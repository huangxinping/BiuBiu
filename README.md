# BiuBiu

[English](#english) · 中文

BiuBiu 是一个常驻 macOS 菜单栏的近期文件快速访问工具。按下快捷键（默认 `⌥⌘R`），就能看到最近打开、保存、下载的文件和文件夹，以及最近安装的应用和刚接上的外置磁盘。全屏应用里也能唤出。

- 基于 Spotlight 索引，全部在本地处理，不联网
- 单击打开；`⌘↩` 在 Finder 中显示；空格或 `⌘Y` 快速预览；直接拖到其他 app
- 置顶常用的文件和文件夹；把不想看到的文件、文件夹或扩展名加入忽略列表

## 安装

1. 从 [Releases](../../releases/latest) 下载 `BiuBiu-<版本>.zip` 并解压。
2. 把 `BiuBiu.app` 拖进"应用程序"文件夹。
3. 第一次打开时，macOS 会提示"无法验证开发者"（BiuBiu 没有使用付费的 Apple 开发者证书）。点"完成"，然后打开"系统设置 → 隐私与安全性"，在页面底部找到 BiuBiu，点"仍要打开"并输入密码确认。

   也可以在终端里执行：`xattr -dr com.apple.quarantine /Applications/BiuBiu.app`

之后的版本都使用同一张自签名证书，升级不会丢失已授予的权限。

## 系统要求

macOS 14 或更高版本，Apple 芯片或 Intel。

## 如果列表是空的

BiuBiu 依赖 Spotlight。请在"系统设置 → Spotlight"中确认主文件夹没有被排除在搜索之外。

## 从源码构建

只需要 Command Line Tools（`xcode-select --install`），不需要 Xcode。

```bash
swift run BiuBiuTestRunner   # 运行测试
swift run BiuBiu             # 直接运行（界面为英文，没有本地化资源）
swift run BiuBiu --dump      # 打印 Spotlight 当前找到的最近项目
scripts/build-app.sh         # 打包 dist/BiuBiu.app 和 zip（临时签名）
```

## 许可

MIT

---

## English

BiuBiu is a menu bar app for macOS that shows the files and folders you recently opened, saved or downloaded, plus newly installed apps and connected drives. Press `⌥⌘R` (configurable) anywhere, including full-screen apps.

- Built on the Spotlight index; everything stays on your Mac
- Click to open, `⌘↩` to show in Finder, Space or `⌘Y` to Quick Look, or drag items into other apps
- Pin favorites; ignore files, folders or extensions you never want to see

### Install

1. Download `BiuBiu-<version>.zip` from [Releases](../../releases/latest) and unzip it.
2. Move `BiuBiu.app` to Applications.
3. The first launch is blocked because BiuBiu is not signed with a paid Apple Developer ID. Click Done, open System Settings → Privacy & Security, scroll down to BiuBiu and click "Open Anyway".

   Or run: `xattr -dr com.apple.quarantine /Applications/BiuBiu.app`

Every release is signed with the same self-signed certificate, so updates keep the permissions you granted.

### Requirements

macOS 14 or later, Apple silicon or Intel.

### Building from source

Command Line Tools are enough (`xcode-select --install`); Xcode is not required. See the commands above.

### License

MIT
