#!/usr/bin/env bash
# Configure Bills Manager on App Store Connect via asc CLI.
# Prerequisite: asc auth login (profile "default" in keychain)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="6796724831"
VERSION="1.0.0"
VERSION_ID="2079b84a-2ebd-4421-b04f-b487a33f1f9b"
REVIEW_DETAIL_ID="7b89ca2d-9d7a-428c-83e5-0fe7de46cd33"
METADATA_DIR="$ROOT/metadata"
REVIEW_DIR="$ROOT/.asc/metadata/review"
BUILD_DIR="$ROOT/fastlane/builds"

mkdir -p "$REVIEW_DIR" "$BUILD_DIR"

echo "==> Auth"
asc doctor

echo "==> App setup"
asc app-setup categories set --app "$APP_ID" --primary FINANCE --secondary PRODUCTIVITY
asc apps update --id "$APP_ID" --content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT
asc app-setup pricing set --app "$APP_ID" --free --base-territory USA
asc versions update --version-id "$VERSION_ID" --copyright "2026 Antigravity"

echo "==> Metadata (iCloud copy + subscription EULA links)"
asc metadata plan --app "$APP_ID" --version "$VERSION" --platform IOS --dir "$METADATA_DIR" --review-dir "$REVIEW_DIR"
asc metadata approve --review-dir "$REVIEW_DIR" --all
asc metadata apply --app "$APP_ID" --version "$VERSION" --platform IOS --dir "$METADATA_DIR" --review-dir "$REVIEW_DIR" --confirm

echo "==> Review notes"
asc review details-update --id "$REVIEW_DETAIL_ID" --notes 'Bills Manager stores data locally by default. PRO unlocks optional iCloud sync via CloudKit private database (container: iCloud.com.antigravity.billsmanager). Sync is OFF by default and requires manual toggle plus app restart. PRO plans: monthly, yearly, and lifetime. Test with Sandbox Apple ID. No login required for free tier. Privacy: https://asynch1889.github.io/BillsManager-legal/privacy/en.html'

echo "==> IAP / subscriptions reconcile (idempotent when products already exist)"
asc iap setup --app "$APP_ID" \
  --type NON_CONSUMABLE \
  --reference-name "Bills Manager PRO Lifetime" \
  --product-id com.billsmanager.pro.lifetime \
  --locale en-US \
  --display-name "Bills Manager PRO" \
  --description "Unlock PRO: optional iCloud sync, export, app lock." \
  --price 19.99 --base-territory USA \
  | tee "$BUILD_DIR/iap-lifetime.json" || true

asc subscriptions setup --app "$APP_ID" --group-id 22277853 \
  --reference-name "Bills Manager PRO Monthly" \
  --product-id com.billsmanager.pro.monthly \
  --subscription-period ONE_MONTH \
  --locale en-US --display-name "PRO Monthly" \
  --description "Optional iCloud sync, export, app lock, analytics." \
  --group-locale en-US --group-display-name "Bills Manager PRO" \
  --price 1.99 --price-territory USA \
  | tee "$BUILD_DIR/sub-monthly2.json" || true

asc subscriptions setup --app "$APP_ID" --group-id 22277853 \
  --reference-name "Bills Manager PRO Yearly" \
  --product-id com.billsmanager.pro.yearly \
  --subscription-period ONE_YEAR \
  --locale en-US --display-name "PRO Yearly" \
  --description "Optional iCloud sync, export, app lock, analytics." \
  --group-locale en-US --group-display-name "Bills Manager PRO" \
  --price 14.99 --price-territory USA \
  | tee "$BUILD_DIR/sub-yearly.json" || true

echo "==> Validation report"
asc validate --app "$APP_ID" --version "$VERSION" --platform IOS | tee "$BUILD_DIR/asc-validate.json"

cat <<'EOF'

Manual follow-ups (not fully automatable via public API today):
  1. App availability: Pricing & Availability → make app available (asc pricing availability create currently errors on some territories)
  2. Developer Portal: enable iCloud + CloudKit container iCloud.com.antigravity.billsmanager on App ID (or: asc web auth login && asc web bundle-ids capabilities ...)
  3. Upload Archive build and attach to version 1.0.0
  4. Upload App Store screenshots
  5. Publish App Privacy questionnaire (include optional iCloud sync data)
  6. On version page, submit lifetime IAP + monthly/yearly subscriptions with the app
EOF
