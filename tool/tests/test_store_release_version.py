import base64
from contextlib import redirect_stderr
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa

SCRIPT = Path(__file__).resolve().parents[1] / "store_release_version.py"
spec = importlib.util.spec_from_file_location("store_release_version", SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def pem(key):
    return key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                             serialization.NoEncryption()).decode()


class VersionTests(unittest.TestCase):
    def test_pubspec_is_only_version_source(self):
        self.assertEqual(guard.pubspec_version("name: app\nversion: 3.2.1+81\n"), ("3.2.1", 81))
        for version in ("", "3.2.1", "3.2.1+0", "3.2.1+081", "3.2.1+2100000001"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                guard.pubspec_version(f"version: {version}\n")

    def test_equal_and_lower_builds_are_rejected_for_both_stores(self):
        for platform in ("android", "ios"):
            for current in (79, 80):
                with self.subTest(platform=platform, current=current), self.assertRaisesRegex(ValueError, "greater than"):
                    guard.require_newer(current, [77, "80"], platform)
            self.assertEqual(guard.require_newer(81, [77, "80"], platform), 80)

    def test_empty_store_and_old_dotted_ios_versions(self):
        self.assertEqual(guard.require_newer(1, [], "android"), 0)
        self.assertEqual(guard.require_newer(81, ["80.9.2"], "ios"), 80)
        with self.assertRaises(ValueError):
            guard.require_newer(80, ["80.9.2"], "ios")
        for value in ("unknown", None, True, "80.1"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                guard.require_newer(81, [value], "android")

    def test_build_only_never_authenticates_or_queries_store(self):
        def unexpected():
            self.fail("Build-only mode must not access the store")
        for platform in ("android", "ios"):
            version, message = guard.check(platform, False, "version: 3.2.1+80", {}, unexpected, unexpected)
            self.assertEqual(version, "3.2.1+80")
            self.assertIn("Build only", message)

    def test_same_build_can_be_uploaded_once_per_platform(self):
        source = "version: 3.2.1+81"
        guard.check("android", True, source, {}, android=lambda: [80])
        guard.check("ios", True, source, {}, ios=lambda: [80])
        with self.assertRaises(ValueError):
            guard.check("android", True, source, {}, android=lambda: [81])
        guard.check("ios", True, source, {}, ios=lambda: [80])

    def test_store_failure_aborts_instead_of_assuming_zero(self):
        def offline():
            raise ValueError("Store request failed")
        with self.assertRaisesRegex(ValueError, "Store request failed"):
            guard.check("android", True, "version: 3.2.1+81", {}, android=offline)


class AndroidTests(unittest.TestCase):
    def api(self, failing=False):
        calls = []
        def request(method, url, token=None, **kwargs):
            calls.append((method, url))
            self.assertEqual(token, "test-token")
            if method == "POST":
                return {"id": "edit-1"}
            if method == "DELETE":
                return {}
            if failing:
                raise ValueError("Store request failed")
            if url.endswith("/bundles"):
                return {"bundles": [{"versionCode": 79}, {"versionCode": 81}]}
            if url.endswith("/apks"):
                return {"apks": [{"versionCode": 80}]}
            if url.endswith("/tracks"):
                return {"tracks": [
                    {"track": "beta", "releases": [{"versionCodes": ["77"]}]},
                    {"track": "production", "releases": [{"versionCodes": ["82"]}]},
                    {"track": "internal"},
                ]}
            self.fail("Unexpected request")
        return request, calls

    def test_all_tracks_apks_and_bundles_are_checked_without_commit(self):
        request, calls = self.api()
        versions = guard.android_builds("test-token", request)
        self.assertEqual(guard.require_newer(83, versions, "android"), 82)
        with self.assertRaises(ValueError):
            guard.require_newer(82, versions, "android")
        self.assertEqual([m for m, _ in calls], ["POST", "GET", "GET", "GET", "DELETE"])
        self.assertFalse(any("commit" in url for _, url in calls))

    def test_read_failure_still_deletes_temporary_edit(self):
        request, calls = self.api(failing=True)
        with self.assertRaises(ValueError):
            guard.android_builds("test-token", request)
        self.assertEqual(calls[-1][0], "DELETE")

    def test_google_service_account_jwt_and_oauth_scope(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        credentials = {"client_email": "test@example.invalid", "private_key": pem(key)}
        env = {"SERVICE_ACCOUNT_JSON_BASE64": base64.encodebytes(json.dumps(credentials).encode()).decode()}
        def request(method, url, **kwargs):
            self.assertEqual((method, url), ("POST", "https://oauth2.googleapis.com/token"))
            claims = jwt.decode(kwargs["form"]["assertion"], key.public_key(), algorithms=["RS256"], audience=url)
            self.assertEqual(claims["iss"], credentials["client_email"])
            self.assertEqual(claims["scope"], "https://www.googleapis.com/auth/androidpublisher")
            self.assertEqual(claims["exp"] - claims["iat"], 600)
            return {"access_token": "access"}
        self.assertEqual(guard.google_token(env, request), "access")


class IosTests(unittest.TestCase):
    def page(self, versions, next_url=None, platform="IOS"):
        return {"data": [{"attributes": {"version": v}, "relationships": {
            "preReleaseVersion": {"data": {"id": "train"}}}} for v in versions],
            "included": [{"type": "preReleaseVersions", "id": "train", "attributes": {"platform": platform}}],
            "links": {"next": next_url}}

    def test_all_pages_and_marketing_versions_include_processing_builds(self):
        calls = []
        def request(method, url, token):
            calls.append(url)
            self.assertEqual(method, "GET")
            if "/v1/apps?" in url:
                return {"data": [{"id": "app", "attributes": {"bundleId": guard.APP_ID}}]}
            if url.endswith("page=2"):
                return self.page(["83", "79"])
            return self.page(["80"], guard.APPLE + "/v1/builds?page=2")
        self.assertEqual(guard.ios_builds("token", request), ["80", "83", "79"])
        self.assertEqual(len(calls), 3)
        self.assertNotIn("filter[version]", calls[1])

    def test_other_platform_builds_are_excluded(self):
        def request(method, url, token):
            if "/v1/apps?" in url:
                return {"data": [{"id": "app", "attributes": {"bundleId": guard.APP_ID}}]}
            return self.page(["999"], platform="MAC_OS")
        self.assertEqual(guard.ios_builds("token", request), [])

    def test_missing_app_is_not_treated_as_empty_store(self):
        with self.assertRaisesRegex(ValueError, "not found uniquely"):
            guard.ios_builds("token", lambda *args: {"data": []})

    def test_foreign_or_repeated_pagination_is_rejected(self):
        for next_url in ("https://elsewhere.invalid/builds", "https://user:pass@api.appstoreconnect.apple.com/v1/builds"):
            def request(method, url, token):
                if "/v1/apps?" in url:
                    return {"data": [{"id": "app", "attributes": {"bundleId": guard.APP_ID}}]}
                return self.page(["80"], next_url)
            with self.subTest(next_url=next_url), self.assertRaisesRegex(ValueError, "pagination"):
                guard.ios_builds("token", request)
        def repeated(method, url, token):
            if "/v1/apps?" in url:
                return {"data": [{"id": "app", "attributes": {"bundleId": guard.APP_ID}}]}
            return self.page(["80"], url)
        with self.assertRaisesRegex(ValueError, "pagination"):
            guard.ios_builds("token", repeated)

    def test_apple_jwt_is_signed_with_es256(self):
        key = ec.generate_private_key(ec.SECP256R1())
        token = guard.apple_token({"ASC_KEY_ID": "KEY", "ASC_ISSUER_ID": "issuer",
                                  "ASC_KEY_CONTENT_BASE64": base64.encodebytes(pem(key).encode()).decode()})
        claims = jwt.decode(token, key.public_key(), algorithms=["ES256"], audience="appstoreconnect-v1")
        self.assertEqual(claims["iss"], "issuer")
        self.assertEqual(jwt.get_unverified_header(token)["kid"], "KEY")


class FailureTests(unittest.TestCase):
    def test_http_error_does_not_print_response_or_credentials(self):
        with patch.object(guard, "urlopen", side_effect=HTTPError("https://test.invalid", 403, "secret", {}, None)):
            with self.assertRaisesRegex(ValueError, "HTTP 403") as caught:
                guard.request_json("GET", "https://test.invalid", "SECRET-TOKEN")
        self.assertNotIn("SECRET", str(caught.exception))
        self.assertNotIn("secret", str(caught.exception))

    def test_credential_exception_is_sanitized_and_fails(self):
        errors = io.StringIO()
        with patch.dict(os.environ, {"STORE_PLATFORM": "ios", "UPLOAD_ENABLED": "true"}), \
             patch.object(guard.Path, "read_text", return_value="version: 3.2.1+81"), \
             patch.object(guard, "check", side_effect=RuntimeError("SECRET-KEY")), \
             redirect_stderr(errors), self.assertRaises(SystemExit) as caught:
            guard.main()
        self.assertEqual(caught.exception.code, 1)
        self.assertNotIn("SECRET", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
