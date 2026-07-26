# Bills Manager - 技术架构与设计文档 (Architecture & Tech Spec)

---

## 1. 系统总体架构设计

Bills Manager 采用 **Modern SwiftUI + SwiftData + `@Observable`** 的分层解耦架构，遵循 Apple 官方推荐的声明式状态驱动设计原则：

```mermaid
graph TD
    subgraph UI_Layer["UI View Layer (SwiftUI)"]
        MainTab["MainTabView / iPadSidebarView"]
        DashView["DashboardView"]
        ListView["BillListView / BillDetailView"]
        CalView["BillCalendarView"]
        AnalyticsView["AnalyticsView (Swift Charts)"]
        Paywall["PaywallView"]
    end

    subgraph Logic_Layer["State & Manager Layer (@Observable)"]
        StoreMgr["StoreManager (StoreKit 2)"]
        NotifMgr["NotificationManager (UserNotifications)"]
        AuthMgr["BiometricAuthManager (LocalAuthentication)"]
        ExportMgr["ExportManager (CSV / JSON)"]
    end

    subgraph Data_Layer["Persistence Layer (SwiftData)"]
        ModelContainer["ModelContainer / ModelContext"]
        MBill["Bill (@Model)"]
        MCategory["Category (@Model)"]
        MAccount["Account (@Model)"]
        MPayment["PaymentRecord (@Model)"]
    end

    UI_Layer --> Logic_Layer
    UI_Layer --> Data_Layer
    Logic_Layer --> Data_Layer
    ModelContainer --> MBill
    ModelContainer --> MCategory
    ModelContainer --> MAccount
    ModelContainer --> MPayment
```

---

## 2. 数据模型实体关系图 (Entity-Relationship Diagram)

本地持久化基于 iOS 17 **SwiftData** 框架。各实体之间的关系定义如下：

```mermaid
erDiagram
    Category ||--o{ Bill : "classifies (nullify)"
    Account ||--o{ Bill : "funds (nullify)"
    Bill ||--o{ PaymentRecord : "has history (cascade delete)"

    Category {
        UUID id PK
        String name
        String iconName
        String hexColor
        Boolean isSystem
    }

    Account {
        UUID id PK
        String name
        String accountNumberLast4
        String iconName
        String hexColor
        Boolean isDefault
    }

    Bill {
        UUID id PK
        String name
        Double amount
        String currencyCode
        Date dueDate
        Boolean isPaid
        Boolean isAutoPay
        String frequencyRaw
        Date repeatEndDate
        Int reminderDaysBefore
        Date reminderTime
        String notes
        Data attachmentImageData
    }

    PaymentRecord {
        UUID id PK
        Date paidDate
        Double amountPaid
        String confirmationCode
        String notes
        Data receiptImageData
    }
```

### 2.1 删除规则 (Cascade Rules)
- **Bill $\rightarrow$ PaymentRecord**：`deleteRule: .cascade`（删除账单时，自动级联删除该账单关联的所有历史支付记录）。
- **Category $\rightarrow$ Bill** 与 **Account $\rightarrow$ Bill**：`deleteRule: .nullify`（删除某个分类或账户时，关联账单的对应指针置为空，不删除账单本身）。

---

## 3. 核心业务流程序列图 (Key Sequence Workflows)

### 3.1 周期账单支付与自动展期流程 (Bill Payment & Next Due Calculation)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant View as BillDetailView / BillRowView
    participant Model as Bill (@Model)
    participant History as PaymentRecord (@Model)
    participant Notif as NotificationManager

    User->>View: 点击 "Mark as Paid" 标记已付
    View->>Model: 调用 markAsPaid(paidAmount, code, receipt)
    Model->>History: 创建新的 PaymentRecord 实例并追加至 paymentHistory
    alt 一次性账单 (Frequency == .once)
        Model->>Model: 设置 isPaid = true
    else 循环账单 (Frequency != .once)
        Model->>Model: 计算 nextDueDate = frequency.nextDueDate(from: dueDate)
        alt 超过重复截止日期 (nextDueDate > repeatEndDate)
            Model->>Model: 设置 isPaid = true
        else 未超过截止日期
            Model->>Model: 更新 dueDate = nextDueDate, 设置 isPaid = false
        end
    end
    View->>Notif: 取消旧通知 (cancelNotification)
    alt 若未支付/已展期
        View->>Notif: 重新调度新到期日通知 (scheduleNotification)
    end
    View->>User: UI 动态刷新显示最新状态
```

### 3.2 StoreKit 2 内购与权限验证流程 (IAP Lifecycle)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant View as PaywallView
    participant Store as StoreManager (@Observable)
    participant SK as StoreKit 2 (App Store)

    User->>View: 打开内购页选定产品 (e.g. Lifetime PRO)
    View->>Store: 调用 purchase(product)
    Store->>SK: 发起 Product.purchase() 流程
    SK-->>User: 弹出 Apple ID 确认对话框
    User->>SK: 完成指纹/人脸/密码验证
    SK-->>Store: 返回 VerificationResult<Transaction>
    Store->>Store: 验证 Transaction 签名真实性 (checkVerified)
    alt 验证成功
        Store->>Store: 将 productID 添加至 purchasedProductIDs 集合
        Store->>SK: 调用 transaction.finish() 完成交易闭环
        Store-->>View: 返回 success = true，刷新 PRO 解锁状态
    else 验证失败/取消
        Store-->>View: 返回 false/错误提示
    end
```

---

## 4. Universal 响应式布局设计 (iPhone vs. iPad)

应用采用 **Size Class 驱动** 的 Universal 布局设计：

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

if horizontalSizeClass == .regular {
    // iPad 宽屏：使用 NavigationSplitView 侧边栏布局
    iPadSidebarView(selectedTab: $selectedTab)
} else {
    // iPhone 窄屏：使用标准 TabView 底部标签栏
    TabView { ... }
}
```

---

## 5. 项目模块目录对照表

| 模块目录 | 核心类/视图 | 职责说明 |
| :--- | :--- | :--- |
| `App/` | `BillsManagerApp.swift` | 应用入口、SwiftData 容器初始化与默认数据 Seed |
| `Models/` | `Bill.swift`, `Category.swift`, `Account.swift`, `PaymentRecord.swift` | SwiftData 数据实体定义及计算属性 |
| `Managers/` | `StoreManager.swift` | StoreKit 2 产品加载、购买、恢复与状态判定 |
| | `NotificationManager.swift` | `UNUserNotificationCenter` 本地推送引擎 |
| | `BiometricAuthManager.swift` | `LAContext` Face ID / Touch ID 生物识别认证 |
| | `ExportManager.swift` | CSV 格式拼装与 JSON 全量序列化 |
| `Views/Dashboard/` | `DashboardView.swift`, `MetricCardView.swift` | 财务概览卡片、逾期 Banner、即将到期列表 |
| `Views/Bills/` | `BillListView.swift`, `BillDetailView.swift`, `AddEditBillView.swift` | 账单列表搜索筛选、详情、划归已付表单 |
| `Views/Calendar/` | `BillCalendarView.swift`, `CalendarGridCell.swift` | 交互月度日历网格与指示点 |
| `Views/Analytics/` | `AnalyticsView.swift` | Swift Charts (`SectorMark`) 分类图表 |
| `Views/Settings/` | `SettingsView.swift`, `PaywallView.swift`, `PasscodeLockView.swift` | 设置页、内购 Paywall、安全解锁遮罩 |
