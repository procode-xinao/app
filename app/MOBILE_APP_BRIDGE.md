# MobileApp WebView 桥接说明

在 Flutter App 的全屏 **WebView** 中，原生会注入全局对象 **`window.MobileApp`**。H5 通过它调用存储、鉴权、系统 UI、设备能力等；**路由与页面结构由前端自行实现**，壳层不再提供原生顶栏或底部 Tab。

---

## 目录

1. [应用壳与启动配置](#1-应用壳与启动配置)
2. [工作原理与前置条件](#2-工作原理与前置条件)
3. [调用约定](#3-调用约定)
4. [当前工程中的可用性](#4-当前工程中的可用性)
5. [API 总览](#5-api-总览)
6. [`MobileApp.Window`（系统栏与衬色）](#6-mobileappwindow系统栏与衬色)
7. [`MobileApp.Auth`](#7-mobileappauth)
8. [`MobileApp.Navigation`](#8-mobileappnavigation)
9. [`MobileApp.NavigationBar`](#9-mobileappnavigationbar)
10. [`MobileApp.Services.*`](#10-mobileappservices)
11. [示例](#11-示例)
12. [错误与调试](#12-错误与调试)
13. [权限与平台](#13-权限与平台)
14. [附录](#14-附录)

---

## 1. 应用壳与启动配置

### 1.1 壳形态

| 项目 | 说明 |
|------|------|
| 入口 | 拉取 `/v1/app` 后，在 **`SplashPage`** 内用 **`AppWebShell`** 加载 H5 **`url`** |
| 默认 UI | **非沉浸**：`SystemUiMode.edgeToEdge`，WebView 外包 **`SafeArea`**，状态栏/底部手势区可见（电量、时间等） |
| 沉浸 | H5 调用 **`MobileApp.Window.SetImmersive(true)`** 后去掉 SafeArea 并 **`immersiveSticky`**；`false` 恢复 |
| 衬色 | 状态栏、导航栏、`Scaffold` 与 WebView 底层背景使用同一套「铬区」颜色；可由接口、dart-define 或桥接设置（见 [§6](#6-mobileappwindow系统栏与衬色)） |
| 过度滚动 | 原生 **`WebViewOverScrollMode.never`** + 页面注入 **`overscroll-behavior: none`**，减轻拉到底的回弹 |

### 1.2 `/v1/app` JSON（与壳相关的字段）

| 字段 | 类型 | 说明 |
|------|------|------|
| **`url`** | string | **必填**，H5 入口（绝对 URL 或相对当前服务 base 的路径） |
| **`is_enable`** | boolean | 必须为 `true`，否则启动失败 |
| **`jpush_app_key`** | string | 可选，极光 AppKey |
| **`top_background_color`** | string | 可选，铬区十六进制色（`#RGB` / `#RRGGBB` / `#AARRGGBB`，`#` 可省略）；缺省见下 |

### 1.3 本地默认衬色

- 构建参数：`--dart-define=APP_TOP_BACKGROUND_COLOR=RRGGBB`（与 `lib/app_branding.dart` 中 **`kTopBackgroundColorDefine`** 一致，默认 `000000`）。
- 优先级：**`top_background_color`（接口）** → **dart-define** → **黑色**。

### 1.4 登录态与 WebView

- 原生 **`SharedPreferences`** 键 **`access_token`** 与 H5 **`localStorage.access_token`** 配合使用。
- 若本地 token 存在且 **`/v1/user`** 校验通过，壳在 WebView 就绪后会注入 `localStorage`（与 `Auth` 写入的键一致）。

---

## 2. 工作原理与前置条件

### 2.1 通信机制

- 页面通过 JS 通道 **`AppBridge`** 向 Flutter 发送 JSON：`{ v, id, ns, method, args }`。
- Flutter **`AppJsBridge`** 解析命名空间 **`ns`** 与方法 **`method`**，通过 **`window.__appBridgeDeliver`** 将结果写回对应 Promise。
- 注入发生在 **`NavigationDelegate.onPageFinished`** 之后（并与 `nativeLikeLockdown` 脚本顺序相关），因此 **`DOMContentLoaded` 时可能尚无 `MobileApp`**。请在 **`load` / 首屏脚本靠后** 或 **用户操作** 中调用，并做好 `MobileApp` 判空。

### 2.2 注入条件

- 使用 **`AppWebShell`** 且传入 **`bridge: AppJsBridge(...)`**，并完成 **`registerChannel`**、**`injectBootstrap`**（由 `AppWebShell` 内部在适当时机调用）。
- 若 **未传 `bridge`**，`window.MobileApp` **不存在**。

### 2.3 源码位置

| 内容 | 路径 |
|------|------|
| 注入的 JS 字符串 | `lib/services/app_js_bridge.dart` → `_bootstrap` |
| 分发与实现 | 同文件 → `_dispatch`、各 `_xxxDispatch` |
| WebView 封装 | `lib/widgets/app_web_shell.dart` |
| 十六进制颜色解析（接口与桥接共用） | `lib/utils/hex_color.dart` |

---

## 3. 调用约定

- 所有 `MobileApp.*` 方法返回 **`Promise`**：**成功** `resolve(data)`，**失败** `reject(Error)`。
- 字符串参数在注入层多会 **`String(...)`**；对象须为可 JSON 语义的普通 Object。
- 建议统一 **`try/catch`** 或 **`.catch()`**。

```javascript
async function withMobileApp(fn) {
  if (!window.MobileApp) {
    console.warn('非 App 内 WebView 或未注入 bridge');
    return null;
  }
  try {
    return await fn();
  } catch (e) {
    console.error(e);
    return null;
  }
}
```

---

## 4. 当前工程中的可用性

| 能力 | 在本工程中的表现 |
|------|------------------|
| **`MobileApp.Window.*`** | **已接**：沉浸切换、铬区颜色（见 §6） |
| **`MobileApp.Navigation.GoHome`** | **已接**：在当前 WebView 内 **`loadRequest`** 配置中的入口 **`url`**，并视情况维护 token |
| **`MobileApp.NavigationBar.*`** | **未接 setter**：调用仍 **`resolve(true)`**，但 **无任何原生顶栏 UI**（保留 API 供将来或其它页面复用桥接代码） |
| **`MobileApp.Services.*` / `Auth`** | **已接**，有桥接即可用 |
| **`ToastService.Show`** | 依赖 `SnackBar`；若 Flutter 侧已 **dispose**，可能静默不展示 |

---

## 5. API 总览

| 命名空间 | 作用 |
|----------|------|
| **`Window`** | 全屏/非全屏、状态栏与底部导航栏衬色、与壳层 SafeArea 联动 |
| **`Auth`** | `access_token` 读写 |
| **`Navigation`** | 回到 H5 入口地址 |
| **`NavigationBar`** | 原生 AppBar（本壳未使用） |
| **`Services.*`** | 存储、Toast、外链、定位、通讯录、扫码、文件、生物识别、设备信息、推送、应用名、分享、剪贴板、网络、相册/相机、系统设置 |

---

## 6. `MobileApp.Window`（系统栏与衬色）

### 6.1 `SetImmersive(enabled)`

| 项目 | 说明 |
|------|------|
| **签名** | `SetImmersive(enabled: boolean)` |
| **返回值** | `Promise<true>` |
| **`true`** | `SystemUiMode.immersiveSticky`，隐藏系统状态栏与底部系统栏；壳层 **去掉 WebView 外层的 SafeArea**，内容可铺满 |
| **`false`** | `SystemUiMode.edgeToEdge`；壳层 **恢复 SafeArea**（状态栏与底部手势区留白） |
| **说明** | 与是否曾有原生顶栏无关；本工程仅有 **单层 WebView** |

### 6.2 `SetChromeBackgroundColor(color)`

用于在运行时修改 **非沉浸** 下的衬色（状态栏、底部导航栏、`Scaffold` 背景、WebView **`setBackgroundColor`**）。沉浸模式下系统栏为透明，但 WebView 底层颜色仍会更新。

| 项目 | 说明 |
|------|------|
| **签名** | `SetChromeBackgroundColor(color: string)` |
| **返回值** | `Promise<true>` |
| **合法 `color`** | `#RGB`、`#RRGGBB`、`#AARRGGBB`，`#` 可省略 |
| **空字符串 `''` 或仅空白** | **清除**桥接覆盖，恢复为启动时的默认衬色（§1.2 / §1.3） |
| **非法字符串** | **reject**（Dart：`无效的 color...`） |

**示例**

```javascript
await MobileApp.Window.SetChromeBackgroundColor('#1677FF');
await MobileApp.Window.SetChromeBackgroundColor(''); // 恢复接口 / dart-define 默认
```

---

## 7. `MobileApp.Auth`

与原生 **`SharedPreferences`** 同步键名 **`access_token`**。

| 方法 | 参数 | 返回值 |
|------|------|--------|
| **`SetAccessToken(token)`** | 字符串（空串仍会写入） | `Promise<true>` |
| **`GetAccessToken()`** | — | `Promise<string \| null>` |
| **`ClearAccessToken()`** | — | `Promise<true>` |

---

## 8. `MobileApp.Navigation`

### `GoHome()`

| 项目 | 说明 |
|------|------|
| **返回值** | `Promise<true>` |
| **行为** | 在当前 WebView 加载 **`/v1/app` 返回的入口 `url`**（绝对地址）；若本地有有效 token 逻辑由壳层维护 |
| **未配置处理器** | **reject**（`未配置 GoHome 处理器`）——本工程 **SplashPage 已配置** |

典型用法：单页应用内「回到首页」时由 H5 路由处理即可；若需整页重新加载入口，可调用 **`GoHome()`**。

---

## 9. `MobileApp.NavigationBar`

控制 **Material AppBar**（非浏览器 UI）。**当前全屏 Web 壳未注册任何 setter**，下列调用 **不会改变界面**，但仍返回 **`Promise<true>`**（除非参数校验失败）：

- `Show()` / `Hide()` → `setVisible`
- `SetTitle(title)`
- `SetStyle(style)` — `style` 须为对象，常用键：`title`、`backgroundColor`、`foregroundColor`、`fontSize`、`fontWeight`
- `SetButtons({ back?, scan? })` — 仅显式传入的 `boolean` 键生效，`buttons` 须为对象

若将来在其它原生页复用 **`AppJsBridge`** 并传入对应回调，上述 API 可重新生效。

---

## 10. `MobileApp.Services.*`

### 10.1 一览表

| 服务 | 方法 | 返回值要点 |
|------|------|------------|
| **StorageService** | `Get` / `Set` / `Remove` / `Keys` / `Clear` | 与 Auth 不同命名空间；`key` 为空会 **reject** |
| **ToastService** | `Show(message)` | `Promise<null>` |
| **LauncherService** | `OpenUrl(url)` | `Promise<true>` |
| **LocationService** | `Get()` | `Promise<object>`，需定位权限 |
| **ContactsService** | `List(limit?)` | 默认 `limit=50`，需通讯录权限 |
| **QrService** | `Scan()` | `Promise<{ text: string }>`，需相机 |
| **FileService** | `PickFile` | `Promise<{ name, path, size }>`，取消等会 **reject** |
| | `ReadText` / `WriteText` / `Delete` / `ListDir` / `GetAppDir` | `path` 必填；`WriteText`/`Delete` 成功 `true`；`GetAppDir` → `{ documents }` |
| **BiometricService** | `IsSupported` / `Authenticate(reason?)` / `GetAvailableBiometrics` | 见方法名 |
| **DeviceService** | `GetInfo()` | `Promise<object>` |
| **PushService** | `GetRegistrationId()` | `Promise<string \| null>`，极光 RID |
| **AppService** | `GetInfo()` | `Promise<{ displayName: string }>`（构建配置中的应用名） |
| **ShareService** | `ShareText(text, subject?)` / `ShareUri(url)` | `Promise<true>` |
| **ClipboardService** | `SetText` / `GetText` | 纯文本 |
| **NetworkService** | `GetStatus()` | `{ types: string[], hasNetwork: boolean }`（**不保证能上公网**） |
| **MediaService** | `PickFromGallery` / `TakePhoto` | `Promise<string \| null>` 本地路径 |
| **SettingsService** | `OpenAppSettings()` | `Promise<true>` |

### 10.2 细节与错误（节选）

- **Storage**：`Set`/`Get` 等对空 `key` **reject**。
- **FileService**：`PickFile` 用户取消 → **reject**；`ListDir` 项含 `path`、`type`、`size`、`modified`（毫秒时间戳）。
- **ShareText**：`subject` 空或省略则无主题。

---

## 11. 示例

### 11.1 保存 token 并回到壳配置的 H5 根地址

```javascript
await MobileApp.Auth.SetAccessToken(token);
await MobileApp.Navigation.GoHome();
```

### 11.2 视频全屏再恢复（无原生顶栏，仅用 Window）

```javascript
await MobileApp.Window.SetImmersive(true);
// …
await MobileApp.Window.SetImmersive(false);
```

### 11.3 随路由切换状态栏衬色

```javascript
await MobileApp.Window.SetChromeBackgroundColor('#1a1a2e');
await MobileApp.Window.SetChromeBackgroundColor(''); // 某页离开时恢复默认
```

### 11.4 分享、网络、剪贴板、相册、推送

```javascript
await MobileApp.Services.ShareService.ShareText('正文', '标题');
const { types, hasNetwork } = await MobileApp.Services.NetworkService.GetStatus();
await MobileApp.Services.ClipboardService.SetText('hello');
const path = await MobileApp.Services.MediaService.PickFromGallery();
const rid = await MobileApp.Services.PushService.GetRegistrationId();
```

---

## 12. 错误与调试

- 搜索 Flutter 日志：`AppJsBridge inject failed`、`AppJsBridge reply failed`。
- **`MobileApp === undefined`**：当前页是否使用带 **`bridge`** 的 **`AppWebShell`**，且主文档 **`onPageFinished`** 已执行。

---

## 13. 权限与平台

- 定位、通讯录、相机、生物识别等需在系统中授权；拒绝后对应接口 **reject**。
- **iOS**：`Info.plist` 中 `NS*UsageDescription`。
- **Android**：`AndroidManifest.xml` 权限以工程为准。
- **桌面 / Web**：部分能力不可用或行为不同；本项目主要面向 **iOS / Android**。

---

## 14. 附录

### 14.1 与源码的对应关系

| 文档 | 代码 |
|------|------|
| JS 助手对象 | `lib/services/app_js_bridge.dart` → `_bootstrap` |
| 分发 | `_dispatch`、`_windowDispatch`、`_authDispatch` 等 |
| WebView | `lib/widgets/app_web_shell.dart` |
| 启动与铬区 | `lib/pages/splash_page.dart` |
| 配置拉取 | `lib/services/app_bootstrap_service.dart` |

### 14.2 文档维护

接口增减或壳行为变更时，请同步更新本文件与 `app_js_bridge.dart` 顶部文档注释。
