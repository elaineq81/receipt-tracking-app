#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from localization_config import CATALOGS, REQUIRED_LANGUAGES

FORMAT_TOKEN = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f)|%%")


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


def has_nonempty_units(localization) -> bool:
    units = list(string_units(localization))
    return bool(units) and all(str(unit.get("value", "")).strip() for unit in units)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate ReceiptSure string-catalog coverage.")
    parser.add_argument("--source-only", action="store_true", help="Only require extracted source strings.")
    parser.add_argument("--machine-draft", action="store_true", help="Require complete nonempty drafts but allow needs-review state.")
    parser.add_argument("--languages", nargs="*", help="Validate only these configured locales.")
    parser.add_argument("--xliff", type=Path, help="Validate an Xcode localization export instead.")
    args = parser.parse_args()

    required_languages = set(args.languages) if args.languages else REQUIRED_LANGUAGES
    unknown = required_languages - REQUIRED_LANGUAGES
    if unknown:
        raise SystemExit(f"Unknown ReceiptSure locales: {', '.join(sorted(unknown))}")

    if args.xliff:
        files = list(args.xliff.rglob("*.xliff"))
        if not files:
            raise SystemExit("Localization validation failed: Xcode export contains no XLIFF file.")
        source_strings = []
        for file in files:
            root = ET.parse(file).getroot()
            for element in root.iter():
                if element.tag.rsplit("}", 1)[-1] == "source" and (element.text or "").strip():
                    source_strings.append(element.text.strip())
        if not source_strings:
            raise SystemExit("Localization validation failed: XLIFF contains no source strings.")
        print(f"Xcode localization export passed: {len(source_strings)} source strings across {len(files)} XLIFF files.")
        return 0

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
        missing_languages = required_languages - languages
        failures.extend(f"Missing required language: {language}" for language in sorted(missing_languages))
        for catalog, strings in catalogs.items():
            for language in sorted(required_languages):
                for key, entry in strings.items():
                    localization = entry.get("localizations", {}).get(language)
                    valid = has_nonempty_units(localization) if args.machine_draft else is_complete(localization)
                    if not localization or not valid:
                        failures.append(f"{catalog.name} — {language}: {key}")
                        continue
                    expected_tokens = sorted(FORMAT_TOKEN.findall(key))
                    for unit in string_units(localization):
                        actual_tokens = sorted(FORMAT_TOKEN.findall(str(unit.get("value", ""))))
                        if actual_tokens != expected_tokens:
                            failures.append(
                                f"{catalog.name} — {language}: placeholder mismatch for {key!r} "
                                f"(expected {expected_tokens}, found {actual_tokens})"
                            )

    if failures:
        preview = "\n".join(failures[:40])
        raise SystemExit(f"Localization validation failed ({len(failures)} gaps):\n{preview}")

    source_count = sum(len(strings) for strings in catalogs.values())
    print(f"Localization catalogs passed: {source_count} source strings, {len(languages)} translated languages.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
