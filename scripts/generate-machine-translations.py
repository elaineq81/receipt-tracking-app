#!/usr/bin/env python3
"""Create resumable machine-translation drafts for ReceiptSure string catalogs.

Generated values deliberately use the `needs_review` state. They are suitable for
linguistic and layout QA, but the release validator will not accept them until a
reviewer changes their state to `translated`.
"""

import argparse
import json
from pathlib import Path
import re

import argostranslate.translate

from localization_config import CATALOGS, REQUIRED_LANGUAGES


MODEL_LOCALES = {
    "zh-Hans": "zh", "zh-Hant": "zt", "fr-CA": "fr",
    "pt-BR": "pt", "pt-PT": "pt", "es-MX": "es",
    "es-ES": "es",
}
PROTECTED_TOKEN = re.compile(
    r"%(?:\d+\$)?(?:lld|ld|d|@|f)|%%|ReceiptSure|Face ID|iCloud|AES-GCM|OCR|PDF|CSV|Excel|Word|JPG|TestFlight"
)


def translate_text(source: str, target: str) -> str:
    # Translate around protected Apple placeholders and product names instead of
    # asking the model to copy opaque sentinels. Some scripts transliterate any
    # invented token, while segmenting guarantees byte-for-byte preservation.
    translated = []
    cursor = 0
    for match in PROTECTED_TOKEN.finditer(source):
        segment = source[cursor:match.start()]
        if segment:
            translated.append(argostranslate.translate.translate(segment, "en", target))
        translated.append(match.group(0))
        cursor = match.end()
    tail = source[cursor:]
    if tail:
        translated.append(argostranslate.translate.translate(tail, "en", target))
    return "".join(translated).strip()


def write_catalog(path: Path, payload) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--languages", nargs="*", default=sorted(REQUIRED_LANGUAGES))
    args = parser.parse_args()

    unknown = set(args.languages) - REQUIRED_LANGUAGES
    if unknown:
        raise SystemExit(f"Unknown ReceiptSure locales: {', '.join(sorted(unknown))}")

    for catalog_path in CATALOGS:
        payload = json.loads(catalog_path.read_text(encoding="utf-8"))
        entries = payload["strings"]
        for language in args.languages:
            pending = [
                (key, key)
                for key, entry in entries.items()
                if language not in entry.get("localizations", {})
            ]
            if not pending:
                continue
            target = MODEL_LOCALES.get(language, language)
            completed = 0
            for key, source in pending:
                value = translate_text(source, target)
                entries[key].setdefault("localizations", {})[language] = {
                        "stringUnit": {"state": "needs_review", "value": value}
                }
                completed += 1
                if completed % 20 == 0 or completed == len(pending):
                    write_catalog(catalog_path, payload)
                    print(f"{catalog_path.name} {language}: {completed}/{len(pending)}", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
