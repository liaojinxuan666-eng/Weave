# Weave

> A self-contained local computing environment for iOS.

**Weave** 不是一个浏览器，也不是一个终端模拟器。它是一个把 iPhone / iPad 变成**独立计算环境**的运行时：一个浏览器、一个终端、一个本地 Linux 用户态，共享同一个文件系统、同一份环境变量、同一个网络栈。

网页里可以调用终端。终端里可以起 HTTP 服务给网页加载。网页和终端看到的是同一个目录树。

---

## 为什么

iOS 上做开发一直很别扭：

- App Store 禁止下载执行代码（指南 2.5.2），任何"运行时"都上不了架
- 现有终端 App 要么只能 SSH，要么只能跑内置命令
- 浏览器和终端是两个割裂的世界，没法共享文件

**Weave 走 sideload 路线**，绕开 2.5.2，用 SideStore + StikDebug 拿到 JIT 和自由安装，把完整能力还给用户。

---

## 能跑什么

Weave 是一个宿主，不是一个 App。以下是它的目标负载：

| 负载 | 类型 | 状态 |
|---|---|---|
| **DeepSeek Harness (dsh)** | Web (WKWebView) | 🎯 首要目标 |
| Claude Code | 终端 (Node.js) | 🎯 目标 |
| Codex | 终端 (Rust) | 🎯 目标 |
| `python3 -m http.server` | 终端 → 浏览器 | 🎯 目标 |
| busybox / git / vim / tmux | 终端 | 🚧 |
| 任意本地 HTML / JS | Web | 🚧 |
| Alpine Linux（QEMU TCG） | 全系统 | 💤 可选 |

**DSH 是一等公民**：它跑在 Web surface 里，通过 Bridge 直接调用本地终端、文件系统和网络，不需要任何远端服务器。

---

## 特性

### 已完成
- [ ] WKWebView 容器，`weave://` scheme 加载本地资源
- [ ] SwiftTerm 终端，`posix_spawn` + socketpair 模拟 PTY
- [ ] JS ⇄ Native 双向 Bridge
- [ ] 共享文件系统（`~/Documents` 挂载为 `/`）

### 进行中
- [ ] 原生 ARM64 用户态工具链（busybox / git / python3）
- [ ] 本地 HTTP 服务器，浏览器加载 `localhost`
- [ ] `weave://exec?cmd=...` 直接执行命令

### 计划中
- [ ] Node.js 交叉编译到 iOS ARM64
- [ ] DSH / Claude Code / Codex 本地运行
- [ ] QEMU TCG（可选，用于真 Linux 内核）
- [ ] 多会话标签页
- [ ] 文件浏览器

---

## 架构
 
┌──────────────────────────────────────────────┐
│  Host (SwiftUI App)                          │
│  · Session 注册表 + 路由                      │
│  · 唯一时钟 (CADisplayLink)                   │
│  · Capability Broker                         │
├──────────────────────────────────────────────┤
│  Surfaces                                    │
│  ├─ WebSurface  : WKWebView + weave:// + bridge│
│  └─ TermSurface : SwiftTerm + transport      │
├──────────────────────────────────────────────┤
│  Transport                                   │
│  ├─ LocalPTY   : posix_spawn 原生二进制       │
│  └─ SSHSession : (计划) Citadel 远端 PTY      │
├──────────────────────────────────────────────┤
│  Shared Runtime                              │
│  · 文件系统: ~/Documents 挂载为 /              │
│  · 环境变量: 共享                              │
│  · 网络: loopback 本地服务器                   │
└──────────────────────────────────────────────┘

核心原语是 **Session**：Web 和 Term 都是 Session，共享 `cwd` / `env` / `caps`。JS 通过 Bridge 请求能力，Host 决定路由到哪个 transport。

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

---

## 快速开始

### 环境要求

- macOS 14+ / Xcode 15.4+
- iOS 18.0+ 设备
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 本地构建

```bash
git clone https://github.com/liaojinxuan666-eng/Weave.git
cd Weave
brew install xcodegen
xcodegen generate
open Weave.xcodeproj
 
未签名的 .app 可以直接从 Xcode 跑到设备上（Signing & Capabilities 里选自己的免费 Apple ID）。
 
CI 构建
 
推送到 main 或打 tag，GitHub Actions 自动构建未签名 IPA。
Actions → Build IPA → weave-unsigned-ipa
 
 
安装（iOS 18，无需付费开发者账户）
 
推荐栈：SideStore + StikDebug + LiveContainer
组件 作用
SideStore 设备端签名刷新，免电脑（首次除外）
StikDebug 启用 JIT，支持 iOS 17.4 – 18.x
LiveContainer 突破 3 App 签名限制

 
步骤：
1. 电脑上用 jitterbugpair 导出配对文件（.mobiledevicepairing），传到手机
2. 手机安装 SideStore，用免费 Apple ID 签名
3. SideStore 内安装 StikDebug 和 LiveContainer
4. 从 CI 下载 weave-unsigned.ipa
5. 用 SideStore 签名安装，或在 LiveContainer 内运行
6. 重启设备后打开 StikDebug → 选 Weave → Enable JIT 
注意：TrollStore 不支持 iOS 18。BreakFree 类企业证书方案不稳定，不推荐。 
 
Bridge API
 
网页通过 weave:// 里的 JS 调用原生能力：
// 终端
const id = await weave.term.spawn('claude', { args: ['--print'], cwd: '/project' })
weave.term.onOutput(id, data => console.log(data))
weave.term.write(id, 'hello\n')

// 文件系统
await weave.fs.write('/project/main.js', source)
const files = await weave.fs.list('/project')

// 本地服务器
const port = await weave.net.serve('/project', 8080)
// → http://localhost:8080

// 执行命令（一次性）
const out = await weave.exec('git status', { cwd: '/project' })
 
原生 → JS：
weave.on('fileChanged', ({ path }) => { ... })
weave.on('termOutput', ({ id, data }) => { ... })
 
Capability 白名单见 docs/CAPABILITIES.md。 
 
项目结构
Weave/
├── .github/workflows/build.yml    CI
├── docs/
│   ├── ARCHITECTURE.md
│   └── CAPABILITIES.md
├── Weave/
│   ├── App/                       SwiftUI 入口
│   ├── Host/                      Session 管理、路由
│   ├── Surfaces/
│   │   ├── Web/                   WKWebView + scheme + bridge
│   │   └── Term/                  SwiftTerm + transport
│   ├── Transport/
│   │   ├── LocalPTY.swift
│   │   └── SSHSession.swift       (计划)
│   ├── Shared/
│   │   ├── Filesystem.swift
│   │   └── Capability.swift
│   └── Resources/
│       ├── web/                   weave:// 根目录（DSH 放这）
│       └── bridge.js              JS 注入脚本
├── project.yml                    XcodeGen 配置
├── .gitignore
└── LICENSE
 
 
路线图
里程碑 内容 状态
M1 终端跑通（busybox sh） 🚧
M2 浏览器跑通（weave:// 加载 HTML） 🚧
M3 互通（fs / terminal / net bridge） ⏳
M4 Node.js ARM64 交叉编译 ⏳
M5 DSH 本地运行 ⏳
M6 Claude Code / Codex ⏳
M7 QEMU TCG（可选） 💤

 
 
合规说明
 
本项目不走 App Store。目标部署方式是 sideload（SideStore / AltStore / LiveContainer），因此：
• 不受 App Store 指南 2.5.2 约束
• 可以使用 JIT（通过 StikDebug）
• 可以加载任意本地二进制
• 可以在运行时读写文件系统 
如果你是 App Store 发布者，本项目的大部分能力都不可用。 
 
贡献
 
欢迎 issue 和 PR。请先读 docs/ARCHITECTURE.md 了解设计约束。
 
提 PR 前请确保：
• xcodegen generate && xcodebuild build 通过
• 不引入付费依赖
• 不破坏 weave:// scheme 的向后兼容 
 
许可证
 
MIT 
 
致谢
• SwiftTerm — 终端模拟
• SideStore — 设备端签名
• StikDebug — JIT 启用
• LiveContainer — 多 App 容器
• UTM SE — QEMU 参考实现‌

---

## 仓库描述（About 字段）
 
A self-contained local computing environment for iOS. Browser, terminal, and Linux userspace — one filesystem, one process tree, one network stack.

---

## project.yml（scheme 改为 weave://）

```yaml
name: Weave

options:
  bundleIdPrefix: com.liaojinxuan
  deploymentTarget:
    iOS: "18.0"
  createIntermediateGroups: true

packages:
  SwiftTerm:
    url: https://github.com/migueldeicaza/SwiftTerm
    from: 1.2.0

targets:
  Weave:
    type: application
    platform: iOS
    sources:
      - path: Weave
    resources:
      - path: Weave/Resources
    dependencies:
      - package: SwiftTerm
    info:
      path: Weave/Info.plist
      properties:
        CFBundleDisplayName: Weave
        CFBundleURLTypes:
          - CFBundleURLName: com.liaojinxuan.weave
            CFBundleURLSchemes: [weave]
        UILaunchScreen: {}
        UIRequiredDeviceCapabilities: [arm64]
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.liaojinxuan.weave
        SWIFT_VERSION: 5.10
        TARGETED_DEVICE_FAMILY: "1,2"
        CODE_SIGN_STYLE: Automatic
        ENABLE_BITCODE: NO