# Bills Manager — App Store Connect 审核拒因风险评估与解决方案

> **首次评估**：2026-07-27
> **最近复评**：2026-07-29（基于 commit `ed42f4a`、Xcode 26.3 Debug Simulator 构建及 Apple 当前公开指南）
> **目标**：在当前代码与配置状态下，评估提交 **App Store Connect / App Review** 被拒概率与对应整改方案
> **参考**：App Store Review Guidelines（2.x 性能、3.x 商务、4.x 设计、5.x 法律与隐私等）
> **总体判断**：**高拒审风险**。Debug 构建成功，但原 Must 清单无一项在代码中关闭；最可能的拒因是 **隐私政策（5.1.1）、订阅持续价值与披露（3.1.2）、IAP 完整性（2.1）、误导性付费宣传（2.3.1）**。

## 复评状态说明

- `🔴 未关闭`：仓库可确认仍存在。
- `🟠 有进展但未闭环`：有实现骨架，仍不足以提交。
- `🟡 外部未知`：需要 ASC、沙盒、真机或 Archive 证明。
- `🟢 已验证`：本次已有直接证据。

| 复评证据 | 结果 |
| :--- | :--- |
| Debug Simulator 构建 | 🟢 成功 |
| Release Archive / 上传验证 | 🟡 未执行、无 CI 证据 |
| 隐私政策 / Terms App 内入口 | 🔴 仍无 |
| PRO 门控 | 🔴 仍无 |
| 通知权限请求 | 🔴 仍无调用 |
| StoreKit 商品加载失败反馈 | 🔴 空数组永久 Loading |
| App Icon | 🟢 Asset Catalog 可编译；源文件仍建议标准化为 PNG |

---

## 0. 风险总览（提交前检查表）

| 风险等级 | 拒因方向 | Guideline | 2026-07-29 状态 | 预估拒审概率 |
| :---: | :--- | :--- | :--- | :---: |
| 🔴 高 | 自动续订订阅缺少持续价值 | 3.1.2(a) | 🔴 月/年订阅仅解锁与买断相同的静态本地功能 | 高 |
| 🔴 高 | 自动续订订阅信息披露不全 | 3.1.2(c) | 🔴 Paywall 缺完整订阅说明、Terms/隐私链接 | 高 |
| 🔴 高 | 隐私政策缺失/不可访问 | 5.1.1(i) | 🔴 App 内未见隐私 URL；ASC 元数据外部未知 | 高 |
| 🔴 高 | 内购无法完成 / 商品加载失败 | 2.1(b) | 🟡 ASC 商品未知；无共享测试 Scheme；空商品无错误/重试 | 高 |
| 🟠 中高 | 付费功能名不副实 / 误导 | 2.3.1 / 3.1.1 | 🔴 PRO 权益未门控；宣称 Ad-Free 但全 App 无广告 | 中高 |
| 🟠 中 | 权限用途不准确 | 5.1.1(iii) | 🔴 声明相机但未提供相机入口 | 中低–中 |
| 🟢 低 | App 图标构建兼容 | 2.3 / 上传资产 | 🟢 JPEG 源图已由 Asset Catalog 成功编译；建议换 PNG，但非已证实拒因 | 低 |
| 🟠 中 | 恢复购买与订阅管理 | 3.1.1 / 3.1.2 | 🟠 有 Restore，缺管理订阅入口与成功/失败反馈 | 中 |
| 🟡 中 | 隐私清单 Privacy Manifest | 5.1 / 平台要求 | 🔴 未见 `PrivacyInfo.xcprivacy`；Required Reason API 仍需核对 | 中 |
| 🟡 中低 | 最低功能完整度 | 4.2 | 作为账单工具基本够用 | 低（若核心能用） |
| 🟠 中 | 明显缺陷 / 数据可信 | 2.1(a) | 🔴 通知不工作；首次 Seed 高概率重复；周期撤销/追赶不正确 | 中 |
| 🟢 低 | 登录墙 | 5.1.1(v) | 无强制账号 ✔ | 低 |
| 🟢 低 | 使用非 IAP 支付数字内容 | 3.1.1 | 仅 StoreKit ✔ | 低 |

---

## 1. 高风险拒因详解与解决方案

### 1.0 Guideline 3.1.2(a) — 订阅持续价值不足 — 🔴 未关闭（新增）

Apple 明确要求自动续订订阅为用户提供持续价值。当前月付、年付与 Lifetime PRO 解锁完全相同的一组静态、本地功能；没有云服务、持续内容、订阅期服务或可审查的持续重大更新计划。审核员可能质疑为何同一永久功能需要持续收费。

**建议**

1. 风险最低：首版仅保留 Lifetime PRO（Non-Consumable），下架月/年订阅入口。
2. 若坚持订阅：先落地可持续交付的权益，例如跨设备云同步、持续新增的高级分析或服务，并在 Paywall、商品描述与 Review Notes 明确说明。
3. 不要只写“持续更新”；需能证明订阅期内确实持续提供价值。

依据：[Apple App Review Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/)。

### 1.1 Guideline 3.1.2(c) — 自动续订订阅信息不足 — 🔴 未关闭

**为何会被拒**
App 提供 `monthly` / `yearly` 自动续订订阅时，Apple 要求在 App 内清晰展示（通常在订阅购买页）：

1. 名称：订阅名称 / 时长
2. 价格：及对应周期（从 StoreKit `Product` 读取更佳）
3. 自动续订说明：确认购买后扣费、续订规则
4. 取消方式：可随时在设置中取消，且需在续订前 24 小时取消等标准表述
5. **功能级隐私政策链接** 与 **使用条款（EULA）链接**
6. 若有免费试用：明确试用时长与转正价格（StoreKit 配置 / ASC 优惠）

**当前代码缺口**（`PaywallView`）：

- 仅有一句笼统 “Payment will be charged to your Apple ID…”
- **无** Privacy Policy / Terms of Use 可点链接
- **无** 自动续订取消说明
- Feature 列表写 “Ad-Free” 等可能不实内容
- StoreKit.storekit **未配置 introductory offer**（与 PRD“首周免费试用”不一致）

**解决方案（审核通过最低集）**

1. Paywall 底部固定法律区（中英本地化）：

```
• 订阅名称与时长（月/年）
• 价格（product.displayPrice）/ 周期
• 订阅到期前 24 小时内扣费并自动续订
• 取消路径：设置 → Apple ID → 订阅
• 链接：隐私政策 | 使用条款（或标准 Apple EULA）
• 「恢复购买」按钮（已有，保留并处理错误 Alert）
```

2. 增加：

```swift
Link("Privacy Policy", destination: URL(string: "https://your.domain/privacy")!)
Link("Terms of Use", destination: URL(string: "https://your.domain/terms")!)
// 或
Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
```

3. ASC 订阅组、本地化描述、截图、审核备注与 App 内价格一致
4. PRD 写了免费试用：要么在 ASC 配置 Introductory Offer，要么删掉所有“免费试用”营销文案
5. 提供 **管理订阅** 深链：`https://apps.apple.com/account/subscriptions`

**审核备注建议（App Review Notes）**
说明沙盒测试账号、订阅商品 ID 列表、如何打开 Paywall、是否需要特殊配置。

---

### 1.2 Guideline 5.1.1(i) — 隐私政策 — 🔴 未关闭

**为何会被拒**
即使数据 100% 本地，只要 App 上架且涉及用户数据（账单金额、账户尾号、收据图、标识符等），Apple **几乎总是要求** 可访问的隐私政策：

- App Store Connect → App 隐私 / 隐私政策 URL
- App 内设置（强烈建议）也放置同一链接

金融相关数据在问卷中需诚实申报（Collected? Linked? Tracking?）。

**当前状态**
- Settings / Onboarding / Paywall **无隐私政策链接**
- 未见独立托管页面资产
- Apple 当前指南明确要求所有 App 同时在 ASC 元数据和 App 内易访问位置提供隐私政策；“数据只在本地”不构成豁免

**解决方案**

1. 发布静态页（GitHub Pages / 自有域名均可），至少包含：
   - 收集哪些数据（默认：不上传服务器）
   - 本地存储位置与用途
   - 照片/Face ID/通知权限用途
   - 第三方：Apple StoreKit 处理支付
   - 联系邮箱
   - 儿童政策（若 4+：不面向 13 岁以下收集）
2. ASC 填写 Privacy Policy URL
3. App 隐私问卷：通常选不收集 / 仅设备本地；**不要**误勾 Tracking
4. Settings → About 增加 Privacy Policy 行

---

### 1.3 Guideline 2.1 — 应用完成度 / 内购无法验证 — 🔴/🟡 未闭环

**常见拒审场景**

| 场景 | 本项目触发条件 |
| :--- | :--- |
| 内购按钮无响应 / 一直 Loading | ASC 未创建完全一致的 Product ID、协议/销售状态未完成，或加载失败 |
| 购买成功但无功能变化 | **PRO 未门控**，审核员认为 IAP 无意义或误导 |
| 明显半成品 | 通知从不弹、备份不可恢复、设置项无效、商品错误永久 Loading |
| 崩溃 | `fatalError` 初始化失败等极端路径 |

**解决方案**

1. 先决定是否保留订阅；ASC 创建对应商品，ID 与代码 **完全一致**
2. 实现真实 PRO 差异（至少 2–3 个可感知功能）
3. 沙盒账号自测：购买、中断、恢复、退款/撤销（`revocationDate` 已处理）
4. 提交共享 Scheme 并绑定本地 StoreKit Configuration；注意 **Product ID 无需与 Bundle ID 使用相同前缀**，旧版文档把这一点误写成了技术失败条件
5. Paywall 对空商品展示明确错误和重试，不得永久 Loading
6. Review Notes 写清路径：设置 → Upgrade to PRO
7. 修复通知权限请求，避免“宣传有提醒但完全不可用”被记 2.1
8. 二进制用 Release 配置、有效签名、正确版本号递增；当前构建产物仍为 `1.0.0 (1)`，并未采用工程中的 `CURRENT_PROJECT_VERSION=2026072601`

---

### 1.4 Guideline 2.3.1 / 3.1.1 — 元数据与付费内容误导 — 🔴 未关闭

**风险点**

- 宣传 “Ad-free” 但应用 **无广告** → 审核或用户视为虚假卖点
- 宣传 Face ID / 导出 / 无限分类为 PRO，实际免费全开 → “In-App Purchase 不必要/不工作”
- 截图若展示不存在功能（趋势对比、模糊遮罩、试用）会被 2.3.1
- 名称/截图若过度模仿已有 “Bills Manager / Bills Monitor” 品牌，可能有 5.2 知识产权投诉风险（概率取决于元数据，非代码问题）

**解决方案**

1. 统一 **营销文案 = 实际行为**（二选一：真门控 or 改成“可选打赏/买断解锁未来功能”并改 PRD）
2. 去掉 Ad-Free，除非接入 ATT 合规广告
3. 截图只用真机录屏级真实 UI
4. 副标题/关键词避免误导性金融承诺（“提高信用分”“自动还贷”等）

---

## 2. 中等风险拒因

### 2.1 Guideline 5.1.1 — 权限字符串与用途 — 🔴 未关闭

| Key | 现状 | 风险 | 方案 |
| :--- | :--- | :--- | :--- |
| `NSFaceIDUsageDescription` | 有，用途合理 | 低 | 保持；中英可考虑 InfoPlist.xcstrings |
| `NSPhotoLibraryUsageDescription` | 有 | 低 | PhotosPicker 场景下可保留简洁说明 |
| `NSCameraUsageDescription` | 有但 **无相机功能** | 中 | **删除** 或实现拍照 |

审核员可能问：为何申请相机？答不上或动态检查无调用仍可能被要求解释。

### 2.2 App 图标与上传资产 — 🟢 构建通过，仍建议标准化

- 当前 `AppIcon.jpg`：JPEG、1024×1024、无 alpha。
- 本次 Xcode 26.3 Asset Catalog 已成功产出 iPhone/iPad 图标，未出现 actool 警告，因此不能再把 JPEG 源图直接判定为中等拒审风险。
- 仍建议保留一份 sRGB、1024×1024、无透明、无圆角的 PNG 标准源资产，并通过 Release Archive / Organizer Validate 做最终上传校验。

**方案**：标准化为 sRGB PNG；勿含透明通道；勿叠加“上架角标”。该项优先级低于隐私、订阅和 IAP 闭环。

### 2.3 Privacy Manifest（`PrivacyInfo.xcprivacy`）— 🔴 未关闭

- 工程未见隐私清单
- App 明确使用 UserDefaults（`@AppStorage` / `UserDefaults.standard`）等能力；需按当前 Required Reason API 清单核对并填写批准理由，不能靠“无第三方 SDK”直接判断无需清单

**方案**：用 Xcode 生成 Privacy Report；添加 `PrivacyInfo.xcprivacy`，按实际 API 与数据行为填写；再用 Archive Validate 验证。参考 [Apple Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)。

### 2.4 加密出口合规问卷 — 🟡 外部待核验

- 仅 HTTPS / 系统 API 通常选标准豁免
- Info 可设 `ITSAppUsesNonExemptEncryption = false`（若适用）

避免误答导致法务问卷反复。

### 2.5 恢复购买体验 — 🟠 部分实现

- 有 `restorePurchases` ✔
- 失败仅设 `purchaseErrorMessage`，UI **可能不展示**
- 无“已恢复成功”Toast

**方案**：Alert 成功/失败；已是 PRO 时禁用购买按钮并显示状态。

### 2.6 账号与数据删除 — 🟢 当前无账号

- 无账号 ✔（减少 5.1.1(v) 负担）
- 若未来做 iCloud/账号，必须提供删除账户路径

---

## 3. 较低但仍建议处理的问题

### 3.1 Guideline 4.2 — Minimum Functionality — 🟢 低风险

账单 CRUD + 日历 + 分析作为工具 App **通常可通过**。
风险主要来自“空壳 + 仅 IAP”，本项目内容足够，**前提是主流程不崩、IAP 可验证**。

### 3.2 Guideline 4.0 设计 / 4.1 复制 — 🟢/🟡 代码低风险、元数据待核验

- UI 为标准 SwiftUI，风险低
- 避免直接使用受保护的商标名、竞品 ICON

### 3.3 本地化与审核地区 — 🔴 体验问题仍存在

- 若 ASC 选中文区主语言，App 内大量英文可能被批“本地化不完整”（少见硬拒，影响体验评分）
- 权限描述目前仅英文：建议与 App 主语言一致

### 3.4 角标与通知 — 🔴 未关闭

- 使用 Badge 需通知授权；未授权时 `setBadgeCount` 可能无效
- 不构成硬拒，但审核员点进账单设提醒却无系统弹窗，可能写 2.1 “功能不工作”

### 3.5 示例数据 — 🔴 需先修复 Seed

- 首次打开有示例账单，有助于审核理解产品 ✔
- 但 Seed 代码多次创建 `Category.defaults` / `Account.defaults`，高概率产生重复默认分类和账户；应先用干净安装验证并修复
- 建议 Review Notes 说明：“首次安装含示例数据，可删除”

### 3.6 周期与金额边界 — 🔴 未关闭

- `0`、负数及非有限金额缺少校验，逗号小数地区可能无法保存合法金额。
- 月末周期会发生 `1/31 → 2/28 → 3/28` 漂移；跨多期逾期只推进一期；周期支付无法正确撤销。
- 审核员未必覆盖这些边界，但它们会降低 Guideline 2.1(a) 的“完成度/明显缺陷”判断，属于正式运营前必须补测试的财务可信问题。

---

## 4. App Store Connect 元数据检查清单（代码外）

提交前在 ASC 逐项确认：

| 项目 | 要求 | 状态建议 |
| :--- | :--- | :--- |
| 隐私政策 URL | 可公网打开、HTTPS | 必须新建 |
| 类别 | 财务 Finance 等 | 合理选择 |
| 年龄分级 | 无 UGC/社交通常 4+ | 诚实填写 |
| App 隐私问卷 | 与真实行为一致 | 本地存储为主 |
| IAP 商品 | 三件套 + 订阅本地化 + 审核截图 | 与代码 ID 一致 |
| 订阅群组 | 月/年同组互斥 | 配置 |
| 审核联系信息 | 电话/邮箱畅通 | 必须 |
| 审核备注 | 测试账号（若需要）、IAP 路径 | 强烈建议 |
| 截图 | 6.7/6.5/12.9 等必填尺寸 | 真实 UI |
| 出口合规 | 加密问卷 | 准确 |
| 内容版权 | 图标/文案自有 | 自查 |
| 版本号 | CFBundleShortVersionString / Build | 递增 |
| 加密/登录 | 无 | OK |

---

## 5. 审核员典型操作路径（请自测）

请用 **未购买的沙盒新号** 按下列路径走通：

1. 安装 → Splash → Onboarding → 主页
2. 查看示例账单 → 打开详情 → Mark Paid → 编辑 → 删除
3. 新建账单 → 设置提前提醒 → **观察是否弹出通知权限**
4. 日历点选日期 → 分析页切换时间范围
5. 设置 → 开 Face ID 锁 → 杀进程/回后台再进 → 解锁
6. 设置 → Upgrade to PRO → 加载价格 → 购买月/年/买断 → 权益变化
7. 删除 App 重装 → Restore Purchases
8. 导出 CSV / JSON（若 PRO 限制，确认拦截与解锁）
9. 中文系统语言下浏览主要文案

任一步骤失败，都可能变成 2.1 拒信。

---

## 6. 拒信场景 → 回复/整改对照

| 拒信关键词 | 优先改什么 |
| :--- | :--- |
| *Subscription information* / 3.1.2 | Paywall 法律文案 + 隐私/条款链接 |
| *Privacy Policy* | 上线网页 + ASC URL + App 内链接 |
| *In-App Purchase* / *could not find* | Product ID、协议、Paid Apps、沙盒 |
| *does not work* / *bug* | 通知、购买后权益、崩溃日志 |
| *misleading* | 改文案或真门控 PRO、去 Ad-Free |
| *permission* / *camera* | 删 Camera key 或实现相机 |
| *Guideline 2.3.3* 截图 | 更新真实截图 |
| *4.2 Minimum* | 充实功能说明；确保非空壳 |

回复审核时：**简短、逐条、附截图/录屏、说明版本号**，勿争辩政策本身。

---

## 7. 提交前 48 小时行动清单（按优先级）

### Must（强烈建议完成后再点 Submit）

- [ ] 🔴 托管并填写 **隐私政策 URL**；App 内可点
- [ ] 🔴 决定仅永久买断，或为月/年订阅提供可证明的 **持续价值**
- [ ] 🔴 Paywall 补齐 **3.1.2 订阅披露** + Terms / Privacy 链接
- [ ] 🟡 ASC 配置实际保留的 IAP，ID 与代码一致；沙盒购买成功
- [ ] 🔴 实现至少一组 **可感知 PRO 门控**（或下调所有 PRO 宣传）
- [ ] 🔴 去掉虚假 **Ad-Free**（或真接广告）
- [ ] 🔴 **通知权限**请求接通
- [ ] 🔴 修复首次 Seed 重复风险及周期支付/撤销核心缺陷
- [ ] 🔴 删除未使用的 **NSCameraUsageDescription**（或实现相机）
- [ ] 🔴 自测第 5 节全路径

### Should

- [ ] 🔴 `PrivacyInfo.xcprivacy` + Archive Privacy Report / Validate
- [ ] 🔴 共享 Scheme 绑定 StoreKit Configuration
- [ ] 🔴 商品加载错误/重试、恢复购买成功/失败 UI
- [ ] 🔴 管理订阅链接
- [ ] 🔴 中英关键文案与权限描述
- [ ] 🔴 JSON 恢复或弱化“全量备份”文案
- [ ] 🔴 统一版本号，Release Archive 使用递增 Build Number
- [ ] 🔴 Review Notes 英文清晰说明

### Nice

- [ ] App Icon 标准源资产改为 PNG
- [ ] 后台隐私模糊
- [ ] 完整本地化
- [ ] 单测保护周期账单逻辑

---

## 8. 风险评分小结

| 若你现在直接上传现有二进制 + 未补齐 ASC 元数据 | 经验性预估（非 Apple 官方概率） |
| :--- | :--- |
| 一次通过 | **很低（约 5–15%）** |
| 一次或二次拒审后通过 | **中高**（补齐隐私+订阅+IAP 后大幅上升） |
| 多次卡在商务/误导 | 若坚持“静态功能订阅 + PRO 不门控 + Ad-Free 虚假” |

| 完成第 7 节 Must 清单后 | 预估 |
| :--- | :--- |
| 一次通过 | **中高（约 60–80%）**（经验判断；仍取决于二进制、截图、问卷与具体审核） |

---

## 9. 建议的审核备注模板（英文）

> 仅在对应功能已经实现并完成沙盒/真机验证后使用；不要把下列未来态描述原样提交。

```text
Thanks for reviewing Bills Manager.

• App type: Local-first personal bill tracker (SwiftData). No account/login.
• Sample data: Three sample bills are inserted on first launch and can be deleted.
• Premium (StoreKit 2):
  - com.xxx.pro.lifetime (non-consumable)
  - com.xxx.pro.monthly / yearly (auto-renewable, group: …; omit if subscriptions are removed)
  - Ongoing subscription value: <describe the actually delivered ongoing service>
  - Entry: Settings → Upgrade to PRO
  - Restore: Paywall → Restore Purchases
• Notifications: When saving a bill with a reminder, the app requests notification permission.
• Face ID: Settings → Lock with Face ID (optional).
• No third-party analytics/ads; data stays on device.

Sandbox Apple ID: <provide if needed>
```

---

## 10. 文档维护

| 项 | 值 |
| :--- | :--- |
| 文档路径 | `docs/APP_STORE_REVIEW_RISKS.md` |
| 关联 | `docs/APP_ISSUES_AND_SOLUTIONS.md`（工程问题详单） |
| 本次状态同步 | 2026-07-29：原 Must 项均未关闭；新增订阅持续价值、Seed/周期数据可信与版本配置风险；下调 JPEG 图标、Product ID 前缀风险 |
| 政策更新 | Apple 指南可能变更，提交前请再读最新 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) |

---

*本文件基于全量源码/配置通读、Debug Simulator 构建与 Apple 公开指南复核，不构成法律意见，也未替代 Release Archive、Organizer Validate、真机通知、StoreKit 沙盒与 ASC 元数据人工核对。文中概率为经验性风险表达，不是 Apple 官方统计。*
