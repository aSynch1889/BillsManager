# Bills Manager — 深度问题评估与解决方案

> **评估日期**：2026-07-27  
> **评估范围**：源码、模型、内购、通知、安全、本地化、数据导出、PRD 一致性、工程质量  
> **工程标识**：`com.antigravity.billsmanager` / iOS 17+ / SwiftUI + SwiftData + StoreKit 2  
> **结论摘要**：产品骨架完整、主流程可演示，但 **Freemium 未落地、通知权限未申请、备份不可恢复、若干声明与实现不符**，距离“可长期运营的生产级 App”仍有明显差距。

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
| 本地化 (en / zh-Hans) | 4 | 声明双语，**约 80%+ 字符串无中文本地化** |
| 无障碍 / 多币种 / 可测试性 | 3 | 硬编码 `$`，无单测，无障碍弱 |
| 与 PRD/README 一致性 | 4 | 多处“已支持”实际未实现或未生效 |
| **整体可上线质量** | **4.5** | 适合 TestFlight 内测；正式运营前需优先修 P0/P1 |

---

## 1. 严重问题（P0）— 建议上线前必须处理

### 1.1 Freemium / PRO 权益完全未门控（与 PRD 严重不符）

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

### 1.2 本地通知从未请求授权，核心卖点失效

**现象**  
`NotificationManager.requestAuthorization()` **全工程无调用点**。  
`scheduleNotification` 在保存账单时会添加请求，但在用户未授权时静默失败。  
Onboarding 宣传 “Never Miss a Payment”，却不引导开启通知。

**影响**  
用户以为会有提醒，实际无推送 → 差评与退订。

**解决方案**

1. 在合适时机请求权限（推荐组合）：
   - Onboarding 最后一页或 “Get Started” 后轻量引导页
   - 用户首次设置提醒/保存带提醒账单时再请求（转化更高）
2. 权限被拒时：设置页提供 “打开系统设置” 跳转（`UIApplication.openSettingsURLString`）
3. 保存/支付后统一调用调度逻辑；**周期账单 mark paid 后应重新 schedule 下一次**（见 2.1）
4. 启动或 Dashboard `onAppear` 同步角标：`updateBadgeCount(overdueCount:)`

---

### 1.3 周期账单“标记已付”后通知逻辑错误

**现象**（`BillListView.togglePaid` / `BillDetailView`）：

- 一次性：`markAsPaid` → `isPaid = true` → `cancelNotification` ✔  
- 周期：`markAsPaid` 会 **推进 `dueDate` 且 `isPaid = false`**，但列表路径仍 `cancelNotification`，**不为新 dueDate 重新 schedule**

**影响**  
下一期账单无提醒。

**解决方案**

```swift
// 统一支付后副作用
func applyPaidSideEffects(for bill: Bill) {
    if bill.isPaid {
        NotificationManager.shared.cancelNotification(for: bill)
    } else {
        // 周期账单已滚到下一期
        NotificationManager.shared.scheduleNotification(for: bill)
    }
    NotificationManager.shared.updateBadgeCount(overdueCount: /* query */)
}
```

删除时 `cancel`；编辑 dueDate/提醒时先 cancel 再 schedule。

---

### 1.4 JSON「备份」不可恢复 + 备份内容不完整

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

### 1.5 内购 Product ID 与 Bundle ID 体系不一致，生产环境易购失败

**现象**  

| 项 | 当前值 |
| :--- | :--- |
| Bundle ID | `com.antigravity.billsmanager` |
| IAP IDs | `com.billsmanager.pro.lifetime` 等 |

**影响**  
ASC 上创建内购时易配错；`Product.products(for:)` 空数组 → Paywall 永久 Loading。

**解决方案**  
统一命名空间，例如：

- `com.antigravity.billsmanager.pro.lifetime`
- `com.antigravity.billsmanager.pro.monthly`
- `com.antigravity.billsmanager.pro.yearly`

同步修改：`StoreManager`、`StoreKit.storekit`、App Store Connect 商品。

---

## 2. 高优先级问题（P1）

### 2.1 通知内容与角标设计粗糙

- `content.badge = 1` 固定为 1，无法反映真实逾期数  
- 过期触发（提醒日已过才创建账单）不会补发  
- 无 `UNUserNotificationCenterDelegate`，前台不展示  

**方案**：角标只走 `setBadgeCount(overdue)`；创建时若 `notificationDate < now` 则跳过或立即本地提示；实现 delegate 前台展示。

### 2.2 App Lock 体验不完整

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

### 2.3 货币与金额显示混乱

- `Bill.formattedAmount` 用 `currencyCode` ✔  
- Dashboard / Analytics / 逾期 Banner / 支付历史等多处 **硬编码 `$%.2f`**  
- `defaultCurrency` `@AppStorage` 存在但 **无 UI、新建账单未读取**  

**方案**：统一 `CurrencyFormatter`；设置页可选默认币种；新建账单写入 `defaultCurrency`；分析页按币种分组或提示“多币种未汇总汇率”。

### 2.4 本地化严重不完整

- `Localizable.xcstrings` 约 **148** 个 key  
- 含 `zh-Hans` 约 **24**；含 `en` 约 **2**；大量仅 source（英文字面量）  
- 工具栏 `"Cancel"` / `"Save"` / `"Delete"` 等硬编码未走 `NSLocalizedString`  
- 种子分类/账户/示例账单全是英文固定名  

**方案**：  
1. 全量补齐 en + zh-Hans  
2. 硬编码按钮改 `String(localized:)`  
3. 种子数据按 `Locale.current.language` 写入中/英默认名，或用本地化 key 映射展示层  

### 2.5 设置项“幽灵配置”

`defaultCurrency`、`defaultReminderDays` 声明后未绑定 UI、未影响业务。

**方案**：在 Settings 增加控件并在 `AddEditBillView` 默认值读取；或删除无用状态避免技术债。

### 2.6 照片权限声明与实际能力不匹配

- 使用 `PhotosPicker`（一般够用）  
- 声明了 `NSCameraUsageDescription` 但 **无相机拍照入口**  
- 旧版 `NSPhotoLibraryUsageDescription` 在 iOS 17+ 对 PhotosPicker 可能非必需，但保留无害  

**方案**：要么增加“拍照收据”，要么移除 Camera usage 文案，避免审核追问。

### 2.7 分析逻辑与财务语义偏差

- 按 `dueDate` 过滤，而非 `PaymentRecord.paidDate`  
- 周期账单只保留“当前期”一条，**历史已付金额不会进入分析**（支付历史未聚合）  
- “本月已付”用 `isPaid && dueDate 在本月`：周期账单付完后 dueDate 已滚走，**已付金额统计失真**

**方案**：统计已付以 `PaymentRecord` 为准；应付以未付账单 `dueDate` 为准；图表提供“应付 vs 实付”切换。

### 2.8 示例数据污染真实使用

首次安装插入 3 条英文示例账单 + 逾期/已付样本。

**方案**：Onboarding 勾选“加载示例数据”；或仅插入分类/账户，账单由用户创建；提供“清空示例数据”。

---

## 3. 中优先级问题（P2）— 体验与工程质量

### 3.1 数据模型与业务边界

| 问题 | 方案 |
| :--- | :--- |
| `amount` 无非负校验，可存 0/负数 | 保存时 `guard amount > 0` |
| 金额 `Double` 浮点误差 | 存 `Decimal` 或整数分 |
| `Bill.id` 非 `@Attribute(.unique)` | 加 unique 约束 |
| 删除分类/账户仅 nullify，无提示 | 删除前显示关联账单数 |
| 系统分类不可编辑名称 | 若需本地化展示，增加 `displayName` |
| 无 SwiftData Migration 计划 | 版本字段 + 显式迁移文档 |

### 3.2 支付历史不完整

- 标记已付支持金额/确认码，但 **无收据图**（模型有 `receiptImageData`）  
- `markAsUnpaid` 不删除最近一条 `PaymentRecord`，历史与状态不一致  
- 列表一键 Pay 不弹确认、不记确认码  

**方案**：Unpay 时可选删除最近记录；列表 Pay 进同一 sheet；支持收据。

### 3.3 iPad / 大屏

- `NavigationSplitView` 仅侧栏切换，**无 double-column 账单列表+详情**  
- 侧栏标题硬编码英文  
- 横屏可用但仪表盘信息架构未针对大屏优化  

### 3.4 无障碍与系统能力

- 缺 VoiceOver label / Dynamic Type 专项  
- 无 Widget 到期摘要（竞品常见）  
- 无 Spotlight / 快捷指令  
- 无 iCloud 同步（隐私向可接受，但需在文案说明“仅本机”）

### 3.5 错误处理与稳定性

- `ModelContainer` 失败 `fatalError` — 生产应降级展示错误页  
- 大量 `try?` 吞掉保存失败  
- StoreKit 错误仅 `print` / 弱提示，Paywall 无明确失败 Alert  

### 3.6 测试与 CI

- **无** Unit Test / UI Test target  
- 无关键业务：周期进位、月末 1/31、时区、StoreKit 交易校验  

**建议最低测试集**：`BillFrequency.nextDueDate`、`Bill.status`、`markAsPaid` 周期边界、`ExportManager` 编解码、`StoreManager` verification mock。

### 3.7 工程与产品元数据

- App Icon 为 **JPEG**（1024，无 alpha）— 建议转 **PNG** 并符合 ASC 规范  
- `Info.plist` 版本与 Settings 硬编码 `1.0.0 (Build 1)` 双处维护  
- Entitlements 为空（对本 App 可接受）  
- **无** `PrivacyInfo.xcprivacy`（Xcode 15+ / 隐私清单要求）  
- **无** 隐私政策 / 使用条款链接（设置与 Paywall）  
- README 写 MIT，与 App 内未展示 License 无关但需确认商标名 “Bills Manager” 不与他人冲突  

### 3.8 文案与功能夸大

| 宣称 | 实际 |
| :--- | :--- |
| Ad-free PRO | 全程无广告 |
| 100% local + Face ID | Face ID 可选，且未门控 PRO |
| JSON 全量备份 | 仅导出子集且不可恢复 |
| 高斯模糊遮罩 | 未实现 |
| 高级趋势对比 | 仅环形图分类占比 |

**方案**：改文案或补齐功能，避免 2.3.1 / 3.1 审核与用户预期落差。

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
| `BillsManagerApp` | 强制种子数据；无通知权限；scenePhase 锁过粗 |
| `Bill` | 分析用 dueDate；unpay 不回溯历史；金额 Double |
| `NotificationManager` | 未 request；badge=1；无前台 delegate |
| `StoreManager` | 权益未用；ID 命名空间；订阅过期边界需测 |
| `ExportManager` | 无 import；字段不全 |
| `SettingsView` | 无隐私条款；导出无 PRO；幽灵配置 |
| `PaywallView` | 缺订阅法律文案与隐私链接；Feature 英文硬编码 |
| `AnalyticsView` | 统计口径错误；硬编码 $ |
| `Category/Account` | 无 PRO 限额 |
| `Localizable.xcstrings` | 中文覆盖率低 |
| `AppIcon` | JPEG，建议 PNG |
| 工程 | 无测试、无 Privacy Manifest |

---

## 6. 建议修复路线图（4 个迭代）

### Sprint A — 可信核心（约 3–5 天）
1. 通知授权 + 调度修复 + 角标  
2. 周期账单支付后重 schedule  
3. 金额/货币格式化统一  
4. 示例数据可选  
5. 基础崩溃与保存错误提示  

### Sprint B — 商业化可用（约 3–5 天）
1. PRO 门控与 Paywall 文案修正  
2. Product ID 对齐 ASC  
3. 订阅法律披露 + Restore + 管理订阅链接  
4. 隐私政策 / 条款 URL  

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
| 下次复评建议 | 完成 Sprint A/B 后重新跑一遍本清单 |

---

*本评估基于仓库静态代码与文档对照，未替代真机 StoreKit 沙盒与 ASC 元数据人工核对。*
