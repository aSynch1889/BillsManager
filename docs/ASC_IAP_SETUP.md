# App Store Connect — IAP & Subscriptions (Bills Manager)

**App ID:** `6796724831` · **Bundle ID:** `com.antigravity.billsmanager`

## Product matrix (all unlock PRO)

| Product ID | Type | Price (USD) | ASC status |
|---|---|---|---|
| `com.billsmanager.pro.lifetime` | Non-Consumable | $19.99 | ✅ Verified |
| `com.billsmanager.pro.monthly` | Auto-Renewable (group `BillsManagerProGroup`) | $1.99/mo | ✅ Verified (`sub-monthly2.json`) |
| `com.billsmanager.pro.yearly` | Auto-Renewable (group `BillsManagerProGroup`) | $14.99/yr | ✅ Verified |

## Ongoing subscription value (Guideline 3.1.2)

PRO includes **optional iCloud sync** (SwiftData + CloudKit private database, user toggle default OFF), plus export/backup, app lock, unlimited categories/accounts, and advanced analytics.

Paywall sells **monthly, yearly, and lifetime**; Restore Purchases honors any active entitlement.

## iCloud capability (Xcode / ASC)

1. Enable **iCloud** capability → **CloudKit** in Xcode for target `BillsManager`
2. Container: `iCloud.com.antigravity.billsmanager`
3. Entitlements file: `BillsManager/App/BillsManager.entitlements` (wired via `CODE_SIGN_ENTITLEMENTS`)
4. Regenerate provisioning profile after enabling iCloud on App ID in Developer portal

## StoreKit local testing

Shared scheme binds `BillsManager/Resources/StoreKit.storekit` (lifetime + monthly + yearly).

## ASC CLI artifacts

- Lifetime: `fastlane/builds/iap-lifetime.json`
- Monthly: `fastlane/builds/sub-monthly2.json` (fixed ≤55 char description)
- Yearly: `fastlane/builds/sub-yearly.json`

## Metadata sync checklist

- [ ] App Privacy → Data linked to user: iCloud sync stores bill data in user's private CloudKit container
- [ ] Privacy Policy URL: https://asynch1889.github.io/BillsManager-legal/privacy/en.html
- [ ] Subscription group display name localized
- [ ] Review notes mention iCloud sync is PRO-only and off by default
