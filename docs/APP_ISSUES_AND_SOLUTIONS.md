# Bills Manager — 深度问题评估与解决方案

> **首次评估**：2026-07-27
> **最近复评**：2026-08-06（真机 `刘小华的iPhone` / iOS 18.6.2，关闭全部可代码闭环的 P0/P1）
> **评估范围**：源码、模型、内购、通知、安全、本地化、数据导出、PRD 一致性、工程质量
> **工程标识**：`com.antigravity.billsmanager` / iOS 17+ / SwiftUI + SwiftData + StoreKit 2
> **结论摘要**：可代码闭环的 **P0/P1 均已关闭**；**P2（除 3.6 测试与 CI）均已关闭**。P0 1.5 ASC 商品与 3.6 测试/CI 仍待后续。剩余主要为 P3 增强。

## 复评状态与验证证据

状态定义：

- `🔴 仍存在`：源码可直接确认，尚无修复。
- `🟠 部分解决`：有实现骨架，但关键路径不完整。
- `🟡 待外部核验`：仅靠仓库无法确认，需要 ASC、沙盒或真机。
- `🟢 已解决`：代码与验证均已闭环。

| 验证项 | 2026-08-06 结果 |
| :--- | :--- |
| Debug 真机构建 | 🟢 `BUILD SUCCEEDED`（`00008110-001A5CA22E3A201E`） |
| Unit / UI Test | 🔴 工程没有 Test target，无法回归业务边界 |
| 原 P0 / P1 整改 | 🟢 可代码闭环项已关闭；ASC 商品 🟡 |
| 通知授权调用点 | 🟢 Onboarding 完成 + 保存账单 `ensureAuthorization`；设置页可跳转系统设置 |
| PRO 权益门控 | 🟢 `ProFeature` 门控分类/账户/导出/锁/多区间分析；已去 Ad-Free 文案 |
| 本地化覆盖 | 🟢 显式 `en` 100%；`zh-Hans` ≈97%+；系统分类/账户展示层本地化 |
| 静默错误 | 🟠 关键保存/导出已 Alert；附件等路径仍有 `try?` |
| 货币硬编码 | 🟢 `CurrencyFormatter` 统一；Dashboard/Analytics/支付历史已替换 |
| App Icon | 🟢 1024 PNG |
| 版本号 | 🟢 Info.plist 跟随 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |

---

## 0. 总体健康度

| 维度 | 评分 (1–10) | 说明 |
| :--- | :---: | :--- |
| 核心账单 CRUD / 周期滚动 | 8 | 锚定日/撤销支付已落地 |
| 数据模型与持久化 | 8 | JSON v2 备份+恢复已闭环 |
| 通知与角标 | 8 | 授权、调度、角标、逾期立即补发 |
| 安全锁 | 8 | 开关认证回滚 + App Switcher 模糊 |
| 内购 / PRO | 7 | 门控与买断策略已落地；ASC 待核验 |
| 导出备份 | 8 | CSV/JSON 导出 + JSON 恢复 |
| 本地化 (en / zh-Hans) | 8 | en 全量；zh-Hans 高覆盖 |
| 无障碍 / 多币种 / 可测试性 | 4 | 无单测；多币种无汇率 |
| 与 PRD/README 一致性 | 7 | 主要卖点已对齐文案与实现 |
| **整体可上线质量** | **7.2** | 适合 TestFlight；正式提交前建议关闭 P2 关键项与 ASC 核验 |

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

### 2.1 通知内容与角标设计粗糙 — 🟢 已解决

- ✅ 角标改为 Dashboard / 支付副作用同步真实逾期数（不再 `content.badge = 1`）
- ✅ 提醒触发时间已过则跳过 schedule（未来到期）
- ✅ 实现 `UNUserNotificationCenterDelegate`，前台展示 banner
- ✅ 已到期/逾期且提醒时间已过时，补发一次性立即本地通知

### 2.2 App Lock 体验不完整 — 🟢 已解决

**修复**
- `inactive` / `background` 显示 `PrivacyBlurOverlay`（App Switcher 高斯模糊）
- `background` 时 `lockApp()`；`active` 取消模糊
- 开启/关闭锁均经 `setAppLockEnabled` 先认证，失败不改 `isAppLockEnabled`（避免“已开锁但未解锁”）

---

### 2.3 货币与金额显示混乱 — 🟢 已解决

- ✅ 统一 `CurrencyFormatter`；Dashboard / Analytics / 支付历史不再硬编码 `$`
- ✅ 设置页可选默认币种；新建账单写入 `defaultCurrency`
- 分析页仍按金额直接相加（多币种汇率汇总属 Sprint 外增强）

### 2.4 本地化严重不完整 — 🟢 已解决

**修复**
- `Localizable.xcstrings` 全量补齐显式 `en`；`zh-Hans` 覆盖率约 97%+（剩余多为符号/版本占位）
- 工具栏 Cancel/Save/Delete 等已走 `L10n.s`
- 系统分类/默认账户 UI 用 `localizedDisplayName`；示例账单按当前语言写入名称
- 设置页版本号改为从 Bundle 读取

---

### 2.5 设置项“幽灵配置” — 🟢 已解决

设置页 Preferences：`Default Currency` / `Default Reminder`；`AddEditBillView` 新建时读取二者。

### 2.6 照片权限声明与实际能力不匹配 — 🟢 已解决

**修复**：移除未使用的 `NSCameraUsageDescription`（仅保留 `PhotosPicker` + `NSPhotoLibraryUsageDescription`）。

---

### 2.7 分析逻辑与财务语义偏差 — 🟢 已解决

**修复**
- 已付金额按 `PaymentRecord.paidDate` 聚合（周期账单滚动后仍计入实付）
- 未付/应付按当前未付账单的 `dueDate` 过滤
- Analytics 增加「实付 / 应付」切换驱动分类图；Dashboard「本月已付」同步改口径

---

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

### 2.11 Auto-Pay 仅是标签，容易被理解为自动扣款 — 🟢 已解决

**修复**：文案改为「外部自动扣款标记」，并加 footer 说明 App 不会扣款或连接银行；字段仍为 `isAutoPay`（兼容备份）。

---

## 3. 中优先级问题（P2）— 体验与工程质量

### 3.1 数据模型与业务边界 — 🟢 已解决（Decimal 延后）

| 问题 | 状态 |
| :--- | :--- |
| `amount` 有效性 | ✅ 表单/`parseAmount` 校验 `isFinite && > 0` |
| 金额 `Double` | ⏭ 延后；见 `docs/SWIFTDATA_MIGRATION.md` |
| `Bill.id` unique | ✅ `@Attribute(.unique)`（Category/Account/PaymentRecord 同） |
| 删除分类/账户无提示 | ✅ 确认对话框展示关联账单数 |
| 系统分类展示名 | ✅ `localizedDisplayName` |
| Migration 计划 | ✅ `docs/SWIFTDATA_MIGRATION.md` |

---

### 3.2 支付历史不完整 — 🟢 已解决

**修复**
- 统一 `MarkPaidSheet`：金额、确认码、收据图；详情/列表/行 Pay 共用
- Unpay / Undo 删除最近 `PaymentRecord`（含确认对话框）
- 支付历史列表展示收据缩略图

---

### 3.3 iPad / 大屏 — 🟢 已解决

**修复**
- `NavigationSplitView` 三栏：侧栏分区 + 账单列表 + 详情
- 侧栏标题/分区走 `L10n`
- 非账单分区详情列展示引导占位

---

### 3.4 无障碍与系统能力 — 🟢 已解决（Widget/Spotlight 延后）

- ✅ `BillRowView` 增加 VoiceOver 组合 label
- ✅ Settings About 标明「仅本机存储、无 iCloud 同步」
- ⏭ Widget / Spotlight / 快捷指令仍属增强，记入 P3

---

### 3.5 错误处理与稳定性 — 🟢 已解决

- ✅ `ModelContainer` 失败展示 `DatabaseLaunchErrorView`，不再 `fatalError`
- ✅ 账单 CRUD / 分类账户 / 示例数据清除走 `Persistence.save` + Alert
- ✅ CSV/JSON 导出写文件失败弹 Alert
- ✅ Paywall：商品加载失败 Retry + 购买失败 Alert；pending/不支持商品有明确文案
- ✅ 附件/收据 PhotosPicker 加载失败弹 Alert（不再静默 `try?`）

---

### 3.6 测试与 CI — 🔴 仍存在（本次跳过）

- **无** Unit Test / UI Test target
- 无关键业务：周期进位、月末 1/31、时区、StoreKit 交易校验

**建议最低测试集**：`BillFrequency.nextDueDate`、`Bill.status`、`markAsPaid` 周期边界、`ExportManager` 编解码、`StoreManager` verification mock。

### 3.7 工程与产品元数据 — 🟢 已解决

- ✅ App Icon 改为 1024×1024 sRGB PNG
- ✅ `Info.plist` 使用 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`；设置页读 Bundle
- Entitlements 为空（对本 App 可接受）
- ✅ 设置页与 Paywall 提供隐私政策 / 使用条款 / Support 链接（`LegalLinks`）
- ✅ 新增 `PrivacyInfo.xcprivacy`（无追踪；声明 UserDefaults / File Timestamp 合理用途）
- README MIT / 商标名仍属人工确认项

### 3.8 文案与功能夸大 — 🟢 已解决

| 宣称 | 实际 |
| :--- | :--- |
| Ad-free PRO | ✅ 文案已移除；应用内无广告 |
| 100% local + Face ID | ✅ Onboarding 改为「本机存储 + 可选 PRO Face ID」 |
| JSON 全量备份 | ✅ v2 含附件/支付历史；可恢复 |
| 高斯模糊遮罩 | ✅ App Switcher / inactive 隐私模糊 |
| 高级趋势对比 | ✅ Paywall 改为「分类占比与实付/应付口径」，不再宣称趋势报告 |

---

### 3.9 StoreKit 权益判定过宽 — 🟢 已解决

`updatePurchasedProducts` / 购买成功路径仅接受 `knownProductIDs` 内的有效 entitlement。

### 3.10 版本与发布配置不可复现 — 🟢 已解决（CI 除外）

- ✅ 共享 Scheme：`xcshareddata/xcschemes/BillsManager.xcscheme`，已绑定 `StoreKit.storekit`
- ✅ 版本来源统一为 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`（Info.plist 构建变量；设置页读 Bundle）
- ⏭ CI / Release Archive / `validate-app` 自动化不在本次范围

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
| `BillsManagerApp` | ✅ Seed 复用；通知配置；scenePhase 锁+隐私模糊 |
| `Bill` | ✅ 锚定日/撤销；分析改 PaymentRecord；金额仍为 Double（P2） |
| `NotificationManager` | ✅ 授权、角标、前台 delegate、逾期立即补发 |
| `StoreManager` | ✅ 门控/买断；ASC 商品 🟡 |
| `ExportManager` | ✅ JSON v2 导出/恢复；CSV 仍为摘要导出 |
| `SettingsView` | ✅ 恢复备份/隐私链接；版本读 Bundle |
| `PaywallView` | ✅ 法律链接与买断策略 |
| `AddEditBillView` | ✅ 金额校验与外部自动扣款文案 |
| `AnalyticsView` | ✅ 实付按 PaymentRecord；应付按 dueDate；可切换 |
| `Category/Account` | ✅ PRO 限额；展示层本地化 |
| `Localizable.xcstrings` | ✅ en 全量；zh-Hans 高覆盖 |
| `AppIcon` | ✅ PNG |
| 工程 | Privacy Manifest ✅；测试/CI ⏭ |

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
2. ✅ 支付历史与分析口径修正
3. ✅ Privacy Manifest + Icon PNG

### Sprint D — 打磨（持续）
1. ✅ 完整中英本地化（系统分类展示层 + 目录全量 en/zh-Hans）
2. ⏭ 单测 + 关键 UI 测（见 3.6，本次跳过）
3. ✅ iPad 双栏；无障碍基础；Widget 仍属 P3

---

## 7. 验收标准（Definition of Done 建议）

- [x] 冷启动后可在中文系统下看到完整中文 UI（无大面积英文残留）
- [ ] 关闭通知权限时有明确引导；开启后到期前提醒可测
- [ ] 月付账单连续标记 3 次支付，下期提醒仍存在且 dueDate 正确
- [ ] 月末账单 `1/31` 连续展期不漂移；跨多期逾期与撤销支付行为符合产品定义
- [ ] 全新安装后恰好 7 个默认分类、3 个默认账户，不出现重名对象
- [ ] 免费用户触发限额功能必现 Paywall；PRO 用户畅通
- [x] JSON 备份 → 删除 App → 重装 → 恢复后数据一致
- [ ] 内购沙盒：买断 / 月 / 年 / 恢复 / 过期 五条路径通过
- [x] 无相机权限却弹相机；无多余隐私用途
- [x] 设置页可打开隐私政策与条款

---

## 8. 文档维护

| 项 | 值 |
| :--- | :--- |
| 文档路径 | `docs/APP_ISSUES_AND_SOLUTIONS.md` |
| 关联文档 | `docs/APP_STORE_REVIEW_RISKS.md`、`docs/PRD.md` |
| 本次状态同步 | 2026-08-06：关闭全部可代码闭环 P0/P1，以及 P2（除 3.6 测试与 CI） |
| 下次复评建议 | 聚焦 3.6 测试/CI、ASC 商品核验与 P3 增强 |

---

*本评估基于源码整改、真机 Debug 构建与文档同步；ASC 商品、StoreKit 沙盒全路径与 Release Archive 仍需人工核对。*
