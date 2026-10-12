# 公开 GitHub 仓库 + Actions 构建

当前代码默认远程在 **阿里云 Codeup**。要在 **GitHub 公开仓库** 里免费用官方 runner 构建，按下面做即可。

## 1. 在 GitHub 新建公开仓库

1. 打开 https://github.com/new  
2. **Repository name**：例如 `ProCode-App`  
3. 选择 **Public**  
4. **不要**勾选 “Add a README”（避免和本地冲突）  
5. Create repository  

## 2. 把本地代码推到 GitHub（保留 Codeup 远程）

在 `C:\Works\Code\App` 执行（把 `YOUR_USER` / `YOUR_REPO` 换成你的）：

```bat
git remote add github https://github.com/procode-xinao/app.git
git add .github
git commit -m "ci: add GitHub Actions for Flutter Android/iOS builds"
git push -u github master
```

若 GitHub 默认分支是 `main`：

```bat
git push -u github master:main
```

## 3. 运行构建

1. 打开 GitHub 仓库 → **Actions**  
2. 左侧选 **Flutter Build**  
3. **Run workflow**（可改 `service_url` / `app_server_url`，默认已是 crm.procode.cn）  
4. 跑完后在 **Summary → Artifacts** 下载：  
   - `app-release-apk`：Android APK  
   - `ios-runner-app`：未签名的 iOS `.app`（上架需 Apple 证书 + Xcode Archive）

## 4. 费用说明（公开仓库）

- 使用 **GitHub 官方 hosted runner** 构建 **公开仓库** 时，标准 Actions 用量 **免费**。  
- 构建机需能访问：`crm.procode.cn:6002`、`storage.procode.cn`（拉站点与图标）。

## 5. iOS IPA（签名）

- 未签名调试包：**Flutter iOS Build** → `ios-runner-app`
- **签名 IPA**：见 **[IOS_SIGNING_SETUP.md](./IOS_SIGNING_SETUP.md)**，运行 **Flutter iOS IPA (Signed)** → 下载 `ios-signed-ipa`
