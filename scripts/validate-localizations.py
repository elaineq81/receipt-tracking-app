#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

CATALOGS = (
    Path("ReceiptArchive/Resources/Localizable.xcstrings"),
    Path("ReceiptArchive/Resources/InfoPlist.xcstrings"),
)

# English is the source language and covers Apple's English storefront variants.
# These are the remaining UI locale identifiers supported by App Store Connect.
REQUIRED_LANGUAGES = {
    "ar", "bn", "ca", "zh-Hans", "zh-Hant", "hr", "cs", "da", "nl",
    "fi", "fr", "fr-CA", "de", "el", "gu", "he", "hi", "hu", "id",
    "it", "ja", "kn", "ko", "ms", "ml", "mr", "nb", "or", "pl",
    "pt-BR", "pt-PT", "pa", "ro", "ru", "sk", "sl", "es-MX", "es-ES",
    "sv", "ta", "te", "th", "tr", "uk", "ur", "vi",
}


def string_units(node):
    if isinstance(node, dict):
        unit = node.get("stringUnit")
        if isinstance(unit, dict):
            yield unit
        for value in node.values():
            yield from string_units(value)
    elif isinstance(node, list):
        for value in node:
            yield from string_units(value)


def is_complete(localization) -> bool:
    units = list(string_units(localization))
    return bool(units) and all(
        unit.get("state") == "translated" and str(unit.get("value", "")).strip()
        for unit in units
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate ReceiptSure string-catalog coverage.")
    parser.add_argument("--source-only", action="store_true", help="Only require extracted source strings.")
    args = parser.parse_args()

    catalogs = {}
    failures = []
    languages = set()
    for catalog in CATALOGS:
        payload = json.loads(catalog.read_text(encoding="utf-8"))
        strings = payload.get("strings", {})
        catalogs[catalog] = strings
        if not strings:
            failures.append(f"{catalog}: no source strings found")
        for entry in strings.values():
            languages.update(entry.get("localizations", {}).keys())

    if not args.source_only:
        missing_languages = REQUIRED_LANGUAGES - languages
        failures.extend(f"Missing required language: {language}" for language in sorted(missing_languages))
        for catalog, strings in catalogs.items():
            for language in sorted(REQUIRED_LANGUAGES):
                for key, entry in strings.items():
                    localization = entry.get("localizations", {}).get(language)
                    if not localization or not is_complete(localization):
                        failures.append(f"{catalog.name} — {language}: {key}")

    if failures:
        preview = "\n".join(failures[:40])
        raise SystemExit(f"Localization validation failed ({len(failures)} gaps):\n{preview}")

    source_count = sum(len(strings) for strings in catalogs.values())
    print(f"Localization catalogs passed: {source_count} source strings, {len(languages)} translated languages.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
