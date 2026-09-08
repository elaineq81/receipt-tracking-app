#!/usr/bin/env python3
"""Download Argos language models; no ReceiptSure source text leaves the computer."""

import argparse

import argostranslate.package


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("languages", nargs="+")
    args = parser.parse_args()

    argostranslate.package.update_package_index()
    available = argostranslate.package.get_available_packages()
    installed = {
        (package.from_code, package.to_code)
        for package in argostranslate.package.get_installed_packages()
    }
    for language in args.languages:
        pair = ("en", language)
        if pair in installed:
            print(f"Already installed: en -> {language}")
            continue
        package = next(
            (candidate for candidate in available if candidate.from_code == "en" and candidate.to_code == language),
            None,
        )
        if package is None:
            raise SystemExit(f"No offline Argos model is available for en → {language}")
        print(f"Downloading offline model: en -> {language}", flush=True)
        argostranslate.package.install_from_path(package.download())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
