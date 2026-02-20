---
allowed-tools: Bash
description: 开始新功能 - 从 main 创建 feature 分支
---

用户想要开始开发一个新功能。根据用户提供的参数 `$ARGUMENTS` 创建 feature 分支。

## 步骤

### 1. 解析参数

`$ARGUMENTS` 是功能名称，例如 `mermaid-support`、`dark-mode`。

- 如果参数为空，直接问用户要功能名称，不要猜测。
- 分支名格式：`feat/<功能名>`（使用用户提供的原始名称，不要修改）

### 2. 前置检查

```bash
git status --porcelain
```

如果有未提交的变更，提醒用户先提交或 stash，**不要自动处理**。

### 3. 创建分支

```bash
git checkout main
git pull origin main
git checkout -b feat/<功能名>
```

### 4. 输出

```
🌿 已创建分支：feat/<功能名>
📍 基于：main (<hash>)
👉 现在可以开始开发了，完成后用 /done 合回 main
```
