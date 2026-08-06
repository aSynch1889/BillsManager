# SwiftData 迁移说明（Bills Manager）

## 当前策略

应用使用 SwiftData 默认轻量迁移（lightweight migration）。模型以 UUID 主键为主，关键实体已声明 `@Attribute(.unique)`：

- `Bill.id`
- `Category.id`
- `Account.id`
- `PaymentRecord.id`

金额字段仍为 `Double`；入口表单通过 `CurrencyFormatter.parseAmount` 约束 `isFinite && > 0`。未来若改为 `Decimal`/整数分，需版本化 schema 与显式迁移计划。

## 变更流程建议

1. 在 `docs/APP_ISSUES_AND_SOLUTIONS.md` / 本文件记录 schema 变更意图
2. 优先做 additive / optional 字段变更，避免破坏性 rename
3. 真机干净安装与升级安装各验证一次
4. JSON 备份 v2 可作为跨版本数据桥（Settings → Restore）

## CloudKit / iCloud 同步（PRO，默认关闭）

- 容器：`iCloud.com.antigravity.billsmanager`
- 本地库 configuration：`LocalStore`（`cloudKitDatabase: .none`）
- 云库 configuration：`CloudStore`（`.private` CloudKit）
- 切换同步需**重启 App**；`ModelContainerFactory` 在启动时执行一次性 local↔cloud 数据拷贝
- **PRO 过期**时自动关闭 iCloud 同步并标记迁移回本地；需重启后生效。重新订阅 PRO 后可再次手动开启
- 系统分类/账户 seed 使用**固定 UUID**，避免多设备重复

## 版本锚点

- 备份格式：`ExportManager.currentBackupVersion = 2`
- App 营销版本：`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
