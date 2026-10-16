"""Use the Android release tag as the version source for the Play bundle."""

import os
import re


def release_version(tag: str) -> tuple[str, str]:
    match = re.fullmatch(r"((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))\+([1-9][0-9]*)", tag)
    if match is None or int(match[2]) > 2_100_000_000:
        raise ValueError(
            "Android release tag must be VERSION+BUILD (for example 3.2.1+81); "
            "BUILD must be between 1 and 2100000000."
        )
    return match[1], match[2]


def main() -> None:
    try:
        name, number = release_version(os.environ.get("RELEASE_TAG", ""))
    except ValueError as error:
        raise SystemExit(str(error)) from error
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"build_name={name}\nbuild_number={number}\n")
    print(f"Android release: {name}+{number}")


if __name__ == "__main__":
    main()
