# BiuBiu 设计文档

- 日期：2026-10-01
- 状态：待审阅

## 1. 目标与背景

BiuBiu 是一款常驻 macOS 菜单栏的近期文件快速访问工具。按下快捷键（或点击菜单栏图标）后弹出一个简洁面板，按时间倒序列出最近打开、保存、下载的文件与文件夹，以及最近打开或安装的应用和新连接的外置磁盘。

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
| 技术栈 | Swift 6 + **纯 AppKit**（不用 SwiftUI），用 SwiftPM 构建，不需要 Xcode | 已实测：只有 Command Line Tools 时，macOS 27 SDK 的 SwiftUI `@State` 宏、Swift Testing 宏和 XCTest 都不可用；Swift + AppKit 可以正常编译 |
| 系统要求 | macOS 14 及以上 | 覆盖近三年的系统，可使用 `SMAppService` 等较新的 API |
| 界面语言 | 简体中文和英文 | 开源项目，面向更多用户 |
| 第三方依赖 | **无** | KeyboardShortcuts 依赖 SwiftUI 宏，没有 Xcode 时无法编译；全局快捷键（Carbon `RegisterEventHotKey`）和录制控件自己实现 |
| 自动化测试 | 自写的测试程序 `BiuBiuTestRunner`（一个可执行 target），用 `swift run BiuBiuTestRunner` 运行 | 没有 Xcode 时 XCTest 和 Swift Testing 都不可用；测试程序输出每条失败并以非零退出码结束，CI 照常可用 |
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
SpotlightFileSource  AppSource  VolumeSource  PinStore
   │          │          │
   └──── ActivitySource 协议 ────┘
                    │
        IgnoreRules / AppSettings
```

代码拆成两个 SwiftPM target：

- **`BiuBiuCore`**（库）：数据模型、`ActivitySource` 协议及三个实现、`ActivityStore`、`IgnoreRules`、`PinStore`、`AppSettings`、活动类型判定、时间分组、快捷键数据模型。不依赖 AppKit 视图层，可以单独测试。供测试使用的接口用 Swift 的 `package` 访问级别暴露。
- **`BiuBiu`**（可执行程序）：菜单栏图标、全局快捷键注册、浮动面板、AppKit 视图、设置窗口、欢迎窗口。
- **`BiuBiuTestRunner`**（可执行程序）：BiuBiuCore 的自动化测试，见第 8 节。

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
@MainActor
protocol ActivitySource: AnyObject {
    var id: String { get }
    /// 开始监听；每次回调都给出这个数据源当前的完整结果集
    func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void)
    func stop()
}
```

`AppDelegate` 启动所有数据源，把回调结果交给 `ActivityStore.update(sourceID:items:)`；任一数据源推送新结果，就重新计算一次合并后的列表。Spotlight 查询的起始时间在启动时固定，所以距上次启动超过 1 小时、再次打开面板时，重启所有数据源，让时间范围向前移动。（用回调而不是 `AsyncStream`：Spotlight 和系统通知本来就在主线程回调，测试也可以同步进行。）

### 3.3 模块职责

- **SpotlightFileSource**：在主目录范围内持续查询（`NSMetadataQueryUserHomeScope`）。查询条件见 4.2。把 Spotlight 返回的结果转换成 `ActivityItem`。`~/Applications` 里的 app 跳过不报，交给 AppSource，否则同一个 app 会以"文件 · 新增"的形式出现。
- **AppSource**：在 `/Applications`、`~/Applications` 和 `/System/Applications` 中查询内容类型为 `com.apple.application-bundle`，并且"加入文件夹"时间（`kMDItemDateAdded`）或"最近打开时间"（`kMDItemLastUsedDate`）落在时间范围内的项目。两者取较新的一个决定事件：`installed` 或 `opened`。打开过的 app 只出现在"应用"分类里，不进入"全部"：常用 app 每天都会启动，混进时间线会把文件淹没（2026-10-02 按用户反馈增加"最近打开的应用"）。
- **VolumeSource**：启动时读取当前已挂载的卷，之后监听系统的挂载和推出通知。只保留可移除、可推出或网络类型的卷。挂载时间只在运行期间收到通知时记录；启动前已经接上的卷，`date` 为 nil。负责执行推出操作。
- **ActivityStore**（`@MainActor` 的普通类，数据变化时调用 `onChange` 回调通知界面刷新）：合并各数据源结果；同一 URL 只保留 `date` 最新的一条；套用 `IgnoreRules`；按日期倒序排列（不截断）；根据时间范围、搜索词和当前分类筛选，筛选结果最多显示 500 条（先筛选再截断，保证"下载"等分类不会被其他分类的大量条目挤掉）；按时间分组。时钟可注入。
- **IgnoreRules**：规则分三种：路径前缀、路径中包含的片段、扩展名。另有一个"忽略隐藏文件"开关。提供默认规则（见 4.3）和"恢复默认"。保存在 `UserDefaults` 中。
- **PinStore**：保存置顶项目的有序列表，每项记录普通书签数据（bookmark，文件移动或改名后仍能找到）和置顶时间。存在 `~/Library/Application Support/BiuBiu/pins.json`。
- **AppSettings**：时间范围、各分类是否显示、上次选中的分类、是否已看过欢迎页、置顶区是否折叠。是否开机启动不单独保存，直接读写 `SMAppService.mainApp` 的状态。全局快捷键（键码 + 修饰键）也保存在这里。
- **PanelController**：管理一个 `NSPanel`，样式为 `.nonactivatingPanel`，窗口层级为浮动窗口，集合行为设为 `.canJoinAllSpaces` + `.fullScreenAuxiliary`，内容全部用 AppKit 实现（列表用 `NSTableView`）。负责计算面板位置、显示和隐藏，以及点击面板外部时自动关闭。
- **StatusItemController**：管理菜单栏图标。左键点击切换面板显示；右键弹出菜单（设置、退出）。

## 4. 数据规则

### 4.1 时间范围

默认 7 天，可选 1、3、7、14、30 天。每个分类最多显示 500 条。

### 4.2 文件与文件夹的判定

Spotlight 查询条件（以文件为例；文件夹另有规则，见下文）：

```
kMDItemLastUsedDate >= since
  OR kMDItemContentModificationDate >= since
  OR kMDItemDateAdded >= since
```

每个结果的活动类型和时间按以下规则判定：

1. 取 最近打开时间（LastUsed）、内容修改时间（ContentModification）、加入文件夹时间（DateAdded）三者中最新的一个作为 `date`。
2. 最新的是 LastUsed，判为 `opened`；是 ContentModification，判为 `saved`；是 DateAdded，判为 `added`。与最新时间相差 2 秒以内的视为并列，并列时优先级为 `added` > `saved` > `opened`。原因：浏览器下载完成后，修改时间往往比加入时间晚几毫秒，不这样处理就会把下载误判成"保存"。
3. **下载**（2026-10-01 按用户验收反馈修订）：满足以下任一条件的文件，其"加入"事件记为 `downloaded`：
   - 位于 `~/Downloads` 下（不论怎么到达的）；
   - 带有下载来源记录（`kMDItemWhereFroms` 非空），并且就是在当前文件夹里生成的："创建时间"与"加入时间"相差不超过 2 秒（浏览器直接存到了别的文件夹）。

   从别处**移入**当前文件夹的文件（加入时间明显晚于创建时间）不算下载，记为 `added`。
   "是下载来的"是条目的一个属性（`isDownload`），不随之后的打开、保存而消失："下载"分类按这个属性筛选，所以下载后打开过的文件仍留在"下载"分类里，悬停仍显示来源域名；时间线标签仍按最新发生的事件显示（如"打开"）（2026-10-02 最终审查后修订）。原因：移动文件会把"加入时间"更新为移动的时刻，用户已经整理走的下载不应再出现在"下载"分类里。
   下载的时间取"修改时间"（浏览器把 `x.crdownload` 原地改名，"加入时间"停留在下载开始的时刻，"修改时间"才是下载完成的时刻）；但如果修改发生在加入一小时以后，视为之后的编辑，记为 `saved`。`sourceHost` 取下载来源记录中第一个网址的域名。
4. **文件夹**（内容类型为 `public.folder`）只看 LastUsed 和 DateAdded，忽略内容修改时间，对应 `opened` 或 `added`；两者都不在时间范围内的文件夹直接丢弃。原因是文件夹里任何文件变动都会刷新它的修改时间，会导致刷屏。"下载"文件夹里的文件夹（例如解压出来的）事件仍是 `added`，但 `isDownload` 为真，所以会出现在"下载"分类里（2026-10-02 review 后明确）。
5. **未来的时间**：Spotlight 偶尔会返回在未来的修改时间（相机时钟不准、恢复的备份）。超过当前时间 2 秒以上的时间一律忽略，这样真实的打开记录仍能显示；三个时间都不可信的条目丢弃（2026-10-02 review 后增加）。

界面上的标签文字：`opened` 显示"打开"、`saved` 显示"保存"、`added` 显示"新增"、`downloaded` 显示"下载"、`installed` 显示"安装/更新"（系统无法可靠区分安装和更新）、`mounted` 显示"已连接"。

### 4.3 默认忽略规则

- 隐藏文件和文件夹（路径中任何一段以 `.` 开头），以及 Finder 的自定义图标文件 `Icon\r`
- 路径前缀：`~/Library/`、`~/.Trash/`。例外：iCloud 云盘位于 `~/Library/Mobile Documents/`，比它更上层的路径前缀规则（如默认的 `~/Library/`）不会隐藏它；iCloud 云盘内部的规则照常生效。iCloud 云盘的文件夹在副标题中显示为"iCloud Drive"（2026-10-02 最终审查后增加）
- 路径中包含：`.app/`（程序包内部）、`/node_modules/`、`/.git/`、`/DerivedData/`、`/__pycache__/`、`.photoslibrary`、`.musiclibrary`、`.tvlibrary`（照片、音乐、视频资料库及其内部文件；在本机实测中它们是主要噪音来源）
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
4. **时间线**：按 4.4 分组显示。每行包括：系统文件图标、文件名、所在文件夹名、"类型标签 · 相对时间"。下载项悬停时显示来源域名。磁盘行的末尾有 ⏏ 推出按钮。已置顶的条目在所有分类的时间线里，副标题前都显示 📌（2026-10-02 按用户验收反馈增加：置顶区只在"全部"视图中出现，其他分类需要这个标记才看得出哪些已置顶）。
5. **空状态 / 提示条**：没有结果时显示空状态。Spotlight 不可用时，在顶部显示提示条（见第 7 节）。
6. **底栏**：显示当前快捷键提示，以及设置按钮（⚙︎）。

### 5.3 操作

| 操作 | 鼠标 | 键盘 |
|---|---|---|
| 打开（面板随后关闭） | 单击 | `↩` |
| 在 Finder 中显示 | 右键菜单 | `⌘↩` |
| 快速预览 | 右键菜单 | `空格`（仅在搜索框为空时；否则空格照常输入）或 `⌘Y` |
| 拖到其他 app | 拖出（以"拷贝"方式，不会移动原文件） | — |
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

**实测补充（2026-10-02）：** 在整个用户目录里做 Spotlight 查询**不会**触发授权弹窗。没有权限时，系统只是悄悄去掉这三个文件夹里的结果。只有直接读取这些文件夹（例如列出目录内容，或把查询范围限定为某个文件夹）才会弹窗。因此：

- 每次启动时（首次运行在欢迎窗口关闭后），app 先在后台线程列出这三个文件夹的内容，以此触发授权弹窗，等用户回答后再启动文件查询。
- 仍然没有权限的文件夹，在面板顶部显示一行提示，点击后跳到"系统设置 → 隐私与安全性 → 文件与文件夹"。
- 面板每次打开时重新检查之前没有权限的文件夹。如果在系统设置里补开了权限，就重新启动文件查询。

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

### 8.1 自动化测试（`swift run BiuBiuTestRunner`，覆盖 BiuBiuCore）

测试程序提供 `expect(条件, 描述)` 和 `expectEqual(实际, 期望)` 两个断言，以及按名称分组的测试用例注册。运行时逐条输出失败的用例名、文件和行号，最后输出汇总；有任何失败时以退出码 1 结束。

覆盖范围：

- `IgnoreRules`：各规则类型的匹配、隐藏文件开关、默认规则、恢复默认。
- 活动类型判定：用假的元数据组合覆盖 4.2 的每条规则，包括文件夹忽略修改时间、下载判定、`sourceHost` 解析。
- `ActivityStore`：多数据源合并、同 URL 去重取最新、套用忽略规则、排序、500 条显示上限（不影响其他分类）、搜索筛选、分类筛选、时间分组（注入固定时钟，覆盖跨天边界）。
- `PinStore`：保存和读取、排序、文件损坏时的备份与重置。
- 快捷键模型：序列化与反序列化、显示文字（如 `⌥⌘R`）、拒绝不含修饰键的组合。
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
│   ├── BiuBiu/          # App 外壳与 AppKit 视图
│   └── BiuBiuTestRunner/ # 自写的测试程序
├── Resources/           # Info.plist 模板、AppIcon.icns、en.lproj / zh-Hans.lproj
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

1. `swift build -c release --arch arm64 --arch x86_64`（已实测：Command Line Tools 可以直接产出同时支持 Apple 芯片和 Intel 的通用二进制）
2. 组装 `BiuBiu.app`：复制可执行文件；把 `Resources/` 下的 `.lproj` 本地化文件复制到 `Contents/Resources/`；Info.plist 设置 `LSUIElement = YES`（不显示 Dock 图标）、bundle identifier、版本号、最低系统版本 14.0。
3. 用自签名证书执行 `codesign`。证书名称通过环境变量传入；没有提供时退回 ad-hoc 签名，用于本地开发。
4. 用 `ditto` 打成 `BiuBiu-<版本>.zip`。

界面文字统一通过 `NSLocalizedString` 读取，键名就是英文原文。所以本地开发时直接 `swift run BiuBiu`（没有 `.lproj`），界面显示英文；打包后的 app 按系统语言显示中文或英文。

### 9.3 GitHub Actions

- `ci.yml`：每次 push 和 PR 时执行 `swift build` 和 `swift run BiuBiuTestRunner`。
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
| `SMAppService` 对非开发者签名的 app 是否可用 | 实际调用测试 | 不可用则去掉开机启动，并在 README 中说明如何手动添加登录项 |
| Spotlight 写入索引的延迟让新下载的文件出现得太慢 | 手动验收中计时 | 增加针对 `~/Downloads` 的 FSEvents 数据源（第一版不做） |
