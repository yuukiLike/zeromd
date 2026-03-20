---
allowed-tools: Bash, Read
description: 修正个人分支 - 将自己的 commit 作者信息刷新为正确的 git config
---

修正当前个人分支上作者信息不正确的 commit。

## 安全原则

**只修正自己的 commit，绝不覆盖他人的。**

## 步骤 1：确认当前配置

```bash
git config user.name
git config user.email
```

如果 name 或 email 为空，提示用户先设置，然后终止。

## 步骤 2：确定修正范围

找到当前分支相对于 main 的所有 commit：

```bash
git log --format='%h %an <%ae> %s' main..HEAD
```

如果当前分支就是 main，提示用户切到 feature 分支后再执行，然后终止。

## 步骤 3：识别需要修正的 commit

从步骤 2 的 commit 列表中，筛选出：
- **author name 与当前 `git config user.name` 相同**，但 email 不同的 commit

这些是"自己的 commit，但 email 配置错了"。

同时列出：
- author name 与当前配置**不同**的 commit（属于他人）

向用户报告：
```
需要修正的 commit（name 匹配，email 不同）：
  <hash> <old-email> <subject>

不会修改的 commit（其他作者）：
  <hash> <author> <subject>

正确的目标：<name> <<email>>
```

如果没有需要修正的 commit，输出"所有 commit 作者信息已正确，无需修正"并结束。

## 步骤 4：执行修正

使用 `git filter-branch` 或 `git rebase` 只修正步骤 3 筛出的 commit。

推荐方式——用 rebase + exec，只 amend 自己的 commit：

```bash
git rebase main --exec '
if [ "$(git log -1 --format=%an)" = "<CORRECT_NAME>" ] && [ "$(git log -1 --format=%ae)" != "<CORRECT_EMAIL>" ]; then
  git commit --amend --reset-author --no-edit
fi
'
```

其中 `<CORRECT_NAME>` 和 `<CORRECT_EMAIL>` 从步骤 1 获取。

## 步骤 5：验证

```bash
git log --format='%h %an <%ae> %s' main..HEAD
```

确认：
1. 自己的 commit email 已修正
2. 他人的 commit 作者信息未被改动

输出修正摘要：
```
✅ 已修正 N 个 commit 的作者信息
   <hash> <subject>
⏭️ 跳过 M 个其他作者的 commit（未修改）
```
