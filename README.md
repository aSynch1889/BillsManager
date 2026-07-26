# Bills Manager (账单管理应用)

一个使用 **Swift** 与 **SwiftUI** 开发的 iOS 原生财务账单管理应用，专为 **iOS 17.0+** 设计，全面支持 **iPhone** 与 **iPad** (Universal App)。本项目完整复刻了 Bills Manager / Bills Monitor 的核心功能，并包含了 StoreKit 2 高级内购功能，具备提交至 App Store Connect (ASC) 的质量标准。

---

## 🔥 核心功能亮点

### 1. 📅 账单管理与周期重导
- **全面属性记录**：支持账单名称、金额、到期日、分类、支付账户、周期（一次性、每天、每周、每两周、每月、每双月、每季度、半年、每年）、自定义重复截止日期、自动扣款 (Auto-Pay) 标识、备注以及小票/发票凭证图片。
- **状态自动更新**：包含已逾期 (Overdue)、今日到期 (Due Today)、即将来临 (Due Soon)、未到期 (Upcoming)、已支付 (Paid) 五种状态。
- **历史支付日志**：记录历次支付的时间、金额、交易流水号/参考码及小票凭证图片。

### 2. 📱 iPhone & iPad 适配
- **iPhone**：优雅的 5 标签栏 Navigation 结构（仪表盘、账单列表、日历、数据分析、设置）。
- **iPad**：原生 `NavigationSplitView` 侧边栏多列导航。

### 3. 📊 交互日历与 Swift Charts 图表分析
- **月度日历**：7x5 / 7x6 交互日历网格，带状态颜色指示点，点击任意日期即时显示当日应付账单。
- **Swift Charts 费用图表**：使用 iOS 17 `SectorMark` 环形图展现分类支出比例，提供按分类的统计与百分比计算。

### 4. 🔒 隐私安全与本地提醒
- **生物识别安全锁**：集成 `LocalAuthentication` 框架，支持 Face ID / Touch ID / 密码锁，应用退至后台时自动开启高斯模糊遮罩。
- **本地到期提醒**：基于 `UNUserNotificationCenter`，支持在到期前 0/1/2/3/7 天及指定时刻发送推送通知，并自动更新 App 图标角标 (Badge)。

### 5. 💎 StoreKit 2 内购高级版 (PRO)
- 采用 iOS 17 `@Observable StoreManager` 与 StoreKit 2 接口。
- 支持买断版（Lifetime PRO）、月度订阅与年度订阅。
- 项目内置 `StoreKit.storekit` 配置文件，支持在 Xcode 模拟器与预览中直接测试内购流程。

### 6. 🌐 默认多语言支持 (Localization)
- 采用 iOS 17 现代字符串目录 (`Localizable.xcstrings`)，默认内置**简体中文 (`zh-Hans`)** 与 **英文 (`en`)**。

### 7. 📤 数据导出与 JSON 备份
- **CSV 表格导出**：一键生成标准 CSV 格式账单报表并通过系统分享面板导出。
- **JSON 完整备份**：支持全量数据库 JSON 格式导出与恢复。

---

## 📁 目录结构

```
BillsManager/
├── BillsManager.xcodeproj/     # Xcode 工程文件
└── BillsManager/
    ├── App/                    # 应用入口与 Info.plist 权限配置
    ├── Models/                 # SwiftData 数据模型 (Bill, Category, Account, PaymentRecord)
    ├── Managers/               # 业务逻辑管理器 (StoreManager, NotificationManager, BiometricAuthManager, ExportManager)
    ├── Views/
    │   ├── Main/               # 主界面与 iPad 侧边栏导航
    │   ├── Dashboard/          # 首页仪表盘与数据卡片
    │   ├── Bills/              # 账单列表、详情、新建与编辑视图
    │   ├── Calendar/           # 交互月度日历视图
    │   ├── Analytics/          # Swift Charts 支出分析图表
    │   ├── CategoriesAccounts/ # 分类与账户管理视图
    │   └── Settings/           # 设置、生物识别锁与 StoreKit 2 内购页
    └── Resources/              # Assets.xcassets、Localizable.xcstrings 与 StoreKit.storekit
```

---

## ⚙️ 开发与运行环境

- **Xcode Version**: Xcode 15.0+ / Xcode 16.0+
- **Swift Version**: Swift 5.9+ / Swift 6
- **Deployment Target**: iOS 17.0+
- **Supported Devices**: iPhone & iPad (Universal)

### 构建命令 (xcodebuild)

```bash
xcodebuild -project BillsManager.xcodeproj \
           -scheme BillsManager \
           -destination 'generic/platform=iOS Simulator' \
           build
```

---

## 📝 许可证

本项目采用 MIT 许可证。
