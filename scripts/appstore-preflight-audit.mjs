import { createPrivateKey, sign } from "node:crypto";

const appId = process.env.APP_STORE_CONNECT_APP_ID || "6798071503";
const versionString = process.env.APP_STORE_VERSION || "1.0";
const platform = process.env.APP_STORE_PLATFORM || "IOS";
const expectedEula = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/";
const expectedMarketing = "https://receipt-tracking-app-lemon.vercel.app";
const expectedSupport = "https://receipt-tracking-app-lemon.vercel.app/support";
const keyId = process.env.APPSTORE_KEY_ID;
const issuerId = process.env.APPSTORE_ISSUER_ID;
const privateKeyRaw = process.env.APPSTORE_PRIVATE_KEY;

if (!keyId || !issuerId || !privateKeyRaw) {
  throw new Error("Missing ReceiptSure App Store Connect API credentials in GitHub secrets.");
}

const privateKey = privateKeyRaw.includes("\\n")
  ? privateKeyRaw.replace(/\\n/g, "\n")
  : privateKeyRaw;

function base64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function createJwt() {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = { iss: issuerId, iat: now, exp: now + 20 * 60, aud: "appstoreconnect-v1" };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = sign("sha256", Buffer.from(signingInput), {
    key: createPrivateKey(privateKey),
    dsaEncoding: "ieee-p1363",
  });
  return `${signingInput}.${base64url(signature)}`;
}

async function api(path) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    headers: {
      Authorization: `Bearer ${createJwt()}`,
      "Content-Type": "application/json",
    },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`API ${response.status} for ${path}: ${JSON.stringify(body)}`);
  }
  return body;
}

let failures = 0;
const pass = (label, detail = "") => console.log(`PASS | ${label}${detail ? ` | ${detail}` : ""}`);
const warn = (label, detail = "") => console.log(`WARN | ${label}${detail ? ` | ${detail}` : ""}`);
const fail = (label, detail = "") => {
  console.log(`FAIL | ${label}${detail ? ` | ${detail}` : ""}`);
  failures += 1;
};

const versionsUrl = new URL(`/v1/apps/${appId}/appStoreVersions`, "https://api.appstoreconnect.apple.com");
versionsUrl.searchParams.set("filter[platform]", platform);
versionsUrl.searchParams.set("limit", "50");
versionsUrl.searchParams.set("include", "build,appStoreVersionLocalizations,appStoreReviewDetail");
versionsUrl.searchParams.set("fields[appStoreVersions]", "platform,versionString,appStoreState,build,appStoreVersionLocalizations,appStoreReviewDetail");
versionsUrl.searchParams.set("fields[builds]", "version,processingState,usesNonExemptEncryption,uploadedDate,expired,iconAssetToken");
versionsUrl.searchParams.set("fields[appStoreVersionLocalizations]", "locale,description,marketingUrl,promotionalText,supportUrl");

const response = await api(`${versionsUrl.pathname}${versionsUrl.search}`);
const version = (response.data || []).find((item) => item.attributes?.versionString === versionString);
if (!version) {
  fail("App version found", `${platform} ${versionString}`);
  process.exit(1);
}
pass("App version found", `${versionString} state=${version.attributes?.appStoreState || "unknown"}`);

const included = response.included || [];
const localization = included.find(
  (item) => item.type === "appStoreVersionLocalizations" && item.attributes?.locale === "en-US",
) || included.find((item) => item.type === "appStoreVersionLocalizations");

if (!localization) {
  fail("English localization present");
} else {
  const attributes = localization.attributes || {};
  attributes.description?.includes(expectedEula)
    ? pass("Standard EULA link present")
    : fail("Standard EULA link present");
  attributes.marketingUrl?.startsWith(expectedMarketing)
    ? pass("Marketing URL matches", attributes.marketingUrl)
    : fail("Marketing URL matches", attributes.marketingUrl || "empty");
  attributes.supportUrl?.startsWith(expectedSupport)
    ? pass("Support URL matches", attributes.supportUrl)
    : fail("Support URL matches", attributes.supportUrl || "empty");
}

const build = included.find((item) => item.type === "builds");
if (!build) {
  fail("Build attached", "No build is selected for version 1.0");
} else {
  const attributes = build.attributes || {};
  pass("Build attached", `version=${attributes.version || "unknown"}`);
  attributes.processingState === "VALID"
    ? pass("Build processing is valid")
    : fail("Build processing is valid", attributes.processingState || "unknown");
  attributes.expired ? fail("Build is not expired") : pass("Build is not expired");
  attributes.iconAssetToken
    ? pass("App icon is present in processed build")
    : fail("App icon is present in processed build", "iconAssetToken is missing");
  attributes.usesNonExemptEncryption === false
    ? pass("Export compliance is exempt", "usesNonExemptEncryption=false")
    : fail("Export compliance is exempt", `usesNonExemptEncryption=${attributes.usesNonExemptEncryption}`);
}

try {
  const review = await api(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  const attributes = review.data?.attributes || {};
  if (attributes.contactFirstName && attributes.contactLastName && attributes.contactEmail && attributes.contactPhone) {
    pass("App Review contact information is complete");
  } else {
    fail("App Review contact information is complete", JSON.stringify({
      firstName: Boolean(attributes.contactFirstName),
      lastName: Boolean(attributes.contactLastName),
      email: Boolean(attributes.contactEmail),
      phone: Boolean(attributes.contactPhone),
    }));
  }
  if (attributes.demoAccountName || attributes.demoAccountPassword) {
    warn("Demo credentials are present", "Confirm they are valid or remove them because ReceiptSure has no login");
  } else {
    pass("No demo credentials are present");
  }
} catch (error) {
  fail("App Review detail is readable", error.message.slice(0, 240));
}

console.log(`AUDIT | Final failure count: ${failures}`);
if (failures > 0) process.exit(1);
