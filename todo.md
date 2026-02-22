# Todo

> 更新于 2026-02-22

## 当前状态
- 分支：main
- 未提交变更：`hackernews-post.md`（HN 帖子存档，未 commit）
- 最近完成：
  - 重写安装体验：新建 `scripts/setup.sh` 智能安装器（8 阶段幂等），`install-remote.sh` curl 一键入口，`scripts/install.sh` 改为薄包装
  - 修正所有 repo URL 从 anthropics/zeromd → yuukiLike/zeromd
  - Windows 说明从 Quick Start 移至架构图下方（zeromd 不直接支持 Windows）
  - 测试从 15 个增加到 25 个，全部通过
  - 写好 HN Show HN 帖子并已发布（周六凌晨，非最佳时段）
  - 创建了 GitHub profile（yuukiLike/yuukiLike repo）

## 进行中
- [ ] **Mac Mini 实测安装**：在另一台 Mac 上运行 `bash <(curl -sL ...)` 验证完整流程。注意：需要先 `git push origin main` 把最新代码推到 GitHub，否则 curl 会 404。验证点：单 vault 自动发现、gh CLI 自动建 repo、SSH 连通性检测、幂等性（跑两遍第二遍全 skip）

## 下次要做
- [ ] **Push 到 GitHub**：当前本地有两个新 commit 未推送（setup 重写 + URL 修正），必须先 push 才能测试 curl 安装
- [ ] **重发 HN**：首发是周六凌晨（美东下午），流量低。择日在美东周二~周四早 6-9 点（对应 UTC+8 晚 7-10 点）重新提交
- [ ] **继续宣发**：Reddit r/ObsidianMD、r/selfhosted、V2EX、少数派，详细计划见下方"宣发计划"
- [ ] **开发 zeromd-preview**：跨端只读 markdown 浏览器，zeromd vault 专属阅读器

## 代码中的 TODO
- 无

## 备忘
- HN 帖子存档在 `hackernews-post.md`，核心卖点：最 AI 友好的知识库是本地 .md 文件夹，zeromd 只是补上同步这最后一块拼图
- GitHub profile README 存档在 `github-profile-README.md`，记得不要 commit 到 zeromd 仓库
- setup.sh Phase 4（首次 push）失败会 exit 1 中断安装——这是有意为之，push 不通 daemon 跑起来也会一直报错
- HN 最佳发帖时段：美东周二~周四早 6-9 点 = UTC+8 晚 7-10 点

---

# 宣发计划

## 发布前准备

- [x] GitHub README 中英双语
- [x] 一句话 pitch：`Local-first Obsidian sync across macOS and iOS — zero cost, AI-native by design`
- [x] HN 帖子已写好并首发
- [x] GitHub profile 已创建
- [ ] 录终端 GIF：从 curl 安装到完成的全过程（用 asciinema 或 vhs）
- [ ] 确保 GitHub 仓库已设为 public

## 第一梯队：精准社区

### Hacker News
- [x] 已首发（周六凌晨，流量低）
- [ ] 择日重发（美东周二~周四早 6-9 点）

### Reddit r/ObsidianMD
- [ ] 发帖，标题参考：`I built a free sync solution for Obsidian across macOS/iOS using iCloud + Git`
- [ ] 先在社区参与几天讨论再发

### Reddit r/selfhosted
- [ ] 角度切"数据所有权"：`Your notes on your disk — Obsidian + iCloud + Git, no cloud service needed`

## 第二梯队：中文社区

### V2EX
- [ ] 发到 /t/share 或 /t/apple 节点

### 少数派
- [ ] 写完整文章（讲故事，不搬 README）

## 第三梯队：扩展传播

### X / Twitter
- [ ] 英文推文 + 终端 GIF

---

# zeromd × zeromd-preview 联动

核心定位：zeromd-preview 不是通用 markdown 预览器，而是 **zeromd vault 的专属阅读器**。

## 高优先级
- [ ] **Vault 自动发现**：复用 zeromd 的 iCloud vault 扫描逻辑，零配置打开
- [ ] **同步状态展示**：sidebar 展示最后同步时间、待同步文件数、健康状态
- [ ] **Vault 浏览体验**：为 vault 设计的专属浏览体验

## 差异化功能
- [ ] **Git 历史可视化**：利用 zeromd 每 5 分钟自动 commit 的精细历史，做时间线视图
- [ ] **笔记演化时间线**：展示一篇笔记从初始想法到完整文章的成长过程

## 不做
- 不让 zeromd-preview 编辑 markdown（和 Obsidian 重叠）
- 不让 zeromd 依赖 zeromd-preview（保持零依赖纯 bash）
- 不合并两个项目（技术栈完全不同）
