# Bills Manager — App Store Connect 审核拒因风险评估与解决方案

> **首次评估**：2026-07-27
> **最近复评**：2026-08-06（对齐 `docs/APP_ISSUES_AND_SOLUTIONS.md`，真机 Debug 构建；commit 见主仓 `e150306` 一带）
> **目标**：在当前代码与配置状态下，评估提交 **App Store Connect / App Review** 被拒概率与对应整改方案
> **参考**：App Store Review Guidelines（2.x 性能、3.x 商务、4.x 设计、5.x 法律与隐私等）
> **总体判断**：**中等偏低拒审风险（相对 7 月底）**。可代码闭环的 P0/P1 与多数 P2 已关闭：买断策略、隐私/条款入口、PRO 门控、通知、备份恢复、Privacy Manifest、PNG Icon、共享 StoreKit Scheme。主要剩余：**ASC 商品是否已创建（🟡）**、**沙盒全路径验收**、**测试/CI（⏭）**、**Release Archive 证据**。

## 复评状态说明

- `🔴 未关闭`：仓库可确认仍存在。
- `🟠 有进展但未闭环`：有实现骨架，仍不足以提交。
- `🟡 外部未知`：需要 ASC、沙盒、真机或 Archive 证明。
- `🟢 已验证`：本次已有直接证据。

| 复评证据 | 结果 |
| :--- | :--- |
| Debug 真机构建 | 🟢 成功（`00008110-001A5CA22E3A201E`） |
| Release Archive / 上传验证 | 🟡 未执行、无 CI 证据 |
| 隐私政策 / Terms App 内入口 | 🟢 Settings + Paywall（`LegalLinks`） |
| PRO 门控 | 🟢 `ProFeature` + 限额 |
| 通知权限请求 | 🟢 Onboarding / 保存账单 / 设置页 |
| StoreKit 商品加载失败反馈 | 🟢 错误文案 + Retry；购买失败 Alert |
| App Icon | 🟢 1024 PNG |
| Privacy Manifest | 🟢 `PrivacyInfo.xcprivacy` |
| 共享 StoreKit Scheme | 🟢 `xcshareddata/.../BillsManager.xcscheme` |
| ASC 商品是否已创建 | 🟡 需人工核验 |

---

## 0. 风险总览（提交前检查表）

| 风险等级 | 拒因方向 | Guideline | 2026-08-06 状态 | 预估拒审概率 |
| :---: | :--- | :--- | :--- | :---: |
| 🟢 低 | 自动续订订阅缺少持续价值 | 3.1.2(a) | 🟢 Paywall **仅出售 Lifetime**；月/年仅 Restore | 低 |
| 🟢 低 | 自动续订订阅信息披露不全 | 3.1.2(c) | 🟢 买断披露 + 隐私/条款 + 管理订阅链接 | 低 |
| 🟠 中 | 隐私政策缺失/不可访问 | 5.1.1(i) | 🟢 App 内链接已有；ASC 元数据 URL 🟡 | 中（看 ASC） |
| 🟡 中 | 内购无法完成 / 商品加载失败 | 2.1(b) | 🟢 Scheme/Retry/错误提示；ASC 商品 🟡 | 中（看 ASC） |
| 🟢 低 | 付费功能名不副实 / 误导 | 2.3.1 / 3.1.1 | 🟢 门控落地；Ad-Free/趋势等文案已修正 | 低 |
| 🟢 低 | 权限用途不准确 | 5.1.1(iii) | 🟢 已删除未使用的相机声明 | — |
| 🟢 低 | App 图标构建兼容 | 2.3 / 上传资产 | 🟢 PNG 1024 | 低 |
| 🟢 低 | 恢复购买与订阅管理 | 3.1.1 / 3.1.2 | 🟢 Restore 反馈 + 管理订阅入口 | 低 |
| 🟢 低 | 隐私清单 Privacy Manifest | 5.1 / 平台要求 | 🟢 已添加；Archive Validate 仍建议人工跑 | 低–中 |
| 🟡 中低 | 最低功能完整度 | 4.2 | 🟢 核心 CRUD/通知/备份可用 | 低 |
| 🟢 低 | 明显缺陷 / 数据可信 | 2.1(a) | 🟢 通知/Seed/周期/分析口径已修 | 低 |
| 🟢 低 | 登录墙 | 5.1.1(v) | 无强制账号 ✔ | 低 |
| 🟢 低 | 使用非 IAP 支付数字内容 | 3.1.1 | 仅 StoreKit ✔ | 低 |

---

## 1. 高风险拒因详解与解决方案

### 1.0 Guideline 3.1.2(a) — 订阅持续价值不足 — 🟢 已解决（产品决策）

Paywall **仅出售** Non-Consumable 永久买断（`com.billsmanager.pro.lifetime`）。月/年订阅 ID 仅用于 Restore / 历史 entitlement，不再作为在售商品。

依据：[Apple App Review Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/)。

### 1.1 Guideline 3.1.2(c) — 自动续订订阅信息不足 — 🟢 已解决（随买断策略）

买断披露 + 隐私/条款链接 + Restore + 管理订阅入口已落地。若未来重新上架自动续订，再按 3.1.2(c) 补齐完整订阅文案。

---

### 1.2 Guideline 5.1.1(i) — 隐私政策 — 🟢 App 内已解决；ASC 🟡

**现状**：Settings / Paywall 已提供 `LegalLinks` 隐私政策与条款。ASC 元数据中的 Privacy Policy URL 仍需人工确认。

---

### 1.2b Guideline 5.1.1(i) — 历史说明（归档）

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

### 1.3 Guideline 2.1 — 应用完成度 / 内购无法验证 — 🟡 ASC/沙盒待核验

代码侧：共享 Scheme + StoreKit 配置、空商品 Retry、购买/Restore Alert 已落地。仍需 ASC 确认商品已创建并可沙盒购买。

### 1.4 Guideline 2.3.1 / 3.1.1 — 元数据与付费内容误导 — 🟢 代码侧已解决

PRO 门控、Ad-Free 移除、分析/Face ID/备份文案已与实现对齐。ASC 截图与描述仍需人工避免夸大。

---

### 2.1 Guideline 5.1.1 — 权限字符串与用途 — 🟢 已解决

| Key | 现状 | 风险 | 方案 |
| :--- | :--- | :--- | :--- |
| `NSFaceIDUsageDescription` | 有，用途合理 | 低 | 保持 |
| `NSPhotoLibraryUsageDescription` | 有 | 低 | PhotosPicker 场景下可保留 |
| `NSCameraUsageDescription` | ✅ 已删除（无相机入口） | — | PhotosPicker 足够 |

### 2.2 App 图标与上传资产 — 🟢 已解决

源资产为 **1024×1024 PNG**（`AppIcon.appiconset/AppIcon.png`）。提交前仍建议 Release Archive / Organizer Validate。

### 2.3 Privacy Manifest（`PrivacyInfo.xcprivacy`）— 🟢 已解决

已添加 `BillsManager/App/PrivacyInfo.xcprivacy`（无追踪；UserDefaults / File Timestamp 合理用途）。提交前建议 Archive → Validate 再看 Privacy Report。

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

### 3.3 本地化与审核地区 — 🟢 代码侧已解决

- en / zh-Hans 词条已大幅补齐；系统分类展示层本地化
- ASC 主语言与截图语言仍需人工与商店元数据一致

### 3.4 角标与通知 — 🟢 已解决

- Onboarding / 保存账单请求权限；角标按逾期数更新；逾期立即补发已落地

### 3.5 示例数据 — 🟢 已解决

- 可选加载示例账单；`isSample` 可清除；Seed defaults 对象复用已修复

### 3.6 周期与金额边界 — 🟢 已解决

- 金额入口校验、锚定日防漂移、一期一付与撤销支付已落地

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
- [x] 删除未使用的 **NSCameraUsageDescription**（或实现相机）
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
| 本次状态同步 | 2026-08-06：对齐 APP_ISSUES；代码侧高风险项大多关闭；剩余 ASC/沙盒/Archive/CI |
| 政策更新 | Apple 指南可能变更，提交前请再读最新 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) |

---

*本文件基于全量源码/配置通读、Debug Simulator 构建与 Apple 公开指南复核，不构成法律意见，也未替代 Release Archive、Organizer Validate、真机通知、StoreKit 沙盒与 ASC 元数据人工核对。文中概率为经验性风险表达，不是 Apple 官方统计。*
