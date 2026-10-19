# 构建说明（必须显式指定环境参数）

所有 **正式构建** 与 **本地运行脚本** 都必须传入以下 4 项，**脚本内不再写死任何客户域名**。

| 参数 | 含义 | 编译常量 |
|------|------|----------|
| **站点 SERVICE URL** | 拉 `/api/{code}/v1/site`（应用名、图标） | — |
| **外网 API** | 运行时优先请求的后端基址 | `APP_EXTERNAL_SERVER_URL` |
| **内网 API** | 外网失败时的备用基址 | `APP_INTERNAL_SERVER_URL` |
| **APP_CODE** | 租户/站点 code | `APP_CODE` |

应用名 `APP_DISPLAY_NAME` 由站点接口 `name` 字段自动注入，无需手填。

---

## Windows：构建 APK

```bat
cd app
build.bat <SERVICE_URL> <外网API> <内网API> <APP_CODE>
```

示例：

```bat
build.bat http://crm.procode.cn:6002/ http://crm.procode.cn:6002 http://crm.procode.cn:6002 code
```

---

## Windows：本地运行（Windows 桌面 / Chrome）

```bat
run-windows.bat <外网API> <内网API> <APP_CODE>
run-chrome.bat  <外网API> <内网API> <APP_CODE>
```

`SERVICE_URL` 仅构建时需要；本地 `flutter run` 只需 API 与 code。

---

## Mac：构建 iOS

```bash
cd app
chmod +x build-ios.sh
./build-ios.sh <SERVICE_URL> <外网API> <内网API> <APP_CODE>
```

---

## 直接调用构建工具

```bash
dart run tool/build_with_site.dart \
  --service=http://host:6002/ \
  --external-server=http://host:6002 \
  --internal-server=http://host:6002 \
  --code=code \
  build apk --release
```

---

## GitHub Actions

手动运行各 Workflow 时 **必须填写** 4 个输入项（无默认域名）：

- `service_url`
- `external_server_url`
- `internal_server_url`
- `app_code`
