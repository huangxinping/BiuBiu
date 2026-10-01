# BiuBiu 设计文档

- 日期：2026-10-01
- 状态：待审阅

## 1. 目标与背景

BiuBiu 是一款常驻 macOS 菜单栏的近期文件快速访问工具。按下快捷键（或点击菜单栏图标）后弹出一个简洁面板，按时间倒序列出最近打开、保存、下载的文件与文件夹，以及最近安装的应用和新连接的外置磁盘。

要解决的问题：文件刚保存或刚下载后就找不到了。Finder 的"最近使用"不够聚焦，BiuBiu 专门为"立刻回到刚才在处理的内容"而设计。

目标用户：作家、设计师、开发者、学生、办公室工作者等普通 Mac 用户。

### 成功标准

- 按下快捷键后 1 秒内看到面板，刚才处理的文件位于列表前几条。
- 单击即可打开；也可以在 Finder 中显示、拖到其他 app、快速预览。
- 在全屏应用中同样可以唤出。
- 刚安装时无需任何配置，就能看到过去 7 天的历史（来自 Spotlight 索引）。

### 非目标（第一版不做）

- 移到废纸篓、重命名等修改文件的操作（app 对文件只读，唯一例外是推出磁盘）
- 云同步、标签、归档流程
- 自动更新（只提供跳转到 GitHub Releases 的链接）
- 自己监听文件系统（FSEvents）和自建数据库（数据源已抽象成接口，以后可以加）
- 收费、内购

## 2. 关键决策

| 决策 | 结论 | 理由 |
|---|---|---|
| 分发方式 | 在 GitHub 开源，通过 GitHub Releases 发布 `.app`；不上架 App Store | 不开沙盒，Spotlight 能直接查询整个主目录 |
| 签名 | 暂时没有 Apple 开发者账号；用一张**固定的自签名证书**签名 | ad-hoc 签名每次构建都会变，用户升级后会丢失已授予的隐私权限；固定证书能让系统认出是同一个 app |
| 数据来源 | 第一版只用 Spotlight 实时查询（`NSMetadataQuery`） | 系统已建好索引，速度快、免维护，安装后立刻有历史 |
| 面板布局 | 统一时间线 + 顶部分类切换 | 最贴合"我刚才动过什么"的回忆方式 |
| 对文件的操作 | 只读：打开、在 Finder 中显示、拖出、快速预览、复制路径、打开方式、置顶 | 权限最小，误操作风险最低 |
| 技术栈 | Swift 6、SwiftUI + AppKit，用 SwiftPM 构建 | 本机只有 Command Line Tools，没有 Xcode |
| 系统要求 | macOS 14 及以上 | 可以使用 Observation 等较新的 SwiftUI 能力 |
| 界面语言 | 简体中文和英文 | 开源项目，面向更多用户 |
| 第三方依赖 | 只用 [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)（MIT 协议） | 提供全局快捷键和设置页的"录制快捷键"控件 |
| 开源协议 | MIT | — |

## 3. 架构

```
┌──────────── App 外壳（BiuBiu）────────────┐
│ StatusItemController  HotKey  PanelController │
│ SettingsWindow  WelcomeWindow                │
└───────────────────┬──────────────────────────┘
                    │ 读取状态 / 执行操作
┌───────────────────▼──────────────────────────┐
│ ActivityStore（合并、去重、过滤、排序、分组）      │
└──┬──────────┬──────────┬──────────┬─────────┘
   │          │          │          │
SpotlightFileSource  AppInstallSource  VolumeSource  PinStore
   │          │          │
   └──── ActivitySource 协议 ────┘
                    │
        IgnoreRules / AppSettings
```

代码拆成两个 SwiftPM target：

- **`BiuBiuCore`**（库）：数据模型、`ActivitySource` 协议及三个实现、`ActivityStore`、`IgnoreRules`、`PinStore`、`AppSettings`、活动类型判定、时间分组。不依赖 SwiftUI 视图层，可以单独测试。
- **`BiuBiu`**（可执行程序）：菜单栏图标、快捷键、浮动面板、SwiftUI 视图、设置窗口、欢迎窗口。

### 3.1 数据模型

```swift
enum ActivityKind { case file, folder, application, volume }
enum ActivityEvent { case opened, saved, added, downloaded, installed, mounted }

struct ActivityItem: Identifiable, Hashable {
    let id: URL              // 以文件路径作为唯一标识
    let url: URL
    let kind: ActivityKind
    let event: ActivityEvent
    let date: Date?          // 启动前已挂载的磁盘为 nil
    let displayName: String
    let parentName: String?  // 所在文件夹的名字
    let sourceHost: String?  // 下载来源的域名
}
```

### 3.2 ActivitySource 协议

```swift
protocol ActivitySource: Sendable {
    /// 持续推送这个数据源当前的完整结果集
    func items() -> AsyncStream<[ActivityItem]>
}
```

`ActivityStore` 订阅所有数据源；任一数据源推送新结果，就重新计算一次合并后的列表。

### 3.3 模块职责

- **SpotlightFileSource**：在主目录范围内持续查询（`NSMetadataQueryUserHomeScope`）。查询条件见 4.2。把 Spotlight 返回的结果转换成 `ActivityItem`。
- **AppInstallSource**：在 `/Applications` 和 `~/Applications` 中查询内容类型为 `com.apple.application-bundle`，并且"加入文件夹"时间（`kMDItemDateAdded`）落在时间范围内的项目。
- **VolumeSource**：启动时读取当前已挂载的卷，之后监听系统的挂载和推出通知。只保留可移除、可推出或网络类型的卷。挂载时间只在运行期间收到通知时记录；启动前已经接上的卷，`date` 为 nil。负责执行推出操作。
- **ActivityStore**（`@MainActor @Observable`）：合并各数据源结果；同一 URL 只保留 `date` 最新的一条；套用 `IgnoreRules`；按日期倒序排列，最多保留 500 条；根据搜索词和当前分类筛选；按时间分组。时钟可注入。
- **IgnoreRules**：规则分三种：路径前缀、路径中包含的片段、扩展名。另有一个"忽略隐藏文件"开关。提供默认规则（见 4.3）和"恢复默认"。保存在 `UserDefaults` 中。
- **PinStore**：保存置顶项目的有序列表，每项记录普通书签数据（bookmark，文件移动或改名后仍能找到）和置顶时间。存在 `~/Library/Application Support/BiuBiu/pins.json`。
- **AppSettings**：时间范围、各分类是否显示、上次选中的分类、是否开机启动（通过 `SMAppService.mainApp`）、是否已看过欢迎页。快捷键由 KeyboardShortcuts 自己保存。
- **PanelController**：管理一个 `NSPanel`，样式为 `.nonactivatingPanel`，窗口层级为浮动窗口，集合行为设为 `.canJoinAllSpaces` + `.fullScreenAuxiliary`，内容用 `NSHostingView` 承载 SwiftUI。负责计算面板位置、显示和隐藏，以及点击面板外部时自动关闭。
- **StatusItemController**：管理菜单栏图标。左键点击切换面板显示；右键弹出菜单（设置、退出）。

## 4. 数据规则

### 4.1 时间范围

默认 7 天，可选 1、3、7、14、30 天。

### 4.2 文件与文件夹的判定

Spotlight 查询条件（以文件为例；文件夹另有规则，见下文）：

```
kMDItemLastUsedDate >= since
  OR kMDItemContentModificationDate >= since
  OR kMDItemDateAdded >= since
```

每个结果的活动类型和时间按以下规则判定：

1. 取 最近打开时间（LastUsed）、内容修改时间（ContentModification）、加入文件夹时间（DateAdded）三者中最新的一个作为 `date`。
2. 最新的是 LastUsed，判为 `opened`；是 ContentModification，判为 `saved`；是 DateAdded，判为 `added`。
3. 如果判为 `added`，并且文件带有下载来源记录（`kMDItemWhereFroms` 非空）或位于 `~/Downloads` 下，则改判为 `downloaded`。`sourceHost` 取下载来源记录中第一个网址的域名。
4. **文件夹**（内容类型为 `public.folder`）只看 LastUsed 和 DateAdded，忽略内容修改时间，对应 `opened` 或 `added`；两者都不在时间范围内的文件夹直接丢弃。原因是文件夹里任何文件变动都会刷新它的修改时间，会导致刷屏。

界面上的标签文字：`opened` 显示"打开"、`saved` 显示"保存"、`added` 显示"新增"、`downloaded` 显示"下载"、`installed` 显示"安装/更新"（系统无法可靠区分安装和更新）、`mounted` 显示"已连接"。

### 4.3 默认忽略规则

- 隐藏文件和文件夹（路径中任何一段以 `.` 开头）
- 路径前缀：`~/Library/`、`~/.Trash/`
- 路径中包含：`.app/`（程序包内部）、`/node_modules/`、`/.git/`、`/DerivedData/`、`/__pycache__/`
- 扩展名：`tmp`、`part`、`crdownload`、`download`、`swp`

在面板中右键某个条目，可以选择：忽略此文件（路径前缀规则）、忽略此文件夹下所有项目（以父文件夹为路径前缀）、忽略所有同扩展名的文件（扩展名规则）。

### 4.4 时间分组

分组规则（基于注入的"当前时间"和本地日历计算）：

- **刚刚**：1 小时内
- **今天**：今天、但早于 1 小时前
- **昨天**
- **本周**：最近 7 天内、早于昨天
- **更早**

`date` 为 nil 的磁盘不进入时间线，只出现在"磁盘"分类中。

## 5. 界面与交互

### 5.1 唤出与关闭

- 唤出方式：点击菜单栏图标，或按全局快捷键（默认 `⌥⌘R`，可在设置中修改）。再按一次关闭。
- 按 `Esc`：搜索框有内容时先清空搜索，再按一次关闭面板。
- 点击面板外部时自动关闭。
- 面板位置：菜单栏可见时出现在图标下方；在全屏应用中菜单栏隐藏，此时出现在鼠标所在屏幕的顶部中央。
- 面板尺寸约 360×520，内容区可滚动。

### 5.2 面板结构（从上到下）

1. **搜索框**：打开面板时自动获得焦点；按文件名筛选，不区分大小写。
2. **分类切换**：全部 / 文件 / 文件夹 / 下载 / 应用 / 磁盘，`⌘1` 到 `⌘6` 切换；下次打开时记住上次的选择。设置中关闭的分类不显示。
3. **置顶区**：只在"全部"视图中显示，可折叠，按置顶时间排序。已找不到的置顶项变灰，标注"找不到"，可一键移除。置顶项如果同时在时间范围内，时间线中照常显示。
4. **时间线**：按 4.4 分组显示。每行包括：系统文件图标、文件名、所在文件夹名、"类型标签 · 相对时间"。下载项悬停时显示来源域名。磁盘行的末尾有 ⏏ 推出按钮。
5. **空状态 / 提示条**：没有结果时显示空状态。Spotlight 不可用时，在顶部显示提示条（见第 7 节）。
6. **底栏**：显示当前快捷键提示，以及设置按钮（⚙︎）。

### 5.3 操作

| 操作 | 鼠标 | 键盘 |
|---|---|---|
| 打开（面板随后关闭） | 单击 | `↩` |
| 在 Finder 中显示 | 右键菜单 | `⌘↩` |
| 快速预览 | 右键菜单 | `空格` |
| 拖到其他 app | 拖出 | — |
| 复制路径 | 右键菜单 | `⌥⌘C` |
| 置顶 / 取消置顶 | 右键菜单 | `⌘P` |
| 用指定 app 打开 | 右键 → 打开方式 ▸ | — |
| 忽略 | 右键 → 忽略 ▸（此文件 / 此文件夹下所有项目 / 此扩展名） | — |
| 推出磁盘 | 行尾 ⏏ 按钮 | — |
| 移动选中项 | — | `↑` `↓` |

### 5.4 设置窗口

- **通用**：快捷键录制、开机自动启动、时间范围、各分类是否显示。
- **忽略规则**：规则列表（可增、删、改）、"忽略隐藏文件"开关、"恢复默认"按钮。
- **关于**：版本号、GitHub 项目链接、"查看新版本"（打开 Releases 页面）。

### 5.5 欢迎窗口

首次启动时显示：一句话介绍、当前快捷键、"开机自动启动"开关。如果第 6 节的权限实验表明需要用户授权，在这里增加一页授权引导。

## 6. 系统隐私权限

不开沙盒的 app 访问"桌面""文稿""下载"等受保护目录时，仍可能触发系统隐私授权弹窗。以下操作是否会弹窗，目前**还不确定**：读取 Spotlight 查询结果、读取文件图标、快速预览、拖出、创建书签。

实现计划的**第一项任务**就是验证这一点（用一个临时实验程序，验证后丢弃）。根据结果决定：

- 如果都不弹窗：不需要授权引导。
- 如果部分弹窗、但用户授权一次后一直有效：欢迎窗口里说明即将出现的授权弹窗。
- 如果要"完全磁盘访问权限"才能正常使用：欢迎窗口增加一个引导页，提供按钮直接跳转到对应的系统设置页面。

## 7. 异常处理

| 场景 | 处理 |
|---|---|
| Spotlight 查询启动失败，或主目录查询长时间返回 0 条 | 面板顶部显示提示条：主目录可能被排除在 Spotlight 索引之外，并说明到"系统设置 → Spotlight"检查 |
| 快捷键注册失败（被占用） | 设置页显示警告，提示更换快捷键 |
| 打开文件时文件已不存在 | 该行显示"文件已不存在"，并从列表中移除 |
| 推出磁盘失败 | 显示系统返回的错误原因（例如"磁盘正在使用"） |
| `pins.json` 无法解析 | 把原文件重命名为 `pins.corrupt-<时间戳>.json` 留作备份，重置为空列表，并写日志 |
| 置顶项的书签无法解析 | 该项显示为"找不到"，不自动删除 |

日志统一使用 `os.Logger`，subsystem 为 app 的 bundle identifier。

## 8. 测试

### 8.1 自动化测试（`swift test`，覆盖 BiuBiuCore）

- `IgnoreRules`：各规则类型的匹配、隐藏文件开关、默认规则、恢复默认。
- 活动类型判定：用假的元数据组合覆盖 4.2 的每条规则，包括文件夹忽略修改时间、下载判定、`sourceHost` 解析。
- `ActivityStore`：多数据源合并、同 URL 去重取最新、套用忽略规则、排序、500 条上限、搜索筛选、分类筛选、时间分组（注入固定时钟，覆盖跨天边界）。
- `PinStore`：保存和读取、排序、文件损坏时的备份与重置。
- 数据源都放在协议后面，测试中用假数据源，不依赖真实的 Spotlight。

### 8.2 手动验收清单

- 全屏应用中用快捷键唤出、关闭
- 多显示器下面板出现在正确的屏幕
- 新下载一个文件，几秒内出现在列表顶部，并标为"下载"
- 拖出到 Finder 和邮件 app
- 快速预览图片和 PDF
- 插拔 U 盘：出现"已连接"条目；推出成功；推出被占用的磁盘时显示错误
- 置顶后移动该文件，置顶项仍能打开
- 忽略某个文件夹后，其中的文件不再出现
- 中文和英文两种系统语言下的界面
- 升级到新版本后，已授予的隐私权限仍然有效（验证自签名证书方案）

## 9. 构建与发布

### 9.1 项目结构

```
BiuBiu/
├── Package.swift
├── Sources/
│   ├── BiuBiuCore/      # 模型、数据源、Store、规则、持久化
│   └── BiuBiu/          # App 外壳与 SwiftUI 视图、本地化资源
├── Tests/
│   └── BiuBiuCoreTests/
├── Resources/           # Info.plist 模板、AppIcon.icns
├── scripts/
│   └── build-app.sh
├── .github/workflows/
│   ├── ci.yml           # push / PR：构建 + 测试
│   └── release.yml      # 推送 v* 标签：构建、签名、上传 Release
├── docs/
├── README.md            # 中英文
└── LICENSE              # MIT
```

### 9.2 打包流程（`scripts/build-app.sh`）

1. `swift build -c release`
2. 组装 `BiuBiu.app`：复制可执行文件和资源；Info.plist 设置 `LSUIElement = YES`（不显示 Dock 图标）、bundle identifier、版本号、最低系统版本 14.0。
3. 用自签名证书执行 `codesign`。证书名称通过环境变量传入；没有提供时退回 ad-hoc 签名，用于本地开发。
4. 用 `ditto` 打成 `BiuBiu-<版本>.zip`。

需要验证：只用 Command Line Tools 能否构建同时支持 Apple 芯片和 Intel 的通用二进制。如果不行，第一版只发布 Apple 芯片版本，并在 README 中注明。

### 9.3 GitHub Actions

- `ci.yml`：每次 push 和 PR 时执行 `swift build` 和 `swift test`。
- `release.yml`：推送 `v*` 标签时，从仓库 secrets 导入自签名证书到临时钥匙串，运行 `build-app.sh`，把 zip 上传到对应的 GitHub Release。

### 9.4 README

- 功能介绍和截图
- 安装方法：下载 zip，解压，把 app 拖进"应用程序"文件夹
- 首次打开时如何在"系统设置 → 隐私与安全性"中点"仍要打开"（较新的 macOS 已不支持"右键 → 打开"绕过）
- 从源码构建的方法

## 10. 风险与待验证项

| 风险 | 验证方式 | 应对 |
|---|---|---|
| 隐私授权弹窗的触发范围不明确 | 第 6 节的实验 | 按结果调整欢迎窗口 |
| 不同 macOS 版本上，非开发者签名的 app 首次打开受到的限制 | 在本机实际打包并从下载的 zip 打开 | README 写准确的放行步骤 |
| 只用 Command Line Tools 能否构建通用二进制 | 分别构建两个架构后用 `lipo` 合并 | 不行则只发 Apple 芯片版本 |
| `SMAppService` 对非开发者签名的 app 是否可用 | 实际调用测试 | 不可用则去掉开机启动，并在 README 中说明如何手动添加登录项 |
| Spotlight 写入索引的延迟让新下载的文件出现得太慢 | 手动验收中计时 | 增加针对 `~/Downloads` 的 FSEvents 数据源（第一版不做） |
