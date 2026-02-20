---
allowed-tools: Bash, Read, Edit
description: 发版 - 更新版本号、打 tag、推送到远程
---

用户准备发布一个新版本。

## 步骤

### 1. 前置检查

```bash
git branch --show-current
git status --porcelain
```

- 必须在 `main` 分支上。如果不是，告诉用户先切到 main。
- 必须没有未提交变更。如果有，告诉用户先提交。

### 2. 获取版本信息

```bash
git tag -l 'v*' --sort=-v:refname | head -5
```

显示最近的 tag，让用户知道当前版本。

读取当前版本号：

```bash
# 从 package.json 和 Cargo.toml 获取当前版本
```

读取 `package.json` 中的 `version` 字段和 `src-tauri/Cargo.toml` 中的 `version` 字段。

### 3. 确定新版本

根据用户参数 `$ARGUMENTS` 决定：

- 如果用户提供了版本号（如 `0.2.0`），使用该版本号
- 如果参数为 `patch`、`minor`、`major`，自动递增对应位
- 如果参数为空，展示当前版本并问用户想要哪个版本（patch/minor/major）

版本号示例（假设当前 v0.1.0）：
- patch → v0.1.1
- minor → v0.2.0
- major → v1.0.0

### 4. 更新版本号

同步更新以下文件中的 version 字段：
- `package.json` — `"version": "x.y.z"`
- `src-tauri/Cargo.toml` — `version = "x.y.z"`
- `src-tauri/tauri.conf.json` — `"version": "x.y.z"`（如果存在）

使用 Edit 工具精准替换，不要改动其他内容。

### 5. 提交版本号变更

```bash
git add package.json src-tauri/Cargo.toml src-tauri/tauri.conf.json
git commit -m "$(cat <<'EOF'
🔖 release: v<新版本号>
EOF
)"
```

### 6. 打 tag

```bash
git tag -a v<新版本号> -m "<用户提供的描述，或自动生成的摘要>"
```

如果用户没有提供描述，自动从上一个 tag 到现在的 commit log 生成摘要：

```bash
git log <上一个tag>..HEAD --oneline
```

### 7. 推送

```bash
git push origin main
git push origin v<新版本号>
```

### 8. 输出

```
🚀 发版完成！
📦 版本：v<新版本号>
🏷️ Tag：v<新版本号>
📋 变更摘要：
   - <commit 1>
   - <commit 2>
   - ...
👉 如需创建 GitHub Release：gh release create v<新版本号> --generate-notes
```
