# Bills Manager - Design Tokens & System Specification

本文档定义了 **Bills Manager** 原生 iOS 应用（SwiftUI）的设计 Token 规范，包括色彩系统、字阶体系、间距圆角、组件尺寸、状态标致及 SF Symbols 图标规范。

---

## 🎨 1. Color Tokens (色彩 Token)

### 1.1 Brand & Accent Colors (品牌主色)
| Token 名称 | 变量 / 颜色值 | 十六进制 | 适用场景 |
| :--- | :--- | :--- | :--- |
| `color.brand.primary` | `Color.blue` | `#3B82F6` | 全局主按键、导航高亮、选定状态 |
| `color.brand.accent` | `AccentColor` | `#3C82F6` | 系统标准 Accent 颜色目录 |
| `color.brand.pro.gradient.start` | `Color.orange` | `#F59E0B` | PRO 专业版升级徽章渐变起点 |
| `color.brand.pro.gradient.end` | `Color.yellow` / `Color.amber` | `#F7D070` | PRO 专业版升级徽章渐变终点 |

### 1.2 Status & Semantic Colors (语义状态色)
| Token 名称 | 颜色 | 十六进制 | 语义说明 |
| :--- | :--- | :--- | :--- |
| `color.status.overdue` | `Color.red` | `#EF4444` | 账单逾期 (Overdue) |
| `color.status.dueToday` | `Color.orange` | `#F59E0B` | 今日到期 (Due Today) |
| `color.status.dueSoon` | `Color.yellow` | `#FBBF24` | 3天内即将来临 (Due Soon) |
| `color.status.paid` | `Color.green` | `#10B981` | 已完成支付 (Paid) |
| `color.status.upcoming` | `Color.blue` | `#3B82F6` | 正常未到期 (Upcoming) |

### 1.3 Surface & Background Colors (暗黑模式适配背景)
| Token 名称 | SwiftUI 变量 | 适用场景 |
| :--- | :--- | :--- |
| `color.bg.primary` | `Color(.systemGroupedBackground)` | 页面大背景，随浅色/深色模式动态切换 |
| `color.bg.secondary` | `Color(.secondarySystemGroupedBackground)` | 卡片、列表项、表单块背景 |
| `color.text.primary` | `Color.primary` | 一级标题与主要文本 |
| `color.text.secondary` | `Color.secondary` | 二级文本、图标辅助说明 |
| `color.text.tertiary` | `Color.tertiary` | 弱化法律条款与底部备注 |

### 1.4 Preset Category Hex Palette (预设账单分类调色板)
| 分类 | 默认图标 | 预设 Hex 颜色 | 视觉表达 |
| :--- | :--- | :--- | :--- |
| **Utilities (公共事业)** | `bolt.fill` | `#F59E0B` | 琥珀黄 (Electricity / Water / Gas) |
| **Housing (房屋居住)** | `house.fill` | `#3B82F6` | 宝石蓝 (Rent / Mortgage) |
| **Subscriptions (订阅服务)** | `play.tv.fill` | `#8B5CF6` | 紫罗兰 (Streaming / Cloud) |
| **Credit Card (信用卡)** | `creditcard.fill` | `#EF4444` | 珊瑚红 (Credit / Loan) |
| **Insurance (保险保障)** | `shield.fill` | `#10B981` | 翡翠绿 (Health / Car Insurance) |
| **Loans (贷款借贷)** | `banknote.fill` | `#6B7280` | 中性灰 (Personal Loans) |
| **Personal (个人消费)** | `person.fill` | `#EC4899` | 玫瑰粉 (Personal & Leisure) |

---

## 🔤 2. Typography Tokens (字体阶梯)

| Token 名称 | SwiftUI 字体定义 | 字号 / 字重 / 设计 | 适用场景 |
| :--- | :--- | :--- | :--- |
| `font.hero.amount` | `.system(size: 36, weight: .bold, design: .rounded)` | 36pt / Bold / Rounded | 账单详情大额数字 |
| `font.title.pro` | `.system(size: 28, weight: .bold, design: .rounded)` | 28pt / Bold / Rounded | 内购 Paywall 标题 |
| `font.title2.rounded` | `.system(.title2, design: .rounded, weight: .bold)` | Title2 / Bold / Rounded | 仪表盘 MetricCard 金额 |
| `font.title3.bold` | `.font(.title3.bold())` | Title3 / Bold | 分组标题与板块大标题 |
| `font.headline` | `.font(.headline)` | Headline / Semibold | 账单行标题、按键文字 |
| `font.body.medium` | `.font(.body.weight(.medium))` | Body / Medium | 属性名、清单正文 |
| `font.callout.bold` | `.system(.callout, design: .rounded, weight: .bold)` | Callout / Bold / Rounded | 列表行右侧账单金额 |
| `font.subheadline` | `.font(.subheadline)` | Subheadline / Regular | 辅助描述说明 |
| `font.caption.bold` | `.font(.caption.bold())` | Caption / Bold | 状态 Tag 标签、筛选 Badge |
| `font.caption2` | `.font(.caption2)` | Caption2 / Regular | 底部补充微型文字 |

---

## 📐 3. Layout & Spacing Tokens (间距与尺寸 Token)

### 3.1 Spacing Ladder (间距阶梯)
| Token 名称 | 尺寸 (pt) | 适用场景 |
| :--- | :--- | :--- |
| `spacing.xxs` | `2pt` / `4pt` | 文本标签内微间距 |
| `spacing.xs` | `6pt` / `8pt` | 列表项内部上下间距、分类 Badge 内边距 |
| `spacing.sm` | `12pt` | 列表行之间间距、图标与文字水平均分间距 |
| `spacing.md` | `16pt` | 卡片内边距 (Padding)、网格间距 (Grid Gap) |
| `spacing.lg` | `20pt` / `24pt` | 板块外边距、Paywall 内部大间距 |
| `spacing.xl` | `32pt` / `48pt` | 缺省页 (Empty View) 上下留白 |

### 3.2 Component Sizes (组件规格尺寸)
| Component | 规格尺寸 (pt) | 说明 |
| :--- | :--- | :--- |
| `size.icon.hero` | `80pt x 80pt` | Paywall 皇冠大图标容器 |
| `size.icon.detail` | `64pt x 64pt` | 账单详情顶部分类大图标 |
| `size.icon.picker` | `54pt x 54pt` | 图标选择器触控响应区域 |
| `size.icon.badge` | `44pt x 44pt` | 账单列表行左侧分类圆形图标 |
| `size.icon.manager` | `36pt x 36pt` | 分类/账户管理列表圆圈 |
| `size.dot.calendar` | `5pt x 5pt` | 日历单元格状态小圆点 |

---

## 🔷 4. Corner Radius & Elevation Tokens (圆角与阴影)

### 4.1 Corner Radii (圆角 Token)
| Token 名称 | 圆角半径 (pt) | 样式 | 适用场景 |
| :--- | :--- | :--- | :--- |
| `radius.card.hero` | `20pt` | Continuous | 账单详情卡片、Paywall 功能列表卡片 |
| `radius.card.standard`| `16pt` | Continuous | 仪表盘 MetricCard、图表卡片 |
| `radius.card.row` | `14pt` | Continuous | 账单列表行 (BillRowView)、通用按键 |
| `radius.pill` | `Capsule()` | Capsule | 状态标签 (Status Tag)、筛选 Pill |
| `radius.circle` | `Circle()` | Circle | 分类图标背景 |

### 4.2 Elevation / Shadows (阴影 Token)
| Token 名称 | 透明度 | 半径 (Radius) | 偏移 (Offset) | 适用场景 |
| :--- | :--- | :--- | :--- | :--- |
| `shadow.card.light` | `Color.black.opacity(0.04)` | `8pt` | `x: 0, y: 2` | 仪表盘 MetricCard 轻微浮起效果 |

---

## 🎭 5. Iconography Tokens (SF Symbols 5 图标规范)

| 分类 | SF Symbol 名称 | 适用场景 |
| :--- | :--- | :--- |
| **导航 Tab** | `square.grid.2x2.fill`, `doc.text.fill`, `calendar`, `chart.pie.fill`, `gearshape.fill` | 底部 5 大主 Tab |
| **状态标识** | `exclamationmark.triangle.fill`, `exclamationmark.circle.fill`, `checkmark.circle.fill`, `circle` | 逾期警告、完成勾选 |
| **周期/自动扣款** | `arrow.triangle.2.circlepath`, `repeat` | 循环账单、Auto-Pay |
| **操作/控制** | `plus.circle.fill`, `pencil`, `trash`, `magnifyingglass`, `xmark.circle.fill` | 新建、编辑、删除、搜索 |
| **高级功能/安全** | `crown.fill`, `lock.shield.fill`, `faceid`, `touchid`, `arrow.down.doc.fill` | Pro 升级、Face ID 锁、CSV 导出 |
