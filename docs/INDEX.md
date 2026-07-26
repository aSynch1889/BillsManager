# Bills Manager - 项目全景文档组合包 (Documentation Package)

欢迎阅读 **Bills Manager** 完整文档组合包！本组合包从**业务需求、技术架构、交互原型、设计规范与工程运行** 5 个维度为您提供全方位、深度的项目解构。

---

## 📚 文档组合包索引导航

```
docs/
├── INDEX.md                     # 📌 本文档 (组合包主索引)
├── PRD.md                       # 📄 1. 产品需求文档 (PRD、商业模式与功能矩阵)
├── ARCHITECTURE.md              # 🛠️ 2. 技术架构与设计文档 (Mermaid 架构图、ER 图与流程)
└── UI_UX_SPECIFICATION.md       # 🎨 3. UI/UX 原型与交互流程规范 (信息架构图与流程图)

根目录/
├── README.md                    # 🚀 4. 项目运行与工程部署指南
└── design_tokens.md             # 🎨 5. Design Tokens 色彩/字阶/间距设计规范
```

---

## 🔍 各文档核心内容速览

### 1. 📄 [产品需求文档 (PRD.md)](PRD.md)
> **解决：“要做什么、业务逻辑与商业变现”**
- **产品定位**：iOS 17.0+ 本地优先 (Local-First) 的账单追踪与到期防漏工具。
- **商业变现**：Freemium 模型，基于 StoreKit 2 的永久买断 ($19.99)、月订 ($1.99) 与年订 ($14.99) 功能矩阵对比。
- **功能矩阵**：账单全属性、9 种循环周期算法、状态流转引擎、生物识别锁、CSV/JSON 导出等。

---

### 2. 🛠️ [技术架构与设计文档 (ARCHITECTURE.md)](ARCHITECTURE.md)
> **解决：“底层怎么实现、模块如何交互”**
- **分层架构**：SwiftUI View Layer $\rightarrow$ `@Observable` Manager Layer $\rightarrow$ SwiftData Persistence Layer。
- **数据 ER 图**：`Bill`, `Category`, `Account`, `PaymentRecord` 实体关系与级联删除规则 (`deleteRule`)。
- **核心流程图**：包含账单划归已付与周期自动展期序列图、StoreKit 2 交易签名验证闭环序列图。
- **设备适配策略**：Size Class 驱动的 iPhone TabView 与 iPad `NavigationSplitView` 原生适配。

---

### 3. 🎨 [UI/UX 原型与交互流程规范 (UI_UX_SPECIFICATION.md)](UI_UX_SPECIFICATION.md)
> **解决：“界面长什么样、交互体验如何”**
- **信息架构图 (IA)**：应用 5 大核心 Tab 与二级模态页结构树。
- **用户旅程流程图**：新建账单流程、划归已付与周期展期流程。
- **界面解构 ASCII 原型**：仪表盘 2x2 卡片与红框预警解构、7x6 日历网格与动态圆点解构。
- **微交互**：划归已付弹簧动画、双向 Swipe Actions、后台高斯模糊隐私护盾。

---

### 4. 🚀 [项目运行与部署指南 (README.md)](../README.md)
> **解决：“如何把项目跑起来、怎么维护”**
- 环境要求：Xcode 15+/16+、iOS 17.0+ 部署目标。
- `xcodebuild` 命令行一键构建指令与编译产物说明。

---

### 5. 🎨 [Design Tokens 设计规范 (design_tokens.md)](../design_tokens.md)
> **解决：“设计系统的样式 Token 标准”**
- 色彩 Token（主色、状态语义色、预设 7 大分类 Hex Palette、动态暗黑模式背景色）。
- 字阶阶梯、间距尺寸（2pt ~ 48pt）、圆角与阴影 Token。
- SF Symbols 5 规范清单。
