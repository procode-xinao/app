# 构建说明

只需指定 **服务根地址**（API 基址），其余在构建时通过接口拼接获取。

## 必填

| 参数 | 说明 |
|------|------|
| **`--service=`** / **`SERVICE_URL`** | 服务根 URL，如 `http://host:6002/` |

## 可选

| 参数 | 说明 |
|------|------|
| **`--code=`** / 第二参数 | 租户 code，默认 `code`；若 `/v1/site` 返回 `code` 且未指定则采用接口值 |

## 构建时自动请求

1. **`GET {service}/api/{code}/v1/site`** → 应用名、图标 → `APP_DISPLAY_NAME`、launcher icons  
2. **`GET {service}/api/{code}/v1/app`** → `jpush_app_key`、`top_background_color` 等 → 对应 `--dart-define`  
3. **`APP_EXTERNAL_SERVER_URL` / `APP_INTERNAL_SERVER_URL`** → 由 `--service` 规范化（去掉末尾 `/`），内外网相同

---

## Windows APK

```bat
cd app
build.bat http://host:6002/
build.bat http://host:6002/ mycode
```

## 本地运行

```bat
run-windows.bat http://host:6002/
run-chrome.bat http://host:6002/
```

## Mac iOS

```bash
./build-ios.sh http://host:6002/
```

## 直接调用

```bash
dart run tool/build_with_site.dart --service=http://host:6002/ build apk --release
```

## GitHub Actions

手动运行 workflow 时填写 **`service_url`**；可选 **`app_code`**（默认 `code`）。
