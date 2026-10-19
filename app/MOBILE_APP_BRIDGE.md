# MobileApp WebView 桥接开发文档

在 Flutter 全屏 **WebView** 中，原生注入全局对象 **`window.MobileApp`**。H5 通过它调用存储、鉴权、系统 UI、设备能力等；**路由与页面结构由前端实现**，本壳不提供原生顶栏或底部 Tab。**系统 UI 默认即为 edge-to-edge（京东式叠字）**，仅在看视频等场景需要时再调用 **`SetImmersive(true)`**。

---

## 阅读指引

| 角色 | 建议阅读 |
|------|----------|
| **H5 / 前端** | [快速参考](#快速参考) → [调用约定](#23-调用约定) → [API 参考](#4-api-参考) → [**§4.7 扩展能力使用明细**](#47-扩展能力使用明细) → [示例](#5-示例) |
| **Flutter / 壳维护** | [应用壳与启动](#1-应用壳与启动配置) → [桥接机制](#2-桥接机制) → [本壳行为差异](#3-本壳中的行为差异) → [附录](#8-附录) |

---

## 目录

1. [应用壳与启动配置](#1-应用壳与启动配置)
2. [桥接机制](#2-桥接机制)
3. [本壳中的行为差异](#3-本壳中的行为差异)
4. [API 参考](#4-api-参考)（含 [§4.7 扩展能力使用明细](#47-扩展能力使用明细)）
5. [示例](#5-示例)
6. [错误与调试](#6-错误与调试)
7. [权限与平台](#7-权限与平台)
8. [附录](#8-附录)

---

## 快速参考

全局对象：**`window.MobileApp`**，子命名空间包括 **`Window`**、**`Auth`**、**`Navigation`**、**`NavigationBar`**、**`Services.*`**。所有方法返回 **`Promise`**（成功 `resolve`，失败 `reject(Error)`）。

| 命名空间 | 作用 |
|----------|------|
| **`MobileApp.Window`** | **`SetImmersive`**（京东式 / 沉浸）与 **`SetChromeBackgroundColor`**（见 §1.1、§4.2） |
| **`MobileApp.Auth`** | `access_token` 与原生 `SharedPreferences` 同步 |
| **`MobileApp.Navigation`** | 回到 H5 入口 URL（`GoHome`） |
| **`MobileApp.NavigationBar`** | Material AppBar（本壳未接 setter，见 §3） |
| **`MobileApp.Services.*`** | 存储、Toast、外链、定位（含持续上报）、通讯录、扫码、文件、生物识别、设备、推送、应用名、分享、剪贴板、网络、相册/相机、相册保存、拨号/短信、日历、NFC、蓝牙扫描、系统设置 |

**默认**：`SystemUiMode.edgeToEdge`，与 **`SetImmersive(false)`** 一致；未调用 `SetImmersive` 即为此模式。  
常用示例：`MobileApp.Window.SetChromeBackgroundColor('#1677FF')`、`MobileApp.Auth.GetAccessToken()`；全屏结束：`SetImmersive(false)`。

---

## 1. 应用壳与启动配置

### 1.1 壳形态

**默认采用 edge-to-edge**：`main.dart` 与进入 **`SplashPage`** 时即 **`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`**，且 **`_immersiveChrome == false`**，与 **`SetImmersive(false)`** 行为一致；H5 **不必**为默认模式显式调用 `SetImmersive(false)`。

| 项目 | 说明 |
|------|------|
| 入口 | 拉取 `/v1/app` 后，在 **`SplashPage`** 内用 **`AppWebShell`** 加载 H5 **`url`** |
| 系统 UI（两种，**非三种**） | H5 调用 **`MobileApp.Window.SetImmersive(enabled)`** 切换。**沉浸**与**全屏**在实现上同属一类（`immersiveSticky`，隐藏系统栏），与 **edge-to-edge** 并列，共 **两种** 模式，见下表 |
| 衬色 | 决定 **`Scaffold` / WebView 底层背景色**；在 **京东式** 下还驱动 **状态栏/导航栏图标明暗**；可由接口、dart-define 或 **`SetChromeBackgroundColor`**（§4.2） |
| H5 避让 | **京东式**下可点击区需 **`env(safe-area-inset-top)`** 等；**沉浸**下四边贴屏，按全屏页处理 |
| 过度滚动 | 原生 **`WebViewOverScrollMode.never`** + 页面 **`overscroll-behavior: none`** |

**`SetImmersive` 与 `SystemUiMode`**

| `enabled` | 模式（文档称呼） | `SystemUiMode` | 状态栏时间/电量 | `SafeArea`（壳层） |
|-------------|------------------|----------------|-----------------|---------------------|
| **`false`**（默认） | **京东式 edge-to-edge** | `edgeToEdge` | **显示**（透明叠在内容上） | 顶 **不**包；左右底 **包**（刘海 / Home 条） |
| **`true`** | **沉浸 / 全屏**（同一路径） | `immersiveSticky` | **隐藏**（边缘滑出可暂显） | **四边不包** |

### 1.2 `/v1/app` JSON（与壳相关）

| 字段 | 类型 | 说明 |
|------|------|------|
| **`url`** | string | **必填**，H5 入口（绝对 URL 或相对当前服务 base） |
| **`is_enable`** | boolean | 必须为 `true`，否则启动失败 |
| **`jpush_app_key`** | string | 可选，极光 AppKey |
| **`top_background_color`** | string | 可选，铬区十六进制色（`#RGB` / `#RRGGBB` / `#AARRGGBB`，`#` 可省略） |

### 1.3 本地默认衬色

- 构建：`--dart-define=APP_TOP_BACKGROUND_COLOR=RRGGBB`（与 `lib/app_branding.dart` 中 **`kTopBackgroundColorDefine`** 一致，默认 `000000`）。
- 优先级：**接口 `top_background_color`** → **dart-define** → **黑色**。

### 1.4 登录态与 WebView

- 原生 **`SharedPreferences`** 键 **`access_token`** 与 H5 **`localStorage.access_token`** 配合。
- 若本地 token 存在且 **`/v1/user`** 校验通过，壳在 WebView 就绪后会注入 `localStorage`（与 `Auth` 键一致）。

---

## 2. 桥接机制

### 2.1 通信方式

- H5 经 JS 通道 **`AppBridge`** 向 Flutter 发送 JSON：**`{ v, id, ns, method, args }`**。
- Flutter **`AppJsBridge`** 按 **`ns`** / **`method`** 分发，通过 **`window.__appBridgeDeliver`** 将结果写回对应 Promise。

### 2.2 注入时机

- 注入在 **`NavigationDelegate.onPageFinished`** 之后执行，**`DOMContentLoaded` 时可能尚无 `MobileApp`**。
- 请在 **`load` 或首屏脚本靠后**、或 **用户交互** 中调用，并对 **`window.MobileApp` 做判空**。

### 2.3 调用约定

- 字符串参数在注入层多会 **`String(...)`**；对象须为可 JSON 序列化的普通 Object。
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

### 2.4 接入条件与源码位置

**接入条件**：使用 **`AppWebShell`** 且传入 **`bridge: AppJsBridge(...)`**，并完成 **`registerChannel`**、**`injectBootstrap`**（由壳在适当时机调用）。**未传 `bridge` 时 `window.MobileApp` 不存在。**

| 内容 | 路径 |
|------|------|
| 注入的 JS（`MobileApp` 定义） | `lib/services/app_js_bridge.dart` → `_bootstrap` |
| 分发与实现 | 同文件 → `_dispatch`、各 `_xxxDispatch` |
| WebView 封装 | `lib/widgets/app_web_shell.dart` |
| 十六进制颜色解析 | `lib/utils/hex_color.dart` |

---

## 3. 本壳中的行为差异

| 能力 | 表现 |
|------|------|
| **`MobileApp.Window.*`** | **已接**：**`SetImmersive`**、**`SetChromeBackgroundColor`**（见 §1.1、§4.2） |
| **`MobileApp.Navigation.GoHome`** | **已接**：在当前 WebView 内 **`loadRequest`** 入口 **`url`**，并视情况维护 token |
| **`MobileApp.NavigationBar.*`** | **未接 setter**：调用仍 **`resolve(true)`**，**无原生顶栏 UI**（保留 API 供复用） |
| **`MobileApp.Services.*` / `Auth`** | **已接**（有 bridge 即可） |
| **`ToastService.Show`** | 依赖 `SnackBar`；Flutter 侧已 **dispose** 时可能静默不展示 |
| **左缘右滑 / 系统返回** | **`AppWebShell`** 左缘窄条内快滑可触发 WebView **`goBack`**（见构造参数 **`edgeSwipeWebBack`**）。**Android 全面屏自左缘右滑返回**与**实体返回键**由 **`SplashPage`** 的 **`PopScope`** 拦截：有 Web 历史则 **`goBack`**，否则 **`SystemNavigator.pop`** 退出应用。请在 **`MainActivity`** 上设置 **`android:enableOnBackInvokedCallback="true"`**（本工程已加），否则系统可能不把边缘返回交给 Flutter。纯前端路由（如 **`history.pushState`**）若未触发整页导航，**`canGoBack`** 可能一直为 false，此时仍会退出应用。 |

---

## 4. API 参考

### 4.1 命名空间总览

| 命名空间 | 作用 |
|----------|------|
| **`Window`** | **`SetImmersive`** 切换京东式 / 沉浸；**`SetChromeBackgroundColor`** 衬色与图标对比度 |
| **`Auth`** | `access_token` 读写 |
| **`Navigation`** | 回到 H5 入口地址 |
| **`NavigationBar`** | 原生 AppBar（本壳未使用） |
| **`Services.*`** | 见下表 |

### 4.2 `MobileApp.Window`

#### `SetImmersive(enabled)`

启动时**默认已是 edge-to-edge**，一般**无需**先调 `SetImmersive(false)`；在曾调用 `SetImmersive(true)` 后需要恢复京东式时再调 **`false`**。

| 项目 | 说明 |
|------|------|
| **签名** | `SetImmersive(enabled: boolean)` |
| **返回值** | `Promise<true>` |
| **`false`** | **京东式 edge-to-edge**：`SystemUiMode.edgeToEdge`，状态栏叠字，见 §1.1 表 |
| **`true`** | **沉浸 / 全屏**：`SystemUiMode.immersiveSticky`，隐藏系统栏，WebView 四边贴屏 |

```javascript
await MobileApp.Window.SetImmersive(true);  // 视频等全屏
await MobileApp.Window.SetImmersive(false); // 恢复京东式 / edge-to-edge
```

#### `SetChromeBackgroundColor(color)`

在 **`SetImmersive(false)`** 下：更新 **`Scaffold`、WebView 底层背景** 与 **状态栏/导航栏图标明暗**（栏为 **透明**）。**沉浸**下系统栏已隐藏，仍更新 WebView/脚手架底色。

| 项目 | 说明 |
|------|------|
| **签名** | `SetChromeBackgroundColor(color: string)` |
| **返回值** | `Promise<true>` |
| **合法 `color`** | `#RGB`、`#RRGGBB`、`#AARRGGBB`，`#` 可省略 |
| **`''` 或仅空白** | **清除**桥接覆盖，恢复启动默认（§1.2 / §1.3） |
| **非法字符串** | **reject**（Dart：`无效的 color...`） |

```javascript
await MobileApp.Window.SetChromeBackgroundColor('#1677FF');
await MobileApp.Window.SetChromeBackgroundColor('');
```

### 4.3 `MobileApp.Auth`

与原生 **`SharedPreferences`** 同步键名 **`access_token`**。

| 方法 | 参数 | 返回值 |
|------|------|--------|
| **`SetAccessToken(token)`** | 字符串（空串也会写入） | `Promise<true>` |
| **`GetAccessToken()`** | — | `Promise<string \| null>` |
| **`ClearAccessToken()`** | — | `Promise<true>` |

### 4.4 `MobileApp.Navigation`

#### `GoHome()`

| 项目 | 说明 |
|------|------|
| **返回值** | `Promise<true>` |
| **行为** | 在当前 WebView 加载 **`/v1/app` 返回的入口 `url`** |
| **未配置处理器** | **reject**（`未配置 GoHome 处理器`）——本工程 **SplashPage 已配置** |

单页应用内「回首页」可用前端路由；需整页重载入口时再调 **`GoHome()`**。

### 4.5 `MobileApp.NavigationBar`

控制 **Material AppBar**。**当前全屏 Web 壳未注册 setter**，下列调用 **不改变界面**，多数仍 **`Promise<true>`**（参数非法时可能 reject）：

- `Show()` / `Hide()` → `setVisible`
- `SetTitle(title)`
- `SetStyle(style)` — `style` 为对象，常用键：`title`、`backgroundColor`、`foregroundColor`、`fontSize`、`fontWeight`
- `SetButtons({ back?, scan? })` — 仅显式传入的 `boolean` 键生效

### 4.6 `MobileApp.Services.*`

#### 4.6.1 服务与方法总表

| 服务 | 方法 | 返回值要点 |
|------|------|------------|
| **StorageService** | `Get` / `Set` / `Remove` / `Keys` / `Clear` | 与 Auth 不同命名空间；**空 `key` 会 reject** |
| **ToastService** | `Show(message)` | `Promise<null>` |
| **LauncherService** | `OpenUrl(url)` | `Promise<true>` |
| **LocationService** | `Get()` | `Promise<object>`，需定位权限 |
| | `StartWatch(opts?)` / `StopWatch()` | 持续定位；需在页面设置 **`MobileApp.onLocationUpdate`**；见 §4.6.4 |
| **GalleryService** | `SaveImageFromPath` / `SaveImageFromBase64` | 写入系统相册；需授权；见 §4.6.4 |
| **TelephonyService** | `Dial(phone)` / `SendSms(phone, body?)` | 调起系统拨号/短信 |
| **CalendarService** | `AddEvent(obj)` | `title`、`startMs`、`endMs` 等；打开系统日历写入；见 §4.6.4 |
| **NfcService** | `GetAvailability` / `ReadNdef(timeoutSec?)` / `ReadTransitPublic(timeoutSec?)` | **仅部分设备**；iOS 需在 Xcode 配置 NFC 能力；见 §4.6.4 |
| **BluetoothService** | `GetStatus` / `Scan(timeoutSec?)` | 短时扫描广播；**非**持续连接；见 §4.6.4 |
| **ContactsService** | `List(limit?)` | 默认 `limit=50`，需读权限；见 §4.6.2 |
| | `Save(data)` | 新建联系人，需读写权限；返回新联系人 **`id`（字符串）**；见 §4.6.2 |
| | `Pick()` | 系统通讯录选择器；**仅 Android / iOS**；见 §4.6.2 |
| **QrService** | `Scan()` | `Promise<{ text: string }>`，需相机 |
| **FileService** | `PickFile` | `Promise<{ name, path, size }>`，取消等会 **reject** |
| | `ReadText` / `WriteText` / `Delete` / `ListDir` / `GetAppDir` | `path` 必填；`WriteText`/`Delete` 成功 `true`；`GetAppDir` → `{ documents }` |
| **BiometricService** | `IsSupported` / `Authenticate(reason?)` / `GetAvailableBiometrics` | 见方法名 |
| **DeviceService** | `GetInfo()` | `Promise<object>` |
| **PushService** | `GetRegistrationId()` | `Promise<string \| null>`，极光 RID |
| **AppService** | `GetInfo()` | `Promise<{ displayName: string }>` |
| **ShareService** | `ShareText(text, subject?)` / `ShareUri(url)` | `Promise<true>` |
| **ClipboardService** | `SetText` / `GetText` | 纯文本 |
| **NetworkService** | `GetStatus()` | `{ types: string[], hasNetwork: boolean }`（**不保证能上公网**） |
| **MediaService** | `PickFromGallery` / `TakePhoto` | `Promise<string \| null>` 本地路径 |
| **SettingsService** | `OpenAppSettings()` | `Promise<true>` |

#### 4.6.2 WebView `<input type="file">`（Android）

- **Android**：壳在 `AppWebShell` 内已为 WebView 注册文件选择；表单单选/多选、常见 `accept`（图/视频/任意）会调起 **`file_picker` / 相机**。
- **iOS**：由 WKWebView 默认处理，一般无需额外桥接。

#### 4.6.3 `ContactsService`

**`List(limit?)`**

- 返回 **`Array`**，每项为同一结构（与 **`Pick`** 选中项一致）：
  - **`id`**：字符串
  - **`displayName`**：字符串
  - **`phones`**：号码字符串数组
  - **`emails`**：邮箱字符串数组

**`Save(data)`**

- **`data`** 为对象，字段：
  - **`displayName`**（可选）
  - **`phones`**、**`emails`**：字符串数组；**至少一类含非空项**，否则 reject
- 需通讯录 **读写** 权限。

**`Pick()`**

- 弹出**系统通讯录选择器**；用户取消返回 **`null`**；选中则返回与 **`List`** 单项相同结构。
- **仅 Android / iOS**；其它平台 **reject**。

#### 4.6.4 持续定位、相册、日历、NFC、蓝牙（概要）

以下能力**参数、返回值、平台差异的完整明细**见 **[§4.7](#47-扩展能力使用明细)**。

- **持续定位**：`LocationService.StartWatch` / `StopWatch`，需 **`MobileApp.onLocationUpdate`**。
- **相册**：`GalleryService.SaveImageFromPath` / `SaveImageFromBase64`。
- **日历**：`CalendarService.AddEvent`（系统日历写入，非系统闹钟 API）。
- **NFC**：`NfcService.GetAvailability` / `ReadNdef` / `ReadTransitPublic`。
- **蓝牙**：`BluetoothService.GetStatus` / `Scan`（仅扫描，不连接）。

#### 4.6.5 其它说明（节选）

- **Storage**：空 `key` **reject**。
- **FileService**：`PickFile` 用户取消 → **reject**；`ListDir` 项含 `path`、`type`、`size`、`modified`（毫秒时间戳）。
- **ShareText**：`subject` 省略或空则无主题。

### 4.7 扩展能力使用明细

以下均为 **`async`**：成功 **`resolve`**，失败 **`reject(Error)`**（与 §2.3 一致）。调用前建议 **`if (!window.MobileApp) return`**。

#### 4.7.1 WebView 内 `<input type="file">`（非 `MobileApp` 方法）

| 项目 | 说明 |
|------|------|
| **是否调桥** | **否**。页面写标准 HTML 即可。 |
| **Android** | 壳已注册 `onShowFileChooser`：`accept` 为图片/视频/混合时分别调相册或文件选择；带 **`capture`** 且为图片时优先调相机。支持 **`multiple`** 多选。 |
| **iOS** | 由 **WKWebView** 系统行为处理，一般直接出相册/文件。 |
| **用户取消** | 不更新 `input.files` 或等价于未选文件（与浏览器一致）。 |
| **路径注意** | 选中文件路径仅在原生侧有效；若需上传请用 `FormData` / 你们服务端直传，勿假设 H5 能任意读磁盘路径。 |

#### 4.7.2 `LocationService`（单次 + 持续）

**`Get()`**

| 项目 | 说明 |
|------|------|
| **签名** | `Get()` |
| **成功返回值** | 对象，字段均为数值（除 `timestamp` 为整数毫秒）： **`latitude`**、**`longitude`**、**`accuracy`**、**`altitude`**、**`heading`**、**`speed`**、**`timestamp`** |
| **权限** | 定位权限；定位服务需开启。 |

**`StartWatch(opts?)`**

| 参数（`opts` 内） | 类型 | 默认 | 说明 |
|------------------|------|------|------|
| **`distanceFilterM`** | number | `0` | 位移超过该米数才可能触发新点；`0` 表示不按距离过滤（仍受系统与 `intervalSec` 影响）。 |
| **`intervalSec`** | number | `2` | Android 上为位置更新间隔量级（秒，范围在原生侧会限制在合理区间）；iOS 无完全等同间隔，以系统为准。 |
| **`foregroundService`** | boolean | `false` | **仅 Android**：`true` 时在后台更易保持连续定位（**前台服务 + 通知**）；需通知权限等。 |

| 项目 | 说明 |
|------|------|
| **前置条件** | 必须先赋值 **`MobileApp.onLocationUpdate = function (pos) { ... }`**。`pos` 与 **`Get()`** 返回结构相同。未赋值则原生仍会推数据，但页面收不到。 |
| **成功返回值** | `Promise<true>` |
| **重复调用** | 再次 **`StartWatch`** 会**取消**上一次订阅，仅保留最新一次。 |
| **`StopWatch()`** | `Promise<true>`，取消订阅，不再触发 **`onLocationUpdate`**。 |

#### 4.7.3 `GalleryService`

| 方法 | 参数 | 成功返回值 | 说明 |
|------|------|------------|------|
| **`SaveImageFromPath`** | **`path`**：字符串，本地绝对路径 | `true` | 文件须存在；会先请求相册写入权限。 |
| **`SaveImageFromBase64`** | **`base64`**：字符串（可含换行/空白，会去掉）；**`name`**：可选，文件名（无扩展名），默认 **`image`** | `true` | 内容为图片的 Base64；非法数据可能 reject。 |

#### 4.7.4 `TelephonyService`

| 方法 | 参数 | 成功返回值 | 说明 |
|------|------|------------|------|
| **`Dial`** | **`phone`**：号码字符串（可含空格等，由系统解析） | `true` | 调起系统**拨号界面**（一般为 `tel:`）。 |
| **`SendSms`** | **`phone`**：号码；**`body`**：可选，短信正文 | `true` | 调起系统**短信应用**（`sms:`）；是否预填正文依赖系统。 |

#### 4.7.5 `CalendarService.AddEvent`

参数为**一个对象**（与 `call('calendar', 'addEvent', o)` 一致）：

| 字段 | 必填 | 类型 | 说明 |
|------|------|------|------|
| **`title`** | 是 | string | 事件标题；纯空白会 reject。 |
| **`startMs`** | 是 | number | 开始时间 **Unix 毫秒**时间戳。 |
| **`endMs`** | 是 | number | 结束时间 **Unix 毫秒**；须 **大于** `startMs`。 |
| **`description`** | 否 | string | 描述。 |
| **`location`** | 否 | string | 地点。 |
| **`allDay`** | 否 | boolean | 是否全天；默认 `false`。 |

| 项目 | 说明 |
|------|------|
| **成功返回值** | `Promise<boolean>`：用户完成系统日历流程后为 `true`，否则可能为 `false`（依插件/系统）。 |
| **与「提醒」关系** | 写入的是**日历事件**；系统是否弹出提醒取决于用户在日历 App 中的设置，**不是**独立闹钟 API。 |

#### 4.7.6 `NfcService`

**`GetAvailability()`**

| 成功返回值 | 说明 |
|------------|------|
| **`{ status: string }`** | **`status`** 取值：**`enabled`**（可用）、**`disabled`**（有硬件但关闭）、**`unsupported`**（不支持）。 |

**`ReadNdef(timeoutSec?)`**

| 参数 | 默认 | 说明 |
|------|------|------|
| **`timeoutSec`** | `30` | 等待贴卡秒数，建议在 **5–120** 内。 |

| 成功返回值 | 说明 |
|------------|------|
| **`{ records: Array }`** | 每条：**`tnf`**（字符串，如 `wellKnown`）、**`typeBase64`**、**`payloadBase64`** 均为 Base64；需自行解码解析 NDEF。 |
| **失败** | 超时、非 NDEF 标签、用户取消会话等会 **reject**。 |

**`ReadTransitPublic(timeoutSec?)`**

| 参数 | 默认 | 说明 |
|------|------|------|
| **`timeoutSec`** | `20` | 等待贴卡秒数，建议在 **5–60** 内。 |

| 成功返回值 | 说明 |
|------------|------|
| **`{ uidHex, techList, isNdef, isoDep?, nfcA?, nfcB? }`** | 读取公交/门禁等**公开可读基础信息**：`uidHex`（卡号十六进制，可能为空）、`techList`（识别到的技术栈）、`isNdef`（是否支持 NDEF）。若存在对应层，还会返回 `isoDep`、`nfcA`、`nfcB` 的公开字段（Base64/Hex）。 |
| **失败** | 超时、用户取消会话、设备不支持 NFC 等会 **reject**。 |

> 说明：`ReadTransitPublic` 仅返回公开层数据，不包含私有扇区读写、复制或模拟能力。

**iOS**：除 **`NFCReaderUsageDescription`** 外，须在 **Xcode** 开启 **NFC** 能力与 **entitlements**（如 Tag Reading），否则无法读卡。

#### 4.7.7 `BluetoothService`

**`GetStatus()`**

| 成功返回值字段 | 说明 |
|----------------|------|
| **`supported`** | boolean，硬件/栈是否支持。 |
| **`adapterState`** | string，如 **`on`**、**`off`**、**`turningOn`**、**`turningOff`**、**`unsupported`** 等（与 `flutter_blue_plus` 一致）。 |

**`Scan(timeoutSec?)`**

| 参数 | 默认 | 说明 |
|------|------|------|
| **`timeoutSec`** | `8` | 扫描持续时间秒数，原生限制在 **1–30**。 |

| 成功返回值 | 说明 |
|------------|------|
| **`Array`** | 每项：**`id`**（设备地址字符串）、**`name`**（广播名或平台名，可能为空串）、**`rssi`**（信号强度）。 |
| **范围** | **仅扫描**，不连接、不读 GATT 特征；若要 BLE 读写需另扩桥接/原生。 |

**平台**：**仅 Android / iOS**；桌面等会 **reject**。

---

## 5. 示例

### 5.1 保存 token 并回到壳配置的 H5 根地址

```javascript
await MobileApp.Auth.SetAccessToken(token);
await MobileApp.Navigation.GoHome();
```

### 5.2 沉浸全屏后再恢复京东式

```javascript
await MobileApp.Window.SetImmersive(true);
// …
await MobileApp.Window.SetImmersive(false);
```

### 5.3 随路由切换衬色与图标对比度（京东式下）

```javascript
await MobileApp.Window.SetChromeBackgroundColor('#1a1a2e');
await MobileApp.Window.SetChromeBackgroundColor('');
```

### 5.4 分享、网络、剪贴板、相册、推送

```javascript
await MobileApp.Services.ShareService.ShareText('正文', '标题');
const { types, hasNetwork } = await MobileApp.Services.NetworkService.GetStatus();
await MobileApp.Services.ClipboardService.SetText('hello');
const path = await MobileApp.Services.MediaService.PickFromGallery();
const rid = await MobileApp.Services.PushService.GetRegistrationId();
```

### 5.5 持续定位、保存图片、拨号、日历

```javascript
MobileApp.onLocationUpdate = function (pos) {
  console.log(pos.latitude, pos.longitude, pos.timestamp);
};
await MobileApp.Services.LocationService.StartWatch({
  intervalSec: 3,
  distanceFilterM: 10,
  foregroundService: true,
});
// await MobileApp.Services.LocationService.StopWatch();

await MobileApp.Services.GalleryService.SaveImageFromPath('/path/from/camera.jpg');
await MobileApp.Services.TelephonyService.Dial('10086');
await MobileApp.Services.TelephonyService.SendSms('10086', '查询');
await MobileApp.Services.CalendarService.AddEvent({
  title: '会议',
  startMs: Date.now(),
  endMs: Date.now() + 3600000,
});
```

### 5.6 NFC、蓝牙（与 §4.7.6、§4.7.7 对应）

```javascript
const { status } = await MobileApp.Services.NfcService.GetAvailability();
if (status === 'enabled') {
  const data = await MobileApp.Services.NfcService.ReadNdef(25);
  console.log(data.records);
  const pub = await MobileApp.Services.NfcService.ReadTransitPublic(20);
  console.log(pub.uidHex, pub.techList);
}

const bt = await MobileApp.Services.BluetoothService.GetStatus();
if (bt.supported && bt.adapterState === 'on') {
  const devices = await MobileApp.Services.BluetoothService.Scan(10);
  console.log(devices);
}
```

### 5.7 通讯录：列表、保存、系统选择器

```javascript
const list = await MobileApp.Services.ContactsService.List(30);
const newId = await MobileApp.Services.ContactsService.Save({
  displayName: '张三',
  phones: ['13800138000'],
  emails: [],
});
const picked = await MobileApp.Services.ContactsService.Pick();
if (picked) console.log(picked.id, picked.phones);
```

---

## 6. 错误与调试

- Flutter 日志关键字：`AppJsBridge inject failed`、`AppJsBridge reply failed`。
- **`MobileApp === undefined`**：当前页是否使用带 **`bridge`** 的 **`AppWebShell`**，且主文档 **`onPageFinished`** 已执行。

---

## 7. 权限与平台

- 定位、通讯录、相机、生物识别、**相册写入**、**日历**、**蓝牙**、**NFC** 等需在系统中授权；拒绝后对应接口 **reject**。
- **iOS**：`Info.plist` 中 `NS*UsageDescription`；**NFC** 另需在 Xcode 开启能力与 entitlements。
- **Android**：`AndroidManifest.xml` 以工程为准（含前台定位服务、蓝牙扫描/连接、日历、NFC 等声明）。
- **桌面 / Web**：部分能力不可用或行为不同；本项目主要面向 **iOS / Android**。

---

## 8. 附录

### 8.1 与源码的对应关系

| 文档概念 | 代码 |
|----------|------|
| JS 助手对象 | `lib/services/app_js_bridge.dart` → `_bootstrap` |
| 分发 | `_dispatch`、`_windowDispatch`、`_authDispatch` 等 |
| WebView | `lib/widgets/app_web_shell.dart`；文件选择 `lib/services/webview_file_picker.dart` |
| 启动与铬区 | `lib/pages/splash_page.dart` |
| 配置拉取 | `lib/services/app_bootstrap_service.dart` |

### 8.2 文档维护

接口增减或壳行为变更时，请同步更新本文件与 **`app_js_bridge.dart`** 顶部文档注释。

### 8.3 按站点构建（应用名与启动图标）

在 **`app/`** 目录执行脚本：请求 **`{service}api/{code}/v1/site`**，用返回的 **`name`** 作为 **`APP_DISPLAY_NAME`**，将 **`icon`** 下载到 `assets/brand/launcher_source.png` 后执行 **`flutter_launcher_icons`**，再执行 **`flutter build`**。

**四个参数均为必填**（无默认域名），详见 **`BUILD.md`**：

```bash
dart run tool/build_with_site.dart \
  --service=http://host:6002/ \
  --external-server=http://host:6002 \
  --internal-server=http://host:6002 \
  --code=code \
  build apk --release
```

- **`--service`**：站点根 URL（可带末尾 `/`），用于拉站点名与图标。
- **`--external-server` / `--internal-server`**：编译注入 `APP_EXTERNAL_SERVER_URL` / `APP_INTERNAL_SERVER_URL`。
- **`--code`**：租户 code，编译注入 `APP_CODE`。
- **后续参数**：传给 `flutter`；省略时默认为 `build apk --release`。

Windows 快捷方式：`build.bat <SERVICE> <外网> <内网> <CODE>`。

构建机需能访问上述 URL；图标可为 PNG 或 SVG（CI/本机需 `rsvg-convert` 或 ImageMagick）。
