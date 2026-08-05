# Bills Manager — 深度问题评估与解决方案

> **首次评估**：2026-07-27
> **最近复评**：2026-07-29（commit `ed42f4a`，Xcode 26.3 / iPhone 16 iOS 18.6 Simulator）
> **评估范围**：源码、模型、内购、通知、安全、本地化、数据导出、PRD 一致性、工程质量
> **工程标识**：`com.antigravity.billsmanager` / iOS 17+ / SwiftUI + SwiftData + StoreKit 2
> **结论摘要**：Debug 构建成功，产品骨架和 CRUD 主流程可演示；但截至本次复评，原清单没有任何代码级整改，**全部 P0/P1 仍未关闭**。此外新增发现默认数据可能重复、周期日期漂移/逾期追赶、地区化金额输入和订阅持续价值等风险，距离正式运营仍有明显差距。

## 复评状态与验证证据

状态定义：

- `🔴 仍存在`：源码可直接确认，尚无修复。
- `🟠 部分解决`：有实现骨架，但关键路径不完整。
- `🟡 待外部核验`：仅靠仓库无法确认，需要 ASC、沙盒或真机。
- `🟢 已解决`：代码与验证均已闭环。

| 验证项 | 2026-07-29 结果 |
| :--- | :--- |
| Debug Simulator 构建 | 🟢 `BUILD SUCCEEDED`，无 Swift 编译错误 |
| Unit / UI Test | 🔴 工程没有 Test target，无法回归业务边界 |
| 原 P0 / P1 整改 | 🔴 未发现代码变更；下文全部保持未关闭 |
| 通知授权调用点 | 🟢 Onboarding 完成 + 保存账单 `ensureAuthorization`；设置页可跳转系统设置 |
| PRO 权益门控 | 🔴 `isProUser` 仅在设置页展示文案，业务门控为 0 |
| 本地化覆盖 | 🔴 148 key；`zh-Hans` 24（16.2%），显式 `en` 2（1.4%） |
| 静默错误 | 🔴 17 处 `try?` |
| 货币硬编码 | 🔴 9 处 `$` 格式 |
| App Icon | 🟠 源文件为 1024×1024 JPEG、无 alpha；Asset Catalog 编译成功 |
| 版本号 | 🔴 构建产物为 `1.0.0 (1)`，与工程 `CURRENT_PROJECT_VERSION=2026072601`、设置页硬编码并存 |

---

## 0. 总体健康度

| 维度 | 评分 (1–10) | 说明 |
| :--- | :---: | :--- |
| 核心账单 CRUD / 周期滚动 | 7 | 主流程可用，细节边界未覆盖 |
| 数据模型与持久化 | 6.5 | SwiftData 可用，缺迁移/恢复/完整性字段 |
| 通知与角标 | 3 | 有调度代码，**从未请求权限**，角标几乎不更新 |
| 安全锁 | 5 | Face ID/设备密码可用，无后台模糊、无失败兜底 UX |
| 内购 / PRO | 3 | StoreKit 2 架子有，**权益门控几乎未实现** |
| 导出备份 | 4 | CSV/JSON 导出有，**无导入恢复**，字段不全 |
| 本地化 (en / zh-Hans) | 4 | 声明双语，简中仅覆盖 **16.2%** 的字符串 key |
| 无障碍 / 多币种 / 可测试性 | 3 | 硬编码 `$`，无单测，无障碍弱 |
| 与 PRD/README 一致性 | 4 | 多处“已支持”实际未实现或未生效 |
| **整体可上线质量** | **4.2** | 可编译、适合 TestFlight 内测；正式提交前需先关闭 P0/P1 |

---

## 1. 严重问题（P0）— 建议上线前必须处理

### 1.1 Freemium / PRO 权益完全未门控（与 PRD 严重不符）— 🔴 仍存在

**现象**
PRD 与 README 写明：免费版限制自定义分类/账户数量、导出备份、生物识别、高级图表等需 PRO。代码中：

- `CategoryManagerView` / `AccountManagerView`：无数量上限、不检查 `isProUser`
- `SettingsView` 导出 CSV / JSON：任意用户可点
- 生物识别开关：任意用户可开
- `AnalyticsView`：完整图表对全员开放
- Paywall 宣传 “Ad-Free”，应用内 **无广告代码**，免费版也无广告

**影响**
- 商业模式失效，内购无转化动机
- App Review 可能认为付费内容“不存在/误导”（见审核文档）
- 用户投诉“买了没变化 / 宣传虚假”

**解决方案**

1. 建立统一权益层，例如 `ProGate` / `StoreManager` 扩展：

```swift
enum ProFeature {
    case unlimitedCategories
    case unlimitedAccounts
    case exportBackup
    case appLock
    case advancedAnalytics
}

extension StoreManager {
    func canAccess(_ feature: ProFeature) -> Bool { isProUser }
}
```

2. 在入口拦截并弹出 `PaywallView`：
   - 自定义分类/账户：`categories.filter { !$0.isSystem }.count >= 5` 时拦截（默认系统分类不计入）
   - 导出按钮、App Lock Toggle、高级分析段（趋势/多区间等）
3. 免费版仍应保留 **完整核心账单能力**（避免 4.2 最低功能问题）
4. 删除或改写 “Ad-Free” 文案，除非确实接入广告并在免费版展示
5. 用 StoreKit Configuration + 单元/UI 测试验证：未购买 / 已购买 / 恢复购买三条路径

---

### 1.2 本地通知从未请求授权，核心卖点失效 — 🟢 已解决

**现象（已修复）**
旧版 `NotificationManager.requestAuthorization()` 全工程无调用点；`scheduleNotification` 在未授权时静默失败；Onboarding 宣传提醒却不引导开启。

**修复**
1. Onboarding「Get Started / Skip」完成时请求通知权限
2. 保存带提醒账单时调用 `ensureAuthorization()`（未决定则弹系统框）
3. 设置页新增 Notifications 区：展示权限状态；被拒时提供「打开系统设置」
4. 启动配置 `UNUserNotificationCenterDelegate`，前台可展示 banner
5. 去掉通知 `badge = 1`；Dashboard `onAppear` / 逾期数变化时 `updateBadgeCount(overdueCount:)`
6. 提醒触发时间已过则跳过 schedule

周期账单 mark paid 后重 schedule 见 1.3 / Sprint A.3。

### 1.3 周期账单“标记已付”后通知逻辑错误 — 🟢 已解决

**现象（已修复）**
旧列表路径在周期 `markAsPaid`（推进 dueDate 且 `isPaid = false`）后仍 `cancelNotification`，不为新 dueDate 重新 schedule。

**修复**
统一 `NotificationManager.applyPaidSideEffects`：已付则 cancel，否则按当前 dueDate schedule，并刷新逾期角标。列表 / 行 / 详情支付与撤销均走此路径。

---

### 1.4 JSON「备份」不可恢复 + 备份内容不完整 — 🔴 仍存在

**现象**
- 仅有 `generateJSONBackup`，**无 Import / Restore UI 与逻辑**
- DTO 缺失：`reminderDaysBefore`、`reminderTime`、`repeatEndDate`、`isAutoPay` 以外部分、`attachmentImageData`、`paymentHistory`、账户 `isDefault`、分类 `isSystem` 等
- CSV 导出无分享失败处理；临时文件无清理

**影响**
换机/重装等于丢数据；PRO 卖点“JSON 全量备份”名不副实。

**解决方案**

1. 备份格式升 `version: 2`，补齐字段；附件用 Base64 或旁路 zip
2. Settings 增加 **Restore from JSON**：`fileImporter` → 校验 version → 用户确认“合并/覆盖”
3. 覆盖模式：清空或按 UUID 去重合并
4. 恢复后重算全部通知与角标
5. 导出失败时 `alert`，不要静默 `try?`

---

### 1.5 内购商品与测试配置未形成可验证闭环 — 🟡 待 ASC / 沙盒核验

**现象**

| 项 | 当前值 |
| :--- | :--- |
| Bundle ID | `com.antigravity.billsmanager` |
| IAP IDs | `com.billsmanager.pro.lifetime` 等 |
| 共享 Scheme / StoreKit Configuration 绑定 | 仓库未见共享 `.xcscheme`，无法确认测试 Scheme 已绑定 |
| 商品加载失败 UI | 商品数组为空时永久显示 Loading，无错误、重试或降级 |

**影响**

- **Product ID 不要求与 Bundle ID 同前缀**，两者命名不同本身不是 StoreKit 错误；旧版文档对此风险表述过重。
- 真正风险是仓库无法证明 ASC 已创建并提交完全一致的三个商品，也没有可复现的共享 StoreKit 测试 Scheme。
- 任一配置或网络错误导致 `Product.products(for:)` 返回空数组时，Paywall 永久 Loading。

**解决方案**

1. 在 ASC 核对三个 Product ID、订阅组、销售地区、协议税务状态与审核截图。
2. 提交共享 Scheme 并绑定 `StoreKit.storekit`，让团队和 CI 能复现本地购买。
3. 空商品状态展示错误、重试按钮和支持信息。
4. 可选统一命名空间以降低人工配错概率，例如：

- `com.antigravity.billsmanager.pro.lifetime`
- `com.antigravity.billsmanager.pro.monthly`
- `com.antigravity.billsmanager.pro.yearly`

若商品已在 ASC 创建，Product ID 通常不能改名，只能新建；不要仅为“看起来一致”破坏现有商品。

---

### 1.6 首次启动默认分类/账户可能重复插入 — 🟢 已解决

**现象（已修复）**

`Category.defaults` / `Account.defaults` 是每次访问都创建全新模型对象的计算属性。旧 Seed 先插入一批 defaults，随后又再次调用 defaults 查找示例账单关联对象，SwiftData 会把第二批对象连同账单一起插入，造成 Utilities、Housing、Subscriptions、Checking Account 重复。

**修复**

`BillsManagerApp.seedInitialDataIfNeeded` 只创建一次并复用同一数组：

```swift
let defaultCategories = Category.defaults
let defaultAccounts = Account.defaults
defaultCategories.forEach(context.insert)
defaultAccounts.forEach(context.insert)
// 后续全部从 defaultCategories / defaultAccounts 取关联对象
```

DEBUG 下增加首次启动断言：恰好 7 个分类、3 个账户、3 个示例账单，名称不重复，且与插入实例 ID 一致。

---

### 1.7 月/年订阅缺少可证明的“持续价值” — 🔴 仍存在（新增）

当前订阅与永久买断解锁同一组静态、本地功能；无云服务、持续内容、订阅期权益或明确的持续重大更新承诺。Apple Guideline 3.1.2(a) 要求自动续订订阅向用户提供持续价值，仅“永久功能开关按月收费”存在商业审核风险。

**方案**：优先考虑仅保留 Non-Consumable 永久买断；若保留订阅，必须定义并兑现持续价值（例如跨设备云同步、持续新增的高级能力/内容），并在 Paywall 与 Review Notes 明确说明。参见 [App Review Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/).

---

## 2. 高优先级问题（P1）

### 2.1 通知内容与角标设计粗糙 — 🟠 部分解决

- ✅ 角标改为 Dashboard / 支付副作用同步真实逾期数（不再 `content.badge = 1`）
- ✅ 提醒触发时间已过则跳过 schedule
- ✅ 实现 `UNUserNotificationCenterDelegate`，前台展示 banner
- ⏳ 过期才创建的账单仍无“立即本地提示”补发（可选增强）

### 2.2 App Lock 体验不完整 — 🔴 仍存在

- 退后台立即 `lockApp()`，从控制中心返回也会反复验证（可接受但可加 grace period）
- **无** App Switcher 高斯模糊遮罩（README 写了）
- 开启锁时若认证失败，`isAppLockEnabled` 已 true 但 `isUnlocked` 可能 false，状态混乱
- 无“关闭锁需再认证一次”

**方案**：

```swift
// scenePhase
case .inactive: showPrivacyBlur = true
case .active: showPrivacyBlur = false; /* 可选 grace */
case .background: if lockEnabled { isUnlocked = false }
```

开启/关闭锁均 `await authenticate()`，失败则回滚 Toggle。

### 2.3 货币与金额显示混乱 — 🔴 仍存在

- `Bill.formattedAmount` 用 `currencyCode` ✔
- Dashboard / Analytics / 逾期 Banner / 支付历史等多处 **硬编码 `$%.2f`**
- `defaultCurrency` `@AppStorage` 存在但 **无 UI、新建账单未读取**

**方案**：统一 `CurrencyFormatter`；设置页可选默认币种；新建账单写入 `defaultCurrency`；分析页按币种分组或提示“多币种未汇总汇率”。

### 2.4 本地化严重不完整 — 🔴 仍存在

- `Localizable.xcstrings` 共 **148** 个 key
- 含 `zh-Hans` **24（16.2%）**；含显式 `en` **2（1.4%）**；大量仅 source（英文字面量）
- 工具栏 `"Cancel"` / `"Save"` / `"Delete"` 等硬编码未走 `NSLocalizedString`
- 种子分类/账户/示例账单全是英文固定名

**方案**：
1. 全量补齐 en + zh-Hans
2. 硬编码按钮改 `String(localized:)`
3. 种子数据按 `Locale.current.language` 写入中/英默认名，或用本地化 key 映射展示层

### 2.5 设置项“幽灵配置” — 🔴 仍存在

`defaultCurrency`、`defaultReminderDays` 声明后未绑定 UI、未影响业务。

**方案**：在 Settings 增加控件并在 `AddEditBillView` 默认值读取；或删除无用状态避免技术债。

### 2.6 照片权限声明与实际能力不匹配 — 🔴 仍存在

- 使用 `PhotosPicker`（一般够用）
- 声明了 `NSCameraUsageDescription` 但 **无相机拍照入口**
- 旧版 `NSPhotoLibraryUsageDescription` 在 iOS 17+ 对 PhotosPicker 可能非必需，但保留无害

**方案**：要么增加“拍照收据”，要么移除 Camera usage 文案，避免审核追问。

### 2.7 分析逻辑与财务语义偏差 — 🔴 仍存在

- 按 `dueDate` 过滤，而非 `PaymentRecord.paidDate`
- 周期账单只保留“当前期”一条，**历史已付金额不会进入分析**（支付历史未聚合）
- “本月已付”用 `isPaid && dueDate 在本月`：周期账单付完后 dueDate 已滚走，**已付金额统计失真**

**方案**：统计已付以 `PaymentRecord` 为准；应付以未付账单 `dueDate` 为准；图表提供“应付 vs 实付”切换。

### 2.8 示例数据污染真实使用 — 🔴 仍存在

首次安装插入 3 条英文示例账单 + 逾期/已付样本。

**方案**：Onboarding 勾选“加载示例数据”；或仅插入分类/账户，账单由用户创建；提供“清空示例数据”。

### 2.9 金额输入与表单约束不足 — 🔴 仍存在（新增）

- Save 只检查 `Double(amountText) != nil`，所以 `0`、负数、`nan`、`infinity` 都可能进入模型。
- `.decimalPad` 会随地区显示逗号小数，但 `Double("12,34")` 解析失败；部分地区用户无法保存合法金额。
- 编辑表单用固定 `"%.2f"` 回填，未使用当前 Locale。
- `repeatEndDate` 可早于 `dueDate`，账户尾号不限制 4 位，支付金额也允许负数或非有限值。

**方案**：使用 `NumberFormatter` / `FloatingPointFormatStyle.Currency` 按 Locale 解析，统一校验 `amount.isFinite && amount > 0`；截止日期不得早于到期日；支付金额同样校验；尾号限制 4 位数字。

### 2.10 周期算法会日期漂移，逾期账单只推进一期 — 🟢 已解决

**产品规则（已落地）**
- **一次 Mark Paid = 一期**：多期逾期需多次标记，每期一条 `PaymentRecord`
- 持久化 `recurrenceAnchorDay`；月度系 `nextDueDate` 按锚定日 clamp（`1/31 → 2/28 → 3/31`）
- `PaymentRecord.periodDueDate` 记录本期；`undoLastPayment()` 回滚 dueDate、删除记录；详情对已滚期账单提供「Undo Last Payment」

---

### 2.11 Auto-Pay 仅是标签，容易被理解为自动扣款 — 🟠 部分实现（新增）

`isAutoPay` 只控制图标、详情文字和导出字段，不会自动付款、连接银行或在到期时自动生成 PaymentRecord。若产品定位只是“该账单在外部已设自动扣款”，应改名为“外部自动扣款标记”并解释；若宣称 App 会自动扣款，则属于功能缺失与高风险误导。

---

## 3. 中优先级问题（P2）— 体验与工程质量

### 3.1 数据模型与业务边界 — 🔴 仍存在

| 问题 | 方案 |
| :--- | :--- |
| `amount` 无有效性校验，可存 0/负数/非有限值 | 保存时校验 `amount.isFinite && amount > 0` |
| 金额 `Double` 浮点误差 | 存 `Decimal` 或整数分 |
| `Bill.id` 非 `@Attribute(.unique)` | 加 unique 约束 |
| 删除分类/账户仅 nullify，无提示 | 删除前显示关联账单数 |
| 系统分类不可编辑名称 | 若需本地化展示，增加 `displayName` |
| 无 SwiftData Migration 计划 | 版本字段 + 显式迁移文档 |

### 3.2 支付历史不完整 — 🔴 仍存在

- 标记已付支持金额/确认码，但 **无收据图**（模型有 `receiptImageData`）
- `markAsUnpaid` 不删除最近一条 `PaymentRecord`，历史与状态不一致
- 列表一键 Pay 不弹确认、不记确认码

**方案**：Unpay 时可选删除最近记录；列表 Pay 进同一 sheet；支持收据。

### 3.3 iPad / 大屏 — 🔴 仍存在

- `NavigationSplitView` 仅侧栏切换，**无 double-column 账单列表+详情**
- 侧栏标题硬编码英文
- 横屏可用但仪表盘信息架构未针对大屏优化

### 3.4 无障碍与系统能力 — 🔴 仍存在

- 缺 VoiceOver label / Dynamic Type 专项
- 无 Widget 到期摘要（竞品常见）
- 无 Spotlight / 快捷指令
- 无 iCloud 同步（隐私向可接受，但需在文案说明“仅本机”）

### 3.5 错误处理与稳定性 — 🔴 仍存在

- `ModelContainer` 失败 `fatalError` — 生产应降级展示错误页
- 共 17 处 `try?`，大量保存、附件加载和文件写入失败被吞掉
- StoreKit 错误仅 `print` / 弱提示，Paywall 无明确失败 Alert

### 3.6 测试与 CI — 🔴 仍存在

- **无** Unit Test / UI Test target
- 无关键业务：周期进位、月末 1/31、时区、StoreKit 交易校验

**建议最低测试集**：`BillFrequency.nextDueDate`、`Bill.status`、`markAsPaid` 周期边界、`ExportManager` 编解码、`StoreManager` verification mock。

### 3.7 工程与产品元数据 — 🔴 仍存在

- App Icon 源文件为 **JPEG**（1024、无 alpha）；本次 Asset Catalog 编译成功，因此不是已证实的上传阻断，但建议用 sRGB PNG 作为标准源资产
- 版本号实际有三套来源：`Info.plist=1.0.0/1`、工程 `MARKETING_VERSION=1.0.0` / `CURRENT_PROJECT_VERSION=2026072601`、Settings 硬编码；构建产物最终是 `1.0.0 (1)`，工程 Build Number 没有生效
- Entitlements 为空（对本 App 可接受）
- **无** `PrivacyInfo.xcprivacy`（Xcode 15+ / 隐私清单要求）
- **无** 隐私政策 / 使用条款链接（设置与 Paywall）
- README 写 MIT，与 App 内未展示 License 无关但需确认商标名 “Bills Manager” 不与他人冲突

### 3.8 文案与功能夸大 — 🔴 仍存在

| 宣称 | 实际 |
| :--- | :--- |
| Ad-free PRO | 全程无广告 |
| 100% local + Face ID | Face ID 可选，且未门控 PRO |
| JSON 全量备份 | 仅导出子集且不可恢复 |
| 高斯模糊遮罩 | 未实现 |
| 高级趋势对比 | 仅环形图分类占比 |

**方案**：改文案或补齐功能，避免 2.3.1 / 3.1 审核与用户预期落差。

### 3.9 StoreKit 权益判定过宽 — 🟠 当前暂不触发（新增）

`isProUser` 以 `purchasedProductIDs` 非空判定，而 `updatePurchasedProducts()` 会接收当前 App 的所有 entitlement，没有过滤三个 PRO Product ID。未来增加其他非 PRO IAP 时，购买任意商品都可能错误解锁 PRO。

**方案**：只接收 `productIDs.contains(transaction.productID)` 的有效、未撤销 entitlement，并覆盖订阅过期、升级/降级、退款与 Family Sharing 测试。

### 3.10 版本与发布配置不可复现 — 🔴 仍存在（新增）

- 仓库没有共享 `.xcscheme`，团队/CI 无法保证 StoreKit Configuration、运行参数和 Archive 行为一致。
- `StoreKit.storekit` 被当普通 App Resource 打包，但这不等于 Scheme 已启用 StoreKit 本地测试。
- 没有 Release Archive / `validate-app` 证据；本次仅验证 Debug Simulator 构建。

**方案**：提交共享 Scheme；统一版本来源为 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 并在 Info.plist 使用构建变量；设置页从 Bundle 动态读取；CI 至少执行 Debug build、tests、Release archive 与静态检查。

---

## 4. 低优先级 / 增强建议（P3）

1. **重复账单历史视图**：每年 12 期应能看到时间线，而非只改 dueDate
2. **智能提醒**：大额账单更早提醒、节假日顺延说明
3. **家庭共享 / 多账本**
4. **CSV 导入**（银行导出）
5. **Swift Charts** 增加柱状月趋势（PRD 暗示）
6. **Passcode 独立于系统**（纯 App 密码）— 当前依赖设备密码，已可用但可增强
7. **日志与崩溃**：OSLog / 无第三方也可先 OSLog
8. **深色模式专项验收**（依赖系统色，风险低）
9. **删除账户尾号**隐私提示（金融敏感）
10. **订阅管理入口**：`https://apps.apple.com/account/subscriptions`

---

## 5. 按模块的问题清单（速查）

| 模块 | 主要问题 |
| :--- | :--- |
| `BillsManagerApp` | 强制种子数据；重复创建 defaults 可能产生重复关联对象；无通知权限；scenePhase 锁过粗 |
| `Bill` | 分析用 dueDate；周期日期漂移；逾期只推进一期；unpay 不回溯历史；金额 Double |
| `NotificationManager` | 未 request；badge=1；无前台 delegate |
| `StoreManager` | 权益未门控；商品/共享 Scheme/ASC 未闭环；entitlement 未过滤；订阅持续价值不足 |
| `ExportManager` | 无 import；字段不全 |
| `SettingsView` | 无隐私条款；导出无 PRO；幽灵配置；版本硬编码 |
| `PaywallView` | 缺订阅法律文案与隐私链接；Feature 英文硬编码 |
| `AddEditBillView` | 地区化金额解析失败；0/负数/非有限值；重复截止日期约束不足 |
| `AnalyticsView` | 统计口径错误；多币种直接相加；硬编码 $ |
| `Category/Account` | 无 PRO 限额 |
| `Localizable.xcstrings` | 中文覆盖率低 |
| `AppIcon` | JPEG，建议 PNG |
| 工程 | 无测试、无 Privacy Manifest |

---

## 6. 建议修复路线图（4 个迭代）

### Sprint A — 可信核心（约 3–5 天）
1. ✅ 修复默认数据对象复用与重复 Seed，并补首次启动断言
2. ✅ 通知授权 + 调度修复 + 角标
3. ✅ 周期账单支付后重 schedule；定义锚定日、逾期追赶和撤销支付语义
4. 金额输入校验、地区化解析与货币格式化统一
5. 示例数据可选
6. 基础崩溃与保存错误提示

### Sprint B — 商业化可用（约 3–5 天）
1. PRO 门控与 Paywall 文案修正
2. 决定“仅永久买断”或为月/年订阅提供真实持续价值
3. 商品 ID、ASC 与共享 StoreKit Scheme 对齐
4. 订阅法律披露 + Restore + 管理订阅链接
5. 隐私政策 / 条款 URL

### Sprint C — 数据可信（约 3–4 天）
1. JSON 备份 v2 + 恢复
2. 支付历史与分析口径修正
3. Privacy Manifest + Icon PNG

### Sprint D — 打磨（持续）
1. 完整中英本地化
2. 单测 + 关键 UI 测
3. iPad 双栏、无障碍、Widget

---

## 7. 验收标准（Definition of Done 建议）

- [ ] 冷启动后可在中文系统下看到完整中文 UI（无大面积英文残留）
- [ ] 关闭通知权限时有明确引导；开启后到期前提醒可测
- [ ] 月付账单连续标记 3 次支付，下期提醒仍存在且 dueDate 正确
- [ ] 月末账单 `1/31` 连续展期不漂移；跨多期逾期与撤销支付行为符合产品定义
- [ ] 全新安装后恰好 7 个默认分类、3 个默认账户，不出现重名对象
- [ ] 免费用户触发限额功能必现 Paywall；PRO 用户畅通
- [ ] JSON 备份 → 删除 App → 重装 → 恢复后数据一致
- [ ] 内购沙盒：买断 / 月 / 年 / 恢复 / 过期 五条路径通过
- [ ] 无相机权限却弹相机；无多余隐私用途
- [ ] 设置页可打开隐私政策与条款

---

## 8. 文档维护

| 项 | 值 |
| :--- | :--- |
| 文档路径 | `docs/APP_ISSUES_AND_SOLUTIONS.md` |
| 关联文档 | `docs/APP_STORE_REVIEW_RISKS.md`、`docs/PRD.md` |
| 本次状态同步 | 2026-07-29：原问题均未关闭；新增 1.6、1.7、2.9–2.11、3.9–3.10 |
| 下次复评建议 | 完成 Sprint A/B 后重新跑构建、首次启动、通知、StoreKit 与业务回归 |

---

*本评估基于全量源码/配置通读、Debug Simulator 构建与静态量化；Simulator 服务在干净安装数据抽检阶段无响应，因此 1.6 仍标为“高概率”，未替代真机通知、StoreKit 沙盒、Release Archive 与 ASC 元数据人工核对。*
