# App Store Connect — CLI 配置指南 (asc)

**App ID:** `6796724831` · **Bundle ID:** `com.antigravity.billsmanager` · **Version:** `1.0.0`

## 一键脚本

```bash
# 需先完成 asc auth login（API Key 已保存在 keychain profile "default"）
chmod +x scripts/asc-setup.sh
./scripts/asc-setup.sh
```

脚本会执行：分类、内容权利、免费定价、版权、元数据同步（含 iCloud 文案 + EULA）、审核备注、IAP/订阅 reconcile、validate 报告。

## Product matrix（均解锁 PRO）

| Product ID | Type | Price (USD) | ASC ID | 状态 |
|---|---|---|---|---|
| `com.billsmanager.pro.lifetime` | Non-Consumable | $19.99 | `6796726719` | READY_TO_SUBMIT |
| `com.billsmanager.pro.monthly` | Auto-Renewable | $1.99/mo | `6796726856` | READY_TO_SUBMIT |
| `com.billsmanager.pro.yearly` | Auto-Renewable | $14.99/yr | `6796727243` | READY_TO_SUBMIT |

订阅组：`BillsManagerProGroup` (`22277853`)

## 已通过 asc CLI 完成的配置

| 项目 | 命令 / 说明 |
|---|---|
| 分类 FINANCE + PRODUCTIVITY | `asc app-setup categories set` |
| 内容权利（无第三方内容） | `asc apps update --content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT` |
| 免费 App 定价 | `asc app-setup pricing set --free` |
| 版权 | `asc versions update --copyright "2026 Antigravity"` |
| 元数据 en-US / zh-Hans | `asc metadata plan → approve → apply`（iCloud 同步说明 + Apple 标准 EULA 链接） |
| 审核备注 | `asc review details-update`（iCloud PRO-only、默认关闭） |
| IAP / 订阅 | 已创建并 verified（`fastlane/builds/*.json`） |

## 元数据目录结构

```
metadata/
  app-info/en-US.json
  app-info/zh-Hans.json
  version/1.0.0/en-US.json    # 注意版本号与 ASC 一致为 1.0.0
  version/1.0.0/zh-Hans.json
  primary_category.txt        # FINANCE
  secondary_category.txt      # PRODUCTIVITY
```

修改文案后：

```bash
asc metadata plan --app 6796724831 --version 1.0.0 --platform IOS --dir ./metadata --review-dir .asc/metadata/review
asc metadata approve --review-dir .asc/metadata/review --all
asc metadata apply --app 6796724831 --version 1.0.0 --platform IOS --dir ./metadata --review-dir .asc/metadata/review --confirm
```

## iCloud capability（Developer Portal）

容器：`iCloud.com.antigravity.billsmanager`

公开 API Key 无法列出该团队的 Bundle ID（已注册但不在当前 key 可见列表）。需在 [Developer Portal](https://developer.apple.com/account/resources/identifiers/list) 手动开启 **iCloud → CloudKit**，或使用 web session：

```bash
asc web auth login --apple-id "your@apple.id"
asc web bundle-ids capabilities sync --bundle-id com.antigravity.billsmanager
```

Xcode entitlements 已配置：`BillsManager/App/BillsManager.entitlements`

## 出口合规（加密声明）

App 仅使用系统 exempt 加密（HTTPS/TLS 等），已在两处声明 **不使用非豁免加密**：

- `BillsManager/App/Info.plist` → `ITSAppUsesNonExemptEncryption = false`
- Target Build Settings → `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`

**重要**：已上传的旧 build 不会自动带上此声明，需重新 Archive 并上传新 build 后，ASC 才会识别为「无需出口合规文档」。

```bash
asc encryption declarations exempt-declare --plist BillsManager/App/Info.plist
```

## 提交前仍需人工完成的项

运行 `asc validate --app 6796724831 --version 1.0.0 --platform IOS` 查看实时阻塞项。当前典型剩余：

1. **App 上架地区** — ASC 网页 Pricing & Availability 勾选（`asc pricing availability create` 对部分 territory 报 API 错误）
2. **上传 Build** — Archive → Upload → 在版本页选择 build
3. **截图** — 至少一种设备尺寸
4. **App 隐私问卷** — 发布并声明可选 iCloud 同步存储账单数据
5. **首提订阅** — 在版本页勾选 monthly / yearly / lifetime 一并提交审核

## PRO 订阅审核要点 (Guideline 3.1.2)

- 描述中已包含 Apple 标准 EULA 链接
- Paywall 展示 monthly / yearly / lifetime 三档
- iCloud 同步为 PRO 功能，默认关闭，用户手动开启
- PRO 过期自动关闭同步并迁移回本地

## StoreKit 本地测试

Scheme 绑定 `BillsManager/Resources/StoreKit.storekit`

## 参考文件

- `.asc/app.json` — App / IAP / 订阅 ID 索引
- `fastlane/builds/asc-validate.json` — 最近一次 validate 输出
- `fastlane/builds/iap-lifetime.json`, `sub-monthly2.json`, `sub-yearly.json`
