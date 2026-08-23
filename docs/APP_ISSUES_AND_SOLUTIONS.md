# Bills Manager — 深度问题评估与解决方案

> **评估日期**：2026-08-23  
> **工程**：`com.antigravity.billsmanager` · iOS 17+ · SwiftUI + SwiftData + StoreKit 2 · Universal (iPhone/iPad)  
> **版本**：Marketing `1.0.0` · App Store Connect App ID `6796724831`  
> **范围**：源码、数据模型、内购与 PRO 门控、iCloud 同步、通知、安全锁、本地化、导出备份、元数据、工程质量、与 PRD/ASC 一致性  
> **结论**：核心账单 CRUD、周期、通知、PRO 门控、法律链接、Privacy Manifest 已具备 TestFlight/上架骨架；**正式提交前仍有一批产品与工程缺口**。整体可上线质量约 **7.5/10**。可代码闭环的历史 P0 大多已修，当前真正卡住发布的是 **ASC 运营项 + iCloud/CloudKit 风险 + 元数据与实现不一致**。

状态标记：

| 标记 | 含义 |
| :--- | :--- |
| 🔴 仍存在 | 仓库可确认，未修复 |
| 🟠 部分解决 | 有实现，关键路径不完整或有隐患 |
| 🟡 外部核验 | 需 ASC / 沙盒 / 真机 / 线上页面 |
| 🟢 已解决 | 代码侧已闭环（历史项） |

---

## 0. 总体健康度

| 维度 | 评分 (1–10) | 说明 |
| :--- | :---: | :--- |
| 账单 CRUD / 周期滚动 | 8 | 锚定日、一次付一期、撤销支付已落地 |
| 持久化 | 7 | SwiftData 本地可用；CloudKit 迁移需重启，`@Attribute(.unique)` 与 CloudKit 冲突风险 |
| 通知与角标 | 8 | Onboarding/保存账单授权；逾期补发；角标跟逾期数 |
| 安全锁 | 8 | Face ID/设备密码 + App Switcher 模糊 |
| 内购 / PRO | 7 | 三档商品 + 门控齐全；Paywall 订阅披露可更严；ASC 商品待随版本提交 |
| 导出备份 | 8 | JSON v2 可恢复；CSV 为摘要 |
| 本地化 | 8 | L10n 五语；商店文案与免费额度不一致 |
| 无障碍 / 测试 | 4 | 少量 VoiceOver；无 Test target / CI |
| 与商店元数据一致性 | 6 | 免费账户上限、App 名称、截图缺失 |
| **整体** | **7.5** | 适合 TestFlight；商店审核前先关 ASC 阻塞项与元数据错误 |

---

## 1. 严重问题（P0）— 建议上线前处理

### 1.1 App Store Connect 版本尚未可提交 — 🟡 外部（阻塞发布，非代码）

`fastlane/builds/asc-validate.json` 显示 **3 个 blocking error**：

1. **未选择 Build**（`build.required.missing`）
2. **未配置上架地区**（`availability.missing`）
3. **无任何设备截图**（`screenshots.required.any`）

**解决方案**

1. Archive → Upload → 在 1.0.0 版本页选择该 build。  
2. Pricing and Availability 勾选销售地区（脚本对部分 territory 曾报 API 错，需网页完成）。  
3. 至少上传一组必填尺寸截图；Universal App **强烈建议同时有 iPhone 6.7" 与 iPad 13"**。截图勿含系统状态栏虚假框、勿展示未实现功能。  
4. 提交前再跑：`asc validate --app 6796724831 --version 1.0.0 --platform IOS`。

---

### 1.2 商店文案与免费额度不一致 — 🔴 仍存在

| 来源 | 说法 |
| :--- | :--- |
| 代码 `ProFeature` | 自定义分类 **5**、支付账户 **3** |
| `metadata/version/1.0.0/en-US.json` | “Up to **5** custom categories **and payment accounts**” |
| `metadata/version/1.0.0/zh-Hans.json` | “自定义分类与支付账户最多 **5** 个” |

审核员或用户按商店描述会认为账户也是 5。属 **Guideline 2.3.1 误导元数据**。

**解决方案**

二选一，且商店、Paywall、设置页、README 同一口径：

- **改文案**（推荐）：英文改为 “Up to 5 custom categories and 3 payment accounts”；中文改为 “自定义分类最多 5 个、支付账户最多 3 个”。  
- **或改代码**：`freeAccountLimit = 5`。

同步 `asc metadata plan → approve → apply`。

---

### 1.3 SwiftData `@Attribute(.unique)` + CloudKit 不兼容 — 🟠 高隐患

`Bill` / `Category` / `Account` / `PaymentRecord` 均使用 `@Attribute(.unique) var id`。Apple 文档：**CloudKit 支持的 SwiftData 配置不支持 Unique Constraints**。开启 PRO iCloud 后可能：

- 容器创建失败 → `DatabaseLaunchErrorView`（用户无法进入 App）  
- 或同步冲突/重复记录  

`ModelContainerFactory.runPendingMigrationIfNeeded` 在 `App.init` 同步执行，大数据量或 CloudKit 失败会拉长启动、甚至启动失败。

**解决方案**

1. 真机用 **Development CloudKit 容器** 开关同步，验证能否创建 Cloud 配置。  
2. 若失败：为 Cloud 配置去掉 unique（拆 `ModelConfiguration` 或仅本地 unique），用应用层 UUID 去重。  
3. 迁移改后台任务 + 进度/失败回滚，不要静默 `try` 后整 App 不可用。  
4. 审核备注写明：iCloud 默认关；需 PRO + 系统 iCloud 登录 + 重启。

---

### 1.4 PRO 权益缓存可被本地篡改 — 🟠

`UserDefaults` 键 `StoreManagerProEntitlementCache` 在启动时用于判断是否因过期关闭 iCloud。用户改 UserDefaults 可推迟关闭同步；网络差时也可能短暂误判。

**解决方案**

启动后尽快 `Transaction.currentEntitlements`；缓存仅作 UI 占位，**不以缓存作为开启 CloudKit 的依据**（当前开启路径走 `isProUser`，保持）。过期关闭以 StoreKit 为准，失败时宁可关同步并提示，也不要用可写缓存放行。

---

### 1.5 法律页与 Support URL 仓库内无法证明线上可用 — 🟡

`LegalLinks` 指向：

- `https://asynch1889.github.io/BillsManager-legal/privacy/en.html`  
- `.../privacy/zh.html`  
- `.../support/`  
- 条款：Apple 标准 EULA  

**解决方案**

用真机 Safari 打开三条 URL，确认 HTTPS、无 404、隐私政策含：本地存储、可选 iCloud、照片/Face ID/通知、StoreKit、联系邮箱、儿童政策。ASC App 隐私 URL 与 App 内链接一致。GitHub Pages 不稳定时可迁自有域名。

---

## 2. 高优先级（P1）

### 2.1 Paywall 订阅信息披露偏弱 — 🟠

已有：价格、Restore、管理订阅、24 小时续订说明、隐私/条款。  
不足：未用 `Product.subscription?.subscriptionPeriod` 明确 “1 month / 1 year”；续订价与首次价未分行；无免费试用时不要写 trial。

**解决方案**

每个订阅行展示：`displayName` + `period`（月/年）+ `displayPrice`。选中订阅时展示：标题、时长、价格、自动续订。Lifetime 单独标注 Non-Consumable。

---

### 2.2 iCloud 开关强制杀进程式重启 — 🟠

`requestSyncEnabled` 只写 UserDefaults 并横幅 “Restart the app”。审核员可能不知道如何重启；迁移失败无重试。

**解决方案**

文案写清：切到后台划掉 App 再打开。提供 “Quit App” 说明。迁移失败保留本地库并关同步，Alert 错误。审核备注给出路径。

---

### 2.3 内购首次随版本提交 — 🟡

商品均为 `READY_TO_SUBMIT`：lifetime `6796726719`、monthly `6796726856`、yearly `6796727243`。首次订阅 **必须在 App 版本页勾选**，不能只靠 API。

**解决方案**

提交 1.0.0 时同时勾选三件商品。沙盒买月/年/终身、Restore、过期关同步。Paywall 空列表时 Retry 已有，需保证审核机有网且商品 Approved 或随版提交。

---

### 2.4 App 显示名与商店名 — 🔴 元数据

`metadata/app-info/en-US.json`：`"name": "Bills Manager - billsmanager"`。后半段像关键词堆砌（2.3.7）。

**解决方案**

改为 “Bills Manager”（≤30 字符）。Subtitle 已有 “Bills & Due Date Tracker”，足够。中文名避免堆砌 “账单管家账单管理”。

---

### 2.5 定位为竞品复刻 — 🟠 品牌/4.1

README：“完整复刻了 Bills Manager / Bills Monitor”。审核可能按 **4.1 Copycat** 对比图标、截图、功能列表。

**解决方案**

商店与审核材料不要写 clone。图标/启动/文案与已上架 “Bills Monitor” 等拉开差异。MIT 许可证与 App 名商标冲突需法务自查。

---

### 2.6 `NSPhotoLibraryUsageDescription` 与 PhotosPicker — 🟠 低–中

附件用系统选图。完整相册权限字符串在 iOS 17 可能触发不必要权限或用途质疑。

**解决方案**

仅 PhotosPicker 时，评估是否可改为有限照片访问文案，或确认不会弹完整相册授权。InfoPlist 中英日韩文案与“收据附件”一致。无相机则不要声明相机（已删，保持）。

---

### 2.7 金额 `Double` — 🟠（已知延后）

财务金额用 `Double`，分位累加有误差。见 `docs/SWIFTDATA_MIGRATION.md`。

**解决方案**

后续 migration 改为 `Decimal` 存储字符串或整数最小币种单位。上架前保证输入校验 `isFinite && > 0`（已有）。

---

### 2.8 无测试与 CI — 🔴

无 Unit/UI Test target。周期锚定、月末 31 日、导入 v1/v2、StoreKit 校验均靠手工。

**解决方案**

最低：`BillFrequency.nextDueDate`、`Bill.markAsPaid` / `undoLastPayment`、`ExportManager` 编解码、`ProFeature` 限额。Xcode Cloud 或本地 `xcodebuild test`。

---

## 3. 中优先级（P2）

| ID | 问题 | 方案 |
| :--- | :--- | :--- |
| 3.1 | iPhone Info.plist 声明横屏，布局以竖屏 Tab 为主 | 若未做横屏：iPhone 仅 Portrait；iPad 保留四向 |
| 3.2 | `UILaunchScreen` 空 dict，白屏闪一下 | 启动图用 Accent + App Icon 或纯色 + 名称 |
| 3.3 | 多币种分析直接加总 | 分析页注明 “未汇率换算” 或按账单币种分组 |
| 3.4 | VoiceOver 仅账单行较完整 | Dashboard 卡片、日历格、Paywall 价格加 `accessibilityLabel` |
| 3.5 | `print` 错误日志 | 改为 `Logger`（os），Release 避免敏感账单名 |
| 3.6 | 通知 identifier = bill UUID，改期覆盖 | 保持单 ID 即可；若要到期当天+提前提醒需多 ID |
| 3.7 | 默认账户含尾号字段，金融敏感 | 设置/账户页说明仅本地、可选不填 |
| 3.8 | 语言五语，商店仅 en-US / zh-Hans | 日韩繁或商店只宣这两语，避免 2.1 语言落差 |
| 3.9 | `PrivacyInfo` 收集类型为空，但可选 iCloud 存账单 | Manifest 可仍空（不经自有服务器）；**App 隐私问卷必须申报 iCloud 财务数据** |
| 3.10 | 工程内 `fastlane/private_keys/*.p8` 本地存在 | 已 gitignore；确认从未入库；泄露则轮换 API Key |
| 3.11 | CloudKit entitlement 已加，Portal 容器需人工开 | Developer Portal 确认 `iCloud.com.antigravity.billsmanager` + CloudKit |
| 3.12 | 无 Widget / 后台刷新 | 不在 1.0 承诺即可；商店不要写锁屏小组件 |

---

## 4. 低优先级 / 增强（P3）

1. 周期账单时间线（不只改 `dueDate`）  
2. 柱状月趋势（Paywall 已不再承诺）  
3. CSV 导入  
4. 独立 App 密码（现依赖系统密码，可接受）  
5. 家庭共享：非消耗型终身可考虑 Family Sharing；订阅看商业策略  
6. 深色模式专项走查  
7. 崩溃：无第三方时用 MetricKit / 系统日志  

---

## 5. 历史 P0/P1（代码已关闭，供对照）

| 项 | 状态 |
| :--- | :--- |
| PRO 未门控 / Ad-Free 文案 | 🟢 `ProFeature` |
| 通知未请求授权 | 🟢 Onboarding + 保存账单 |
| 周期付费后通知取消不重排 | 🟢 `applyPaidSideEffects` |
| JSON 不可恢复 | 🟢 v2 合并/覆盖 |
| Seed 重复分类账户 | 🟢 单次数组插入 |
| 订阅无持续价值 | 🟢 可选 iCloud 等 |
| App Lock / 模糊 | 🟢 |
| 相机权限多余 | 🟢 已删 |
| Privacy Manifest / PNG 1024 Icon | 🟢 |
| 加密声明 `ITSAppUsesNonExemptEncryption=false` | 🟢 plist + build setting |

---

## 6. 建议修复顺序

1. 改商店免费额度文案（或改 `freeAccountLimit`）+ 去掉 App 名 keyword stuffing。  
2. 真机验证 CloudKit 开/关、迁移、PRO 过期。  
3. Paywall 补订阅周期展示。  
4. 上传 Build、截图、地区、隐私问卷、三件 IAP 随版本提交。  
5. 浏览器验收隐私/支持页。  
6. （可并行）补单测、iPhone 方向、启动屏。

---

## 7. 模块速查

| 模块 | 仍需关注 |
| :--- | :--- |
| `StoreManager` / `PaywallView` | 周期披露、ASC 随版提交 |
| `CloudSyncManager` / `ModelContainerFactory` | unique+CloudKit、迁移失败、重启 |
| `ProFeature` vs metadata | 账户 3 vs 文案 5 |
| `LegalLinks` | 线上页存活 |
| `NotificationManager` | 已较完整 |
| `ExportManager` | 已可恢复 |
| `BiometricAuthManager` | 已完整 |
| ASC / fastlane | 无 build、无截图、无 availability |
