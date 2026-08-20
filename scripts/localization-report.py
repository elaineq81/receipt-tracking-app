#!/usr/bin/env python3
"""Report draft and reviewed coverage for each configured ReceiptSure locale."""

import json

from localization_config import CATALOGS, REQUIRED_LANGUAGES


catalogs = [json.loads(path.read_text(encoding="utf-8"))["strings"] for path in CATALOGS]
total = sum(len(strings) for strings in catalogs)
print(f"Source strings: {total}")
print("locale\tdraft\treviewed\tmissing")
for language in sorted(REQUIRED_LANGUAGES):
    draft = reviewed = 0
    for strings in catalogs:
        for entry in strings.values():
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            if str(unit.get("value", "")).strip():
                draft += 1
            if unit.get("state") == "translated" and str(unit.get("value", "")).strip():
                reviewed += 1
    print(f"{language}\t{draft}/{total}\t{reviewed}/{total}\t{total - draft}")
