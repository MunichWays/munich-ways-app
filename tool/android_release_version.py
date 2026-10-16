"""Reject Android release tags that do not match pubspec.yaml."""

import os
import re
from pathlib import Path


def release_version(tag: str) -> tuple[str, str]:
    match = re.fullmatch(r"((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))\+([1-9][0-9]*)", tag)
    if match is None or int(match[2]) > 2_100_000_000:
        raise ValueError(
            "Android release tag must be VERSION+BUILD (for example 3.2.1+81); "
            "BUILD must be between 1 and 2100000000."
        )
    return match[1], match[2]


def validate_release(tag: str, pubspec: str) -> None:
    release_version(tag)
    match = re.search(r"^version:\s*(\S+)\s*$", pubspec, re.MULTILINE)
    version = match[1] if match else None
    if version != tag:
        raise ValueError(
            f"Release tag {tag!r} does not match pubspec.yaml version {version!r}. "
            "Update and commit pubspec.yaml before creating the release tag."
        )


def main() -> None:
    tag = os.environ.get("RELEASE_TAG", "")
    try:
        validate_release(tag, Path("pubspec.yaml").read_text(encoding="utf-8"))
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(f"Android release tag matches pubspec.yaml: {tag}")


if __name__ == "__main__":
    main()
