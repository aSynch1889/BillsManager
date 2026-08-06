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
| PRO 权益门控 | 🟢 `ProFeature` 门控分类/账户/导出/锁/多区间分析；已去 Ad-Free 文案 |
| 本地化覆盖 | 🔴 148 key；`zh-Hans` 24（16.2%），显式 `en` 2（1.4%） |
| 静默错误 | 🟠 关键保存/导出已 Alert；附件等路径仍有 `try?` |
| 货币硬编码 | 🟢 `CurrencyFormatter` 统一；Dashboard/Analytics/支付历史已替换 |
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

### 1.1 Freemium / PRO 权益完全未门控（与 PRD 严重不符）— 🟢 已解决

**修复**
- 统一 `ProFeature` + `StoreManager.canAccess` / 限额辅助方法
- 自定义分类 ≥5、账户 ≥3 时拦截并弹 Paywall；导出、App Lock、多区间分析同理
- 免费用户保留本月基础分析与完整账单 CRUD
- 删除 Paywall / 设置中的 “Ad-Free” 文案（应用内无广告）
- entitlement 仅计入已知 PRO Product ID（见 3.9）

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

### 1.4 JSON「备份」不可恢复 + 备份内容不完整 — 🟢 已解决

**现象（已修复）**
- 旧版仅有 `generateJSONBackup`，无 Import / Restore；DTO 缺提醒、附件、支付历史、账户/分类元数据等字段。

**修复**
1. 备份格式升 `version: 2`，补齐 `reminderDaysBefore` / `reminderTime` / `repeatEndDate` / `recurrenceAnchorDay` / `isSample` / 附件 Base64 / `paymentHistory`（含收据）/ 分类 `id`+`isSystem` / 账户 `id`+`isDefault`；仍可读 v1
2. Settings **Restore from JSON**：`fileImporter` → 校验 version → 确认「合并 / 覆盖」
3. 覆盖清空账单/分类/账户后导入；合并按 UUID（v1 按名称）去重 upsert
4. 恢复后重 schedule 全部通知并刷新角标
5. 导出/导入失败均 `alert`，不再静默

---

### 1.5 内购商品与测试配置未形成可验证闭环 — 🟠 部分解决

| 项 | 状态 |
| :--- | :--- |
| Bundle ID | `com.antigravity.billsmanager` |
| 在售 IAP | `com.billsmanager.pro.lifetime`（月/年仅 Restore） |
| 共享 Scheme + StoreKit 配置 | ✅ `xcshareddata/xcschemes/BillsManager.xcscheme` 绑定 `StoreKit.storekit` |
| 空商品 UI | ✅ 错误文案 + Retry，不再永久 Loading |
| ASC 商品是否已创建 | 🟡 仍需人工在 App Store Connect 核验 |

不重命名已有 Product ID（避免破坏 ASC）。

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

### 1.7 月/年订阅缺少可证明的“持续价值” — 🟢 已解决（产品决策）

**决策**：Paywall **仅出售 Non-Consumable 永久买断**（`com.billsmanager.pro.lifetime`）。月/年订阅 ID 保留用于 Restore / 历史 entitlement，但不再作为在售商品，直至具备可证明的持续价值（如云同步）。

参见 [App Review Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/).

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

### 2.3 货币与金额显示混乱 — 🟢 已解决

- ✅ 统一 `CurrencyFormatter`；Dashboard / Analytics / 支付历史不再硬编码 `$`
- ✅ 设置页可选默认币种；新建账单写入 `defaultCurrency`
- 分析页仍按金额直接相加（多币种汇率汇总属 Sprint 外增强）

### 2.4 本地化严重不完整 — 🔴 仍存在

- `Localizable.xcstrings` 共 **148** 个 key
- 含 `zh-Hans` **24（16.2%）**；含显式 `en` **2（1.4%）**；大量仅 source（英文字面量）
- 工具栏 `"Cancel"` / `"Save"` / `"Delete"` 等硬编码未走 `NSLocalizedString`
- 种子分类/账户/示例账单全是英文固定名

**方案**：
1. 全量补齐 en + zh-Hans
2. 硬编码按钮改 `String(localized:)`
3. 种子数据按 `Locale.current.language` 写入中/英默认名，或用本地化 key 映射展示层

### 2.5 设置项“幽灵配置” — 🟢 已解决

设置页 Preferences：`Default Currency` / `Default Reminder`；`AddEditBillView` 新建时读取二者。

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

### 2.8 示例数据污染真实使用 — 🟢 已解决

默认仅 Seed 分类/账户；Onboarding 可选「Load Sample Bills」；设置页可「Remove Sample Bills」。账单带 `isSample` 标记。

### 2.9 金额输入与表单约束不足 — 🟢 已解决

- ✅ `CurrencyFormatter.parseAmount` 按 Locale 解析；校验 `isFinite && > 0`
- ✅ 表单回填用地区化小数格式；支付金额同样校验
- ✅ `repeatEndDate` DatePicker 下限为 `dueDate`
- ✅ 账户尾号为空或恰好 4 位数字

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

### 3.5 错误处理与稳定性 — 🟠 部分解决

- ✅ `ModelContainer` 失败展示 `DatabaseLaunchErrorView`，不再 `fatalError`
- ✅ 账单 CRUD / 分类账户 / 示例数据清除走 `Persistence.save` + Alert
- ✅ CSV/JSON 导出写文件失败弹 Alert
- ⏳ StoreKit / Paywall 错误提示仍弱；附件加载等非关键路径仍有部分 `try?`

### 3.6 测试与 CI — 🔴 仍存在

- **无** Unit Test / UI Test target
- 无关键业务：周期进位、月末 1/31、时区、StoreKit 交易校验

**建议最低测试集**：`BillFrequency.nextDueDate`、`Bill.status`、`markAsPaid` 周期边界、`ExportManager` 编解码、`StoreManager` verification mock。

### 3.7 工程与产品元数据 — 🔴 仍存在

- App Icon 源文件为 **JPEG**（1024、无 alpha）；本次 Asset Catalog 编译成功，因此不是已证实的上传阻断，但建议用 sRGB PNG 作为标准源资产
- 版本号实际有三套来源：`Info.plist=1.0.0/1`、工程 `MARKETING_VERSION=1.0.0` / `CURRENT_PROJECT_VERSION=2026072601`、Settings 硬编码；构建产物最终是 `1.0.0 (1)`，工程 Build Number 没有生效
- Entitlements 为空（对本 App 可接受）
- ✅ 设置页与 Paywall 提供隐私政策 / 使用条款 / Support 链接（`LegalLinks`）
- **无** `PrivacyInfo.xcprivacy`（Xcode 15+ / 隐私清单要求；见 Sprint C）
- README 写 MIT，与 App 内未展示 License 无关但需确认商标名 “Bills Manager” 不与他人冲突

### 3.8 文案与功能夸大 — 🔴 仍存在

| 宣称 | 实际 |
| :--- | :--- |
| Ad-free PRO | ✅ 文案已移除；应用内无广告 |
| 100% local + Face ID | Face ID 已门控 PRO；本地存储属实 |
| JSON 全量备份 | ✅ v2 含附件/支付历史；Settings 可合并或覆盖恢复 |
| 高斯模糊遮罩 | 未实现 |
| 高级趋势对比 | 仅环形图分类占比 |

**方案**：改文案或补齐功能，避免 2.3.1 / 3.1 审核与用户预期落差。

### 3.9 StoreKit 权益判定过宽 — 🟢 已解决

`updatePurchasedProducts` / 购买成功路径仅接受 `knownProductIDs` 内的有效 entitlement。

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
| `ExportManager` | ✅ JSON v2 导出/恢复；CSV 仍为摘要导出 |
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
4. ✅ 金额输入校验、地区化解析与货币格式化统一
5. ✅ 示例数据可选
6. ✅ 基础崩溃与保存错误提示

### Sprint B — 商业化可用（约 3–5 天）
1. ✅ PRO 门控与 Paywall 文案修正
2. ✅ 决定“仅永久买断”或为月/年订阅提供真实持续价值
3. ✅ 商品 ID、ASC 与共享 StoreKit Scheme 对齐
4. ✅ 订阅法律披露 + Restore + 管理订阅链接
5. ✅ 隐私政策 / 条款 URL

### Sprint C — 数据可信（约 3–4 天）
1. ✅ JSON 备份 v2 + 恢复
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
- [x] JSON 备份 → 删除 App → 重装 → 恢复后数据一致
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
