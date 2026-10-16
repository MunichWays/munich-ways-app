"""Read pubspec.yaml and reject uploads whose build is not newer in the store."""

import base64
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse, quote
from urllib.request import Request, urlopen

APP_ID = "com.munichways.app"
GOOGLE = "https://androidpublisher.googleapis.com/androidpublisher/v3"
APPLE = "https://api.appstoreconnect.apple.com"


def decode_secret(value):
    # Match the existing fastlane/base64 CLI handling of wrapped secrets.
    return base64.b64decode("".join(value.split()), validate=True)


def pubspec_version(source):
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+([1-9][0-9]*)\s*$", source, re.MULTILINE)
    if not match or int(match[2]) > 2_100_000_000:
        raise ValueError("pubspec.yaml needs version: VERSION+BUILD, with BUILD between 1 and 2100000000.")
    return match[1], int(match[2])


def build_number(value, ios=False):
    # A new integer iOS build must also exceed older dotted CFBundleVersions.
    pattern = r"[0-9]+(?:\.[0-9]+){0,2}" if ios else r"[0-9]+"
    if isinstance(value, bool) or not re.fullmatch(pattern, str(value)):
        raise ValueError("Store returned an unsupported build number; refusing upload.")
    return int(str(value).split(".")[0])


def require_newer(current, used, platform):
    highest = max((build_number(v, ios=platform == "ios") for v in used), default=0)
    if current <= highest:
        raise ValueError(
            f"pubspec.yaml build {current} must be greater than {platform} store build {highest}. "
            "Increase and commit the build number before uploading."
        )
    return highest


def request_json(method, url, token=None, body=None, form=None):
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if form is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        data = urlencode(form).encode()
    try:
        with urlopen(Request(url, data=data, headers=headers, method=method), timeout=30) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except HTTPError as error:
        # Do not print response bodies, credentials or tokens.
        raise ValueError(f"Store request failed (HTTP {error.code}); upload has not been authorized.") from None
    except (URLError, TimeoutError):
        raise ValueError("Store request failed; check connectivity and retry. Upload has not been authorized.") from None


def google_token(env, request=request_json):
    import jwt
    credentials = json.loads(decode_secret(env["SERVICE_ACCOUNT_JSON_BASE64"]))
    now = int(time.time())
    assertion = jwt.encode({
        "iss": credentials["client_email"],
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": "https://oauth2.googleapis.com/token", "iat": now, "exp": now + 600,
    }, credentials["private_key"], algorithm="RS256")
    return request("POST", "https://oauth2.googleapis.com/token", form={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion,
    })["access_token"]


def android_builds(token, request=request_json):
    base = f"{GOOGLE}/applications/{APP_ID}/edits"
    edit = request("POST", base, token, body={})["id"]
    edit_url = f"{base}/{quote(edit, safe='')}"
    try:
        bundles = request("GET", f"{edit_url}/bundles", token)
        apks = request("GET", f"{edit_url}/apks", token)
        tracks = request("GET", f"{edit_url}/tracks", token)
        versions = [v["versionCode"] for v in bundles.get("bundles", [])]
        versions += [v["versionCode"] for v in apks.get("apks", [])]
        for track in tracks.get("tracks", []):
            for release in track.get("releases", []):
                versions += release.get("versionCodes", [])
        return versions
    finally:
        # This edit only reads data. Never validate or commit it.
        request("DELETE", edit_url, token)


def apple_token(env):
    import jwt
    now = int(time.time())
    return jwt.encode({
        "iss": env["ASC_ISSUER_ID"], "iat": now, "exp": now + 600,
        "aud": "appstoreconnect-v1",
    }, decode_secret(env["ASC_KEY_CONTENT_BASE64"]),
        algorithm="ES256", headers={"kid": env["ASC_KEY_ID"], "typ": "JWT"})


def ios_builds(token, request=request_json):
    apps = request("GET", f"{APPLE}/v1/apps?" + urlencode({
        "filter[bundleId]": APP_ID, "limit": 2,
    }), token)["data"]
    if len(apps) != 1 or apps[0]["attributes"]["bundleId"] != APP_ID:
        raise ValueError("App Store Connect app was not found uniquely; refusing upload.")
    url = f"{APPLE}/v1/builds?" + urlencode({
        "filter[app]": apps[0]["id"],
        "filter[processingState]": "PROCESSING,FAILED,INVALID,VALID",
        "include": "preReleaseVersion", "limit": 200,
    })
    versions, visited = [], set()
    while url:
        if url in visited or urlparse(url).scheme != "https" or urlparse(url).netloc != urlparse(APPLE).netloc:
            raise ValueError("Invalid Store pagination link; refusing upload.")
        visited.add(url)
        page = request("GET", url, token)
        platforms = {v["id"]: v["attributes"]["platform"] for v in page.get("included", [])
                     if v["type"] == "preReleaseVersions"}
        for build in page["data"]:
            version_id = build["relationships"]["preReleaseVersion"]["data"]["id"]
            if platforms[version_id] == "IOS":
                # Include expired, processing and failed builds: their numbers may be consumed.
                versions.append(build["attributes"]["version"])
        url = page.get("links", {}).get("next")
    return versions


def check(platform, upload, source, env, android=None, ios=None):
    name, current = pubspec_version(source)
    if platform not in ("android", "ios"):
        raise ValueError("Unknown store platform.")
    if upload:
        if platform == "android":
            used = android() if android else android_builds(google_token(env))
        else:
            used = ios() if ios else ios_builds(apple_token(env))
        highest = require_newer(current, used, platform)
        message = f"Upload allowed: {name}+{current}; highest {platform} store build: {highest}."
    else:
        message = f"Build only: {name}+{current}. No store lookup or upload; build number may be reused."
    return f"{name}+{current}", message


def main():
    try:
        if os.environ["UPLOAD_ENABLED"] not in ("true", "false"):
            raise ValueError("Invalid upload mode.")
        version, message = check(os.environ["STORE_PLATFORM"], os.environ["UPLOAD_ENABLED"] == "true",
                                 Path("pubspec.yaml").read_text(encoding="utf-8"), os.environ)
    except Exception as error:
        # Credential/parsing exceptions can contain secrets; expose only known safe messages.
        if isinstance(error, ValueError) and str(error).startswith(("pubspec.yaml", "Store request", "Store returned", "App Store", "Invalid Store", "Unknown store")):
            print(str(error), file=sys.stderr)
        else:
            print("Store version check failed. Check credentials/API response; refusing upload.", file=sys.stderr)
        raise SystemExit(1) from None
    print(message)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write(f"version={version}\n")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(message + "\n")


if __name__ == "__main__":
    main()
