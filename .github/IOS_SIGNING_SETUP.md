# GitHub Actions 打 iOS IPA（证书 Secrets）

Bundle ID：**`com.procode.app`**（须与 Apple 开发者后台、描述文件一致）

Workflow：**Actions → Flutter iOS IPA (Signed) → Run workflow**

---

## 一、在 Apple 开发者网站准备（需 Mac 或已有证书）

1. 加入 [Apple Developer Program](https://developer.apple.com/programs/)（真机分发 / TestFlight 需付费账号）。
2. **Identifiers** 中创建 App ID：`com.procode.app`（启用 Push 等能力需与 `Runner.entitlements` 一致）。
3. 创建 **证书**（与导出方式对应）：
   - **ad-hoc / app-store**：**Apple Distribution**
   - **development**：**Apple Development**
4. 创建 **Provisioning Profile**（类型与 workflow 里 `export_method` 一致）：
   - **ad-hoc**：Ad Hoc（设备 UDID 需已登记）
   - **development**：iOS App Development
   - **app-store**：App Store Connect
5. 在 Mac 上导出 **`.p12`**（含私钥），下载 **`.mobileprovision`**。

记下 **Team ID**（10 位，Membership 页面）。

---

## 二、转成 Base64（在 Mac 终端）

```bash
base64 -i Certificates.p12 | pbcopy          # 粘贴到 Secret IOS_CERTIFICATE_BASE64
base64 -i profile.mobileprovision | pbcopy # 粘贴到 Secret IOS_PROVISION_PROFILE_BASE64
```

Windows PowerShell：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\cert.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\profile.mobileprovision"))
```

---

## 三、在 GitHub 仓库配置 Secrets

仓库 → **Settings → Secrets and variables → Actions → New repository secret**

| Secret 名称 | 内容 |
|-------------|------|
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `IOS_CERTIFICATE_BASE64` | `.p12` 的 Base64 |
| `IOS_CERTIFICATE_PASSWORD` | 导出 p12 时设置的密码 |
| `IOS_PROVISION_PROFILE_BASE64` | `.mobileprovision` 的 Base64 |
| `KEYCHAIN_PASSWORD` | 任意强随机串（仅 CI 临时钥匙串用） |

---

## 四、运行构建

1. **Actions → Flutter iOS IPA (Signed) → Run workflow**
2. 选择 **export_method**（必须与描述文件类型匹配）
3. 成功后下载 Artifact：**`ios-signed-ipa`**

---

## 五、安装 IPA

| export_method | 安装方式 |
|---------------|----------|
| **ad-hoc** | 设备 UDID 已在描述文件中；用 **Apple Configurator**、**爱思** 等装 `.ipa` |
| **development** | 开发设备 + 开发证书 |
| **app-store** | 需再上传 App Store Connect / TestFlight（本 workflow 只产出 IPA，不自动上传） |

---

## 六、常见问题

- **pod / deployment target**：项目已设为 iOS **15.0**（Flutter 3.47+）。
- **Push**：`Runner.entitlements` 现为 `aps-environment: development`；上架生产推送需改为 `production` 并使用对应描述文件。
- **无 Mac**：可请同事导出 p12 + 描述文件，或租用云 Mac 操作一次，Secrets 配好后日常只需 GitHub 构建。

---

## 七、可选：上传 TestFlight

需额外 Secrets（App Store Connect API Key）：

- `APPSTORE_ISSUER_ID`
- `APPSTORE_KEY_ID`
- `APPSTORE_PRIVATE_KEY`（`.p8` 文件内容）

需要时可再在 workflow 里加 `upload-testflight-build` 步骤。
