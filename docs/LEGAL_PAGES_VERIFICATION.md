# 隐私政策与支持页验收（2026-08-23）

对 `LegalLinks` 中的 HTTPS 地址做了 HTTP 探测与正文关键词核对。**三页均返回 HTTP 200**，英文隐私政策覆盖上架所需要点。

| URL | HTTP | 结论 |
| :--- | :---: | :--- |
| https://asynch1889.github.io/BillsManager-legal/privacy/en.html | 200 | 含 iCloud、Face ID、photo、notification、StoreKit、child、contact、local |
| https://asynch1889.github.io/BillsManager-legal/privacy/zh.html | 200 | 含 iCloud、Face ID、通知；中文用词与英文页不完全逐字对应，页面可打开 |
| https://asynch1889.github.io/BillsManager-legal/support/ | 200 | Support FAQ + GitHub issue；链到中英隐私政策 |
| https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ | （Apple 标准 EULA） | Paywall / 商店描述已引用 |

## 仍建议

1. 用真机 Safari 再开一遍（GitHub Pages 在部分网络会慢）。  
2. App Store Connect 隐私问卷点 **Publish**（API 无法核验）。  
3. 中文隐私页建议补「照片/收据」「数据默认仅存本机」等与英文对等的小节（托管在 `BillsManager-legal` 仓库，不在本 App 仓）。  
4. Support 页补充：如何 Restore、如何在系统设置取消订阅、iCloud 开关需划掉 App。

本 App 仓无需改 `LegalLinks.swift`。
