# KKXX

KKXX 是个人效率工具 App（iOS 16+，SwiftUI），包含笔记、待办、记账、习惯打卡、小工具、数据总览六大模块。

- 离线优先：本地 JSON 持久化，全部功能离线可用
- 云端同步：与 PHP 后台（app.puaaa.cn）双向同步，冲突按时间戳新者胜（LWW）
- 待同步队列：离线操作写入本地队列，联网批量上传
- 全部界面图标使用 SF Symbols 系统矢量图标（iOS 平台等效于内联 SVG，自动适配深浅色）
- 支持深浅色模式、指纹/面容解锁、本地数据导出

## 仓库结构

```
KKXX/
├─ project.yml                  # XcodeGen 工程配置
├─ KKXX/
│  ├─ KKXXApp.swift             # 入口
│  ├─ Models.swift              # 数据模型（带时间戳/软删除）
│  ├─ AppSettings.swift         # 全局设置
│  ├─ LocalStore.swift          # 离线存储 + 待同步队列 + 同步引擎
│  ├─ SyncService.swift         # API 客户端 + 网络监听
│  ├─ Assets.xcassets/          # App 图标（构建时从 CDN 还原）
│  └─ Views/                    # 全部界面
└─ .github/workflows/build-ipa.yml   # GitHub Actions 打包未签名 IPA
```

## 打包

推送到 `main` 分支自动触发 GitHub Actions（macOS 云端编译），输出未签名 IPA 到 Release。
