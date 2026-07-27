# Bills Manager — App Store Connect 审核拒因风险评估与解决方案

> **评估日期**：2026-07-27  
> **目标**：在当前代码与配置状态下，评估提交 **App Store Connect / App Review** 被拒概率与对应整改方案  
> **参考**：App Store Review Guidelines（2.x 性能、3.x 商务、4.x 设计、5.x 法律与隐私等）  
> **总体判断**：**中高拒审风险**。功能型工具 App 本身可通过 4.2，但 **订阅合规（3.1.2）、隐私政策（5.1.1）、内购完整性（2.1）、元数据/图标、误导性付费宣传** 是当前最可能的拒因组合。

---

## 0. 风险总览（提交前检查表）

| 风险等级 | 拒因方向 | Guideline | 当前状态 | 预估拒审概率 |
| :---: | :--- | :--- | :--- | :---: |
| 🔴 高 | 自动续订订阅信息披露不全 | 3.1.2 | Paywall 缺完整订阅法律文案、EULA/隐私链接 | 高 |
| 🔴 高 | 隐私政策缺失/不可访问 | 5.1.1 | App 内与预期 ASC 元数据均未见隐私 URL | 高 |
| 🔴 高 | 内购无法完成 / 商品加载失败 | 2.1 | Product ID 与 Bundle 不一致；ASC 未配齐则空商品 | 高 |
| 🟠 中高 | 付费功能名不副实 / 误导 | 2.3.1 / 3.1.1 | PRO 权益未门控；宣称 Ad-Free 但无广告 | 中高 |
| 🟠 中高 | 权限用途不准确 | 5.1.1 | 声明相机但未使用相机 | 中 |
| 🟠 中 | App 图标格式/规范 | 2.3 / 上传资产 | 1024 Icon 为 JPEG | 中 |
| 🟠 中 | 恢复购买与订阅管理 | 3.1.1 / 3.1.2 | 有 Restore，缺管理订阅入口与失败反馈 | 中 |
| 🟡 中低 | 隐私清单 Privacy Manifest | 5.1 / 平台要求 | 未见 `PrivacyInfo.xcprivacy` | 中低–中 |
| 🟡 中低 | 最低功能完整度 | 4.2 | 作为账单工具基本够用 | 低（若核心能用） |
| 🟡 中低 | 崩溃 / 明显缺陷 | 2.1 | 通知不工作、示例数据等属体验问题 | 中（若审核员测提醒） |
| 🟢 低 | 登录墙 | 5.1.1(v) | 无强制账号 ✔ | 低 |
| 🟢 低 | 使用非 IAP 支付数字内容 | 3.1.1 | 仅 StoreKit ✔ | 低 |

---

## 1. 高风险拒因详解与解决方案

### 1.1 Guideline 3.1.2 — 自动续订订阅信息不足

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

### 1.2 Guideline 5.1.1 — 隐私政策

**为何会被拒**  
即使数据 100% 本地，只要 App 上架且涉及用户数据（账单金额、账户尾号、收据图、标识符等），Apple **几乎总是要求** 可访问的隐私政策：

- App Store Connect → App 隐私 / 隐私政策 URL  
- App 内设置（强烈建议）也放置同一链接  

金融相关数据在问卷中需诚实申报（Collected? Linked? Tracking?）。

**当前状态**  
- Settings / Onboarding / Paywall **无隐私政策链接**  
- 未见独立托管页面资产  

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

### 1.3 Guideline 2.1 — 应用完成度 / 内购无法验证

**常见拒审场景**

| 场景 | 本项目触发条件 |
| :--- | :--- |
| 内购按钮无响应 / 一直 Loading | ASC 未创建与代码一致的 Product ID；Bundle 与商品不匹配 |
| 购买成功但无功能变化 | **PRO 未门控**，审核员认为 IAP 无意义或误导 |
| 明显半成品 | 通知从不弹、备份不可恢复、设置项无效 |
| 崩溃 | `fatalError` 初始化失败等极端路径 |

**解决方案**

1. ASC 创建 Non-Consumable + 2 个 Auto-Renewable，ID 与代码 **完全一致**  
2. 实现真实 PRO 差异（至少 2–3 个可感知功能）  
3. 沙盒账号自测：购买、中断、恢复、退款/撤销（`revocationDate` 已处理）  
4. Review Notes 写清路径：设置 → Upgrade to PRO  
5. 修复通知权限请求，避免“宣传有提醒但完全不可用”被记 2.1  
6. 二进制用 Release 配置、有效签名、正确版本号递增  

---

### 1.4 Guideline 2.3.1 / 3.1.1 — 元数据与付费内容误导

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

### 2.1 Guideline 5.1.1 — 权限字符串与用途

| Key | 现状 | 风险 | 方案 |
| :--- | :--- | :--- | :--- |
| `NSFaceIDUsageDescription` | 有，用途合理 | 低 | 保持；中英可考虑 InfoPlist.xcstrings |
| `NSPhotoLibraryUsageDescription` | 有 | 低 | PhotosPicker 场景下可保留简洁说明 |
| `NSCameraUsageDescription` | 有但 **无相机功能** | 中 | **删除** 或实现拍照 |

审核员可能问：为何申请相机？答不上或动态检查无调用仍可能被要求解释。

### 2.2 App 图标与上传资产

- 当前 `AppIcon.jpg`：JPEG、1024×1024、无 alpha  
- Apple 营销图标要求：**1024×1024，PNG，无 alpha，无圆角**（以当前 ASC 校验为准）  
- JPEG 可能导致 Transporter / Xcode 校验警告或失败  

**方案**：导出 sRGB PNG；勿含透明通道；勿叠加“上架角标”。

### 2.3 Privacy Manifest（`PrivacyInfo.xcprivacy`）

- 工程未见隐私清单  
- 若使用“Required Reason API”（UserDefaults、file timestamp 等常见 API），新 SDK 规则下可能需要声明  

**方案**：用 Xcode 生成 Privacy Report；添加 `PrivacyInfo.xcprivacy`，按实际 API 填写；本 App 无第三方 SDK 时相对简单。

### 2.4 加密出口合规问卷

- 仅 HTTPS / 系统 API 通常选标准豁免  
- Info 可设 `ITSAppUsesNonExemptEncryption = false`（若适用）  

避免误答导致法务问卷反复。

### 2.5 恢复购买体验

- 有 `restorePurchases` ✔  
- 失败仅设 `purchaseErrorMessage`，UI **可能不展示**  
- 无“已恢复成功”Toast  

**方案**：Alert 成功/失败；已是 PRO 时禁用购买按钮并显示状态。

### 2.6 账号与数据删除

- 无账号 ✔（减少 5.1.1(v) 负担）  
- 若未来做 iCloud/账号，必须提供删除账户路径  

---

## 3. 较低但仍建议处理的问题

### 3.1 Guideline 4.2 — Minimum Functionality

账单 CRUD + 日历 + 分析作为工具 App **通常可通过**。  
风险主要来自“空壳 + 仅 IAP”，本项目内容足够，**前提是主流程不崩、IAP 可验证**。

### 3.2 Guideline 4.0 设计 / 4.1 复制

- UI 为标准 SwiftUI，风险低  
- 避免直接使用受保护的商标名、竞品 ICON  

### 3.3 本地化与审核地区

- 若 ASC 选中文区主语言，App 内大量英文可能被批“本地化不完整”（少见硬拒，影响体验评分）  
- 权限描述目前仅英文：建议与 App 主语言一致  

### 3.4 角标与通知

- 使用 Badge 需通知授权；未授权时 `setBadgeCount` 可能无效  
- 不构成硬拒，但审核员点进账单设提醒却无系统弹窗，可能写 2.1 “功能不工作”

### 3.5 示例数据

- 首次打开有示例账单，有助于审核理解产品 ✔  
- 建议 Review Notes 说明：“首次安装含示例数据，可删除”

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

- [ ] 托管并填写 **隐私政策 URL**；App 内可点  
- [ ] Paywall 补齐 **3.1.2 订阅披露** + Terms 链接  
- [ ] ASC 配置 **3 个 IAP**，ID 与代码一致；沙盒购买成功  
- [ ] 实现至少一组 **可感知 PRO 门控**（或下调所有 PRO 宣传）  
- [ ] 去掉虚假 **Ad-Free**（或真接广告）  
- [ ] **通知权限**请求接通  
- [ ] App Icon 改为合规 **PNG**  
- [ ] 删除未使用的 **NSCameraUsageDescription**（或不使用则删）  
- [ ] 自测第 5 节全路径  

### Should

- [ ] `PrivacyInfo.xcprivacy`  
- [ ] 恢复购买成功/失败 UI  
- [ ] 管理订阅链接  
- [ ] 中英关键文案与权限描述  
- [ ] JSON 恢复或弱化“全量备份”文案  
- [ ] Review Notes 英文清晰说明  

### Nice

- [ ] 后台隐私模糊  
- [ ] 完整本地化  
- [ ] 单测保护周期账单逻辑  

---

## 8. 风险评分小结

| 若你现在直接上传现有二进制 + 空 ASC 元数据 | 预估 |
| :--- | :--- |
| 一次通过 | **低（约 10–25%）** |
| 一次或二次拒审后通过 | **中高**（补齐隐私+订阅+IAP 后大幅上升） |
| 多次卡在商务/误导 | 若坚持“PRO 宣传但不门控 + Ad-Free 虚假” |

| 完成第 7 节 Must 清单后 | 预估 |
| :--- | :--- |
| 一次通过 | **中高（约 60–80%）**（仍取决于截图/问卷/随机审核） |

---

## 9. 建议的审核备注模板（英文）

```text
Thanks for reviewing Bills Manager.

• App type: Local-first personal bill tracker (SwiftData). No account/login.
• Sample data: Three sample bills are inserted on first launch and can be deleted.
• Premium (StoreKit 2):
  - com.xxx.pro.lifetime (non-consumable)
  - com.xxx.pro.monthly / yearly (auto-renewable, group: …)
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
| 政策更新 | Apple 指南可能变更，提交前请再读最新 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) |

---

*本文件为基于当前仓库的合规与审核风险评估，不构成法律意见。正式上架请以 Apple 最新指南与 ASC 实时校验为准。*
