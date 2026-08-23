# Bills Manager — App Store Connect 审核拒因风险评估与解决方案

> **评估日期**：2026-08-23  
> **依据**：[App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)（2 性能、3 商务、4 设计、5 法律）  
> **对照仓库**：代码 + `metadata/` + `docs/ASC_IAP_SETUP.md` + `fastlane/builds/asc-validate.json`  
> **总体判断**：**现在直接点 Submit for Review 会被流程挡住，即使硬提交，拒审风险为中等。**  
> 代码侧 3.1.2 / 隐私链接 / Restore / Manifest / Icon 已明显好于早期版本；**当前最大风险是 ASC 未就绪、元数据与免费额度不符、iCloud/CloudKit 在审核机上崩溃或不可用、订阅披露与首次 IAP 未挂到版本。**

状态：🔴 会挡提交或高概率拒 | 🟠 有实现但仍可能拒 | 🟡 外部/人工 | 🟢 代码侧已到位

---

## 0. 风险总览

| 等级 | 拒因方向 | Guideline | 现状 | 预估 |
| :---: | :--- | :--- | :--- | :--- |
| 🔴 | 版本不完整：无 Build / 无截图 / 无销售地区 | 2.3 / ASC 校验 | validate：**3 个 blocking error** | **无法提交** |
| 🔴 | 元数据夸大免费额度（账户 5 vs 代码 3） | 2.3.1 | en-US / zh-Hans 均错 | 中高 |
| 🟠 | 订阅持续价值 / 信息披露 | 3.1.2(a)(c) | 有 iCloud+导出+锁；Paywall 周期展示偏弱 | 中 |
| 🟠 | 内购无法购买 / 未随版本提交 | 2.1 / 3.1.1 | 商品 READY_TO_SUBMIT，未随 1.0.0 勾选则审核买不到 | 中高 |
| 🟠 | iCloud 开同步崩溃或白屏 | 2.1 | unique + CloudKit；迁移在 `App.init` | 中 |
| 🟡 | 隐私政策 URL 打不开 / 问卷未发布 | 5.1.1(i) | App 内有链接；Pages 与问卷需人工确认 | 中 |
| 🟠 | App 名称 keyword stuffing | 2.3.7 | “Bills Manager - billsmanager” | 中低–中 |
| 🟠 | 复刻竞品观感 | 4.1 | README 写 clone；商店勿沿用 | 中（看视觉） |
| 🟢 | 权限字符串 | 5.1.1(iii) | Face ID + 相册；无相机 | 低 |
| 🟢 | 恢复购买 / 管理订阅 | 3.1.1 / 3.1.2 | Paywall 已有 | 低 |
| 🟢 | Privacy Manifest | 5.1.2 平台 | `PrivacyInfo.xcprivacy` 无追踪 | 低（仍建议 Validate） |
| 🟢 | 加密出口 | 法律问卷 | `ITSAppUsesNonExemptEncryption=false` | 低 |
| 🟢 | 登录墙 / 账号删除 | 5.1.1(v) | 无账号 | 低 |
| 🟢 | 站外支付 | 3.1.1 | 仅 StoreKit | 低 |
| 🟢 | 最低功能 | 4.2 | CRUD/日历/通知/分析完整 | 低 |
| 🟡 | Universal 截图只传 iPhone | 2.3.3 | 截图目录空 | 中（上架后） |
| 🟡 | 金融类隐私标签漏报 iCloud | 5.1.1 | Manifest 收集类型空 ≠ 问卷可空 | 中 |

**经验判断（在补齐 ASC 阻塞项之后）**：一次通过约 **55–75%**。不改元数据额度、不挂 IAP、不测 CloudKit，会掉到 **40% 以下**。

---

## 1. 现在提交会直接失败的 ASC 项（先于审核员）

来源：`fastlane/builds/asc-validate.json`（errors: 3, warnings: 5）。

### 1.1 没有 Build — 🔴

**会被挡**：`no build attached to app store version`。

**方案**：Xcode Organizer Archive（Release，team `R9TC286V25`）→ Upload → 版本 1.0.0 选 build。旧包若在加 `ITSAppUsesNonExemptEncryption` 之前上传，**必须再传一包** 出口合规才会显示豁免。

### 1.2 没有 Availability — 🔴

**方案**：App Store Connect → Pricing and Availability 选择国家/地区。CLI 曾对部分 territory 报错，用网页。

### 1.3 没有截图 — 🔴

**方案**：至少一套必填机型。建议：

| 设备 | 用途 |
| :--- | :--- |
| iPhone 6.7" | 仪表盘、账单列表、日历、分析、设置/Paywall |
| iPad 13" | Universal 强烈建议，否则 2.3.3 / 用户投诉 |

禁止：未上架功能、竞品水印、误导价格。Paywall 截图须与真实三档价格一致（以商店地区价格为准）。

订阅 **审核用截图**（`fastlane/builds/iap_review.png`）与 **商店促销图** 不是同一要求。validate 对月/年 **promotional image** 仅为 warning，不挡提交。

---

## 2. 高概率被拒点与改法

### 2.1 Guideline 2.3.1 — 元数据与实际功能不符 — 🔴

商店写免费「分类和账户各最多 5」，代码账户上限 **3**。

**方案**：改 metadata（推荐）或把 `freeAccountLimit` 改为 5，再 `asc metadata apply`。审核备注不要写与代码冲突的数字。

同类：描述写 “unlimited bills”（代码确实不限账单）可以保留。不要写广告关闭、银行连接、自动扣款。Auto-Pay 已是「外部扣款标记」——截图/描述不要画成 Open Banking。

---

### 2.2 Guideline 2.1 — 内购买不了 / 商品空白 — 🟠

审核员打开 Paywall：若商品未随版本提交或未过审，列表为空（虽有 Retry，仍常按 2.1 拒）。

**方案**：

1. 版本页 **同时提交** Monthly / Yearly / Lifetime。  
2. 沙盒：三档购买、取消、Restore、Lifetime 与订阅互斥策略（同组订阅会升级；终身是非消耗型，确认不会「买了订阅仍显示未解锁」——当前 `purchasedProductIDs` 非空即 PRO，合理）。  
3. Review Notes 写清：Settings → Upgrade to PRO；沙盒账号；无需登录 App 账号。

---

### 2.3 Guideline 3.1.2(a) — 订阅缺少持续价值 — 🟠 已缓解、仍会被问

PRO：可选 iCloud、无限分类/账户、导出备份、App Lock、高级分析区间。订阅 + 终身同售，Apple 可接受，但可能问「为何月订与买断并存」。

**方案**：Paywall/描述强调 iCloud 为持续服务（跨设备同步）。审核备注：sync 默认关、PRO 专属、过期自动关并迁回本地。不要把一次性本地功能（例如一次性导出）写成订阅唯一价值。

---

### 2.4 Guideline 3.1.2(c) — 自动续订披露 — 🟠

已有：收费说明、24h 取消、EULA、隐私、Manage Subscriptions。  
缺口：UI 未单独展示 **subscription period length**（依赖商品名 “Monthly PRO” + `displayPrice`）。部分审核员要求价格旁写 `/month`、`/year`。

**方案**：绑定 `product.subscription.subscriptionPeriod`。中英商店描述已含「Manage in Settings → Apple ID → Subscriptions」和标准 EULA URL，保持。

---

### 2.5 Guideline 2.1 — iCloud / CloudKit 缺陷 — 🟠

审核员若打开 iCloud（需先买 PRO）：SwiftData unique 约束可能导致启动失败。强制「请重启 App」若数据丢失或一直 Restart banner，算崩溃/不完整。

**方案**：真机完整走：关→开同步→杀进程→开 App→第二台设备（若有）→过期关同步。Portal 确认容器 `iCloud.com.antigravity.billsmanager`。失败则 1.0 商店弱化 iCloud 或修好再提交。

---

### 2.6 Guideline 5.1.1(i) — 隐私政策 — 🟡

App 内 Settings + Paywall 有链接；ASC `privacyPolicyUrl` 已配 GitHub Pages。风险：Pages 404、HTTP、与问卷矛盾。

金融 + 可选 iCloud：**App 隐私问卷必须发布**。validate 写 `privacy.publish_state.unverified`（API 看不到，仍可能挡提交）。

**问卷建议（按当前设计，非法律意见）**：

- Tracking：**否**  
- 用于追踪的数据：无  
- 联系信息：无（无账号）  
- **财务信息 / 用户内容**：若用户开启 iCloud，经 Apple iCloud 同步账单；未开则仅设备  
- 照片：用户选收据，用于账单附件，不用于追踪  
- 不要勾 SKAdNetwork/广告  

**方案**：网页打开隐私页；问卷点 Publish；联系邮箱可用。

---

### 2.7 Guideline 2.3.7 / 2.3.8 — 名称与截图 — 🟠

名称 `Bills Manager - billsmanager` 像堆砌关键词。

**方案**：显示名 “Bills Manager”。截图不要假数据夸大“节省 $xx,xxx”（可用温和示例账单）。

---

### 2.8 Guideline 4.1 — 复制 / 垃圾应用 — 🟠

功能集与市面账单 App 高度相似。图标为通用账单风格则风险上升。当前 1024 PNG 已合规，但是否与某已上架 App 过近需目视对比。

**方案**：审核与 ASO 避免 “clone of Bills Monitor”。保留独特说明：本地优先、可选 iCloud、无广告、无银行连接。

---

### 2.9 Guideline 5.1.1(iii) — 权限 — 🟢 为主

| Key | 用途 | 风险 |
| :--- | :--- | :--- |
| `NSFaceIDUsageDescription` | 保护账单 | 低 |
| `NSPhotoLibraryUsageDescription` | 收据图 | 低–中：若只用 Picker，说明写「选择收据照片」即可 |
| 相机 | 已删除 | — |
| 跟踪 / IDFA | 无 | 不要弹 ATT |

Onboarding 在 Get Started 要通知权限，合理（提醒是核心功能）。

---

### 2.10 Guideline 2.3.3 / 4.2.3 — Universal 与 iPad — 🟡

工程 Universal + iPad `NavigationSplitView`。只传 iPhone 截图可能要补 iPad。iPad 分栏需真机看空白列（文档称已修）。

**方案**：iPad 截图 + 审核用 iPad 点一遍五栏。

---

### 2.11 出口合规 — 🟢 代码 / 🟡 旧 build

plist 与 Build Setting 已 `false`。仅新上传的 build 生效。

---

### 2.12 年龄分级与金融 — 🟡

账单金额、账户后四位：分级选不面向儿童；内容权利已 `DOES_NOT_USE_THIRD_PARTY_CONTENT`。不要标 4+ 却在隐私政策写收集儿童数据。

---

## 3. 较低但仍建议处理

| 项 | 说明 | 方案 |
| :--- | :--- | :--- |
| 订阅促销图 | warning | 可后补，不挡审 |
| 横向 iPhone | 可能裁切 | 限制 Portrait |
| 空 LaunchScreen | 白屏闪 | 补 Launch Screen |
| 无 Demo 账号 | 无登录，不需要 | Review Notes 写 “No account required” |
| 家庭共享 | 终身买断可开 Family Sharing（可选） | ASC IAP 配置 |
| Support URL | 与 marketing 同域 | 确保有实际帮助内容（如何备份、如何关订阅） |
| 审核联系电话 | 必须能打通 | 时区写 UTC+8 |

---

## 4. 提交前 Must / Should

### Must（不做几乎必挂）

- [ ] Archive 上传并选定 1.0.0 build  
- [ ] Pricing & Availability  
- [ ] iPhone 必填截图（建议加 iPad）  
- [ ] 隐私问卷 Publish + URL 可打开  
- [ ] 修正免费账户数量文案  
- [ ] 版本页勾选 3 个 IAP  
- [ ] 沙盒走通购买 + Restore  
- [ ] 真机：通知授权、标记已付、备份恢复、App Lock  
- [ ] 真机：PRO iCloud 开/关（或确认不会崩溃）  
- [ ] Developer Portal CloudKit 容器  

### Should

- [ ] Paywall 展示订阅时长  
- [ ] App 名称去掉 billsmanager 后缀  
- [ ] Review Notes（见下）  
- [ ] Organizer **Validate App**（Privacy Report）  
- [ ] 英文审核备注 + 隐私政策英文页（审核员多为英）  

---

## 5. 审核员路径（请自己先走一遍）

1. 启动 → Onboarding → 允许/拒绝通知 → 主界面有默认分类。  
2. 新建账单、日历点日期、仪表盘逾期。  
3. Settings → 通知状态；免费用户加第 4 个账户应出 Paywall。  
4. Paywall：三价格、隐私、条款、Restore、管理订阅。  
5. （沙盒）购买 → 导出 CSV/JSON → 开 App Lock → 开 iCloud（重启）→ 杀进程再进。  
6. 后台切走看模糊遮罩。  

任一步崩溃或 Paywall 空商品，按 2.1 拒。

---

## 6. 建议审核备注（英文，可贴 ASC）

```
Bills Manager is a local-first personal bill tracker. No user account or login.

IN-APP PURCHASE (please attach to this version):
• com.billsmanager.pro.monthly (auto-renewable)
• com.billsmanager.pro.yearly (auto-renewable)
• com.billsmanager.pro.lifetime (non-consumable)
All three unlock the same PRO entitlement. Path: Settings → Upgrade to PRO.

PRO includes: optional iCloud sync (OFF by default), unlimited custom categories
and accounts (free: 5 categories, 3 accounts), CSV/JSON backup, Face ID lock,
advanced analytics ranges.

iCloud: Settings → iCloud Sync (PRO). Requires iCloud account. Changing the
toggle asks you to force-quit and reopen the app to migrate the SwiftData store.
If PRO lapses, sync is turned off automatically.

Notifications: requested on onboarding and when saving a bill with a reminder.
Photos: user-picked receipt images only. Face ID: optional app lock.

Privacy Policy and Terms (Apple Standard EULA) are linked in Settings and Paywall.
Sandbox Apple ID is sufficient; no demo in-app account.
```

把备注里的 5/3 与代码保持一致。

---

## 7. 若被拒，常见回复方向

| 拒信关键词 | 动作 |
| :--- | :--- |
| 2.1 crash / bug | 修 CloudKit/启动；附新 build 录屏 |
| 2.1 IAP | 确认商品随版本；沙盒录屏购买 |
| 3.1.2 subscription | 加强 Paywall 时长/价格；说明 iCloud 持续价值 |
| 5.1 privacy | 修 URL、重发问卷、App 内入口截图 |
| 2.3.1 metadata | 改描述额度/名称后 Reply + 不必争辩 |
| 4.2 | 强调提醒+日历+周期+备份，给录屏 |

回复：**短、逐条、版本号、录屏**，不争论政策。

---

## 8. 结论

| 问题 | 现在能否 Submit | 建议 |
| :--- | :--- | :--- |
| ASC validate | **否**（无 build/截图/地区） | 先补齐 |
| 代码完成度 | 接近可审 | 先修元数据 5 vs 3、IAP 挂版本、CloudKit 真机 |
| 通过概率 | 补齐 Must 后中等偏好 | 不要在截图空、商品未挂时强提 |

更细的产品问题（测试、Double 金额、无障碍）见 `docs/APP_ISSUES_AND_SOLUTIONS.md`，多数不单独构成拒审，但会放大 2.1。
