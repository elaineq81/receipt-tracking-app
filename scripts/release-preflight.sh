#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Release preflight failed: $1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$file" || fail "$file is missing: $expected"
}

assert_file_contains project.yml "DEVELOPMENT_TEAM: B5DJ69S32C"
assert_file_contains project.yml "CURRENT_PROJECT_VERSION: 1"
assert_file_contains project.yml "MARKETING_VERSION: 1.0"
assert_file_contains project.yml "PRODUCT_BUNDLE_IDENTIFIER: com.bodywiseremedy.receiptsure"
assert_file_contains project.yml 'iOS: "17.0"'

assert_file_contains APP_STORE_METADATA.md "ReceiptSure: Expense Proof"
assert_file_contains APP_STORE_METADATA.md "Trusted receipts, tidy reports"
assert_file_contains APP_STORE_METADATA.md "https://receipt-tracking-app-lemon.vercel.app/privacy"
assert_file_contains APP_STORE_METADATA.md "https://receipt-tracking-app-lemon.vercel.app/support"
assert_file_contains APP_STORE_METADATA.md "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

if git ls-files | grep -Eiq '\.(p8|p12|pem|mobileprovision|cer|key|certSigningRequest|csr)$'; then
  fail "a signing credential or private key is tracked by Git"
fi

python3 - <<'PY'
import json
import pathlib
import re
import sys

def fail(message: str) -> None:
    print(f"Release preflight failed: {message}", file=sys.stderr)
    raise SystemExit(1)

metadata = pathlib.Path("APP_STORE_METADATA.md").read_text(encoding="utf-8")

def field(label: str) -> str:
    match = re.search(rf"^- {re.escape(label)}: \*\*(.+?)\*\*$", metadata, re.MULTILINE)
    if not match:
        fail(f"metadata field not found: {label}")
    return match.group(1)

name = field("App Store name")
subtitle = field("Subtitle")
keywords_match = re.search(r"^## Keywords\s+(.+)$", metadata, re.MULTILINE)
if not keywords_match:
    fail("keywords were not found")
keywords = keywords_match.group(1).strip()

if len(name) > 30:
    fail(f"App Store name is {len(name)} characters; maximum is 30")
if len(subtitle) > 30:
    fail(f"subtitle is {len(subtitle)} characters; maximum is 30")
if len(keywords.encode("utf-8")) > 100:
    fail(f"keywords are {len(keywords.encode('utf-8'))} bytes; maximum is 100")

storekit = json.loads(pathlib.Path("ReceiptArchive/Resources/ReceiptSure.storekit").read_text(encoding="utf-8"))
products = storekit.get("products", [])
if len(products) != 1:
    fail(f"expected one StoreKit product, found {len(products)}")

product = products[0]
if product.get("productID") != "com.bodywiseremedy.receiptsure.pro.lifetime":
    fail("StoreKit product ID does not match the release product")
if product.get("type") != "NonConsumable":
    fail("ReceiptSure Pro must be a non-consumable")

expected_description = "Unlimited receipts, reports, and exports."
localizations = product.get("localizations", [])
if {item.get("locale") for item in localizations} != {"en_SG", "en_US"}:
    fail("StoreKit localizations must include exactly en_SG and en_US")
for item in localizations:
    description = item.get("description", "")
    display_name = item.get("displayName", "")
    if description != expected_description:
        fail(f"{item.get('locale')} IAP description differs from the approved copy")
    if len(description) > 45:
        fail(f"{item.get('locale')} IAP description exceeds 45 characters")
    if len(display_name) > 30:
        fail(f"{item.get('locale')} IAP display name exceeds 30 characters")

print(
    f"Release metadata passed: {name!r} ({len(name)}/30), "
    f"subtitle ({len(subtitle)}/30), keywords ({len(keywords.encode('utf-8'))}/100 bytes)."
)
PY

if command -v plutil >/dev/null 2>&1; then
  plutil -lint ReceiptArchive/Resources/Info.plist
  plutil -lint ReceiptArchive/Resources/PrivacyInfo.xcprivacy
fi

echo "ReceiptSure App Store release preflight passed."
