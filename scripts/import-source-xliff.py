#!/usr/bin/env python3
"""Import Xcode's compiler-extracted source keys into ReceiptSure string catalogs."""

import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET


CATALOGS = {
    "ReceiptArchive/Resources/Localizable.xcstrings": Path("ReceiptArchive/Resources/Localizable.xcstrings"),
    "ReceiptArchive/Resources/InfoPlist.xcstrings": Path("ReceiptArchive/Resources/InfoPlist.xcstrings"),
}


def child_text(element, name: str) -> str:
    return next(
        ((child.text or "") for child in element if child.tag.rsplit("}", 1)[-1] == name),
        "",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xliff", type=Path, help="English XLIFF exported by Xcode.")
    args = parser.parse_args()

    root = ET.parse(args.xliff).getroot()
    imported = 0
    for file_element in (element for element in root.iter() if element.tag.rsplit("}", 1)[-1] == "file"):
        original = file_element.attrib.get("original", "").replace("\\", "/")
        destination = CATALOGS.get(original)
        if destination is None:
            continue

        payload = json.loads(destination.read_text(encoding="utf-8"))
        strings = payload.setdefault("strings", {})
        for unit in (element for element in file_element.iter() if element.tag.rsplit("}", 1)[-1] == "trans-unit"):
            key = unit.attrib.get("id", "").strip()
            if not key:
                continue
            entry = strings.setdefault(key, {})
            note = child_text(unit, "note").strip()
            if note and "comment" not in entry:
                entry["comment"] = note
            imported += 1

        destination.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    if not imported:
        raise SystemExit("No ReceiptSure string-catalog units were found in the XLIFF.")
    print(f"Imported {imported} compiler-extracted source units.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
