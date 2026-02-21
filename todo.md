# cc-md 宣发计划

## 发布前准备

- [ ] 确保 GitHub 仓库已设为 public
- [ ] README 英文版校对（语法、拼写）
- [ ] 录一个终端 GIF：从 clone 到 install 完成的全过程（用 asciinema 或 vhs）
- [ ] 准备一句英文 pitch：`Local-first Obsidian sync across macOS, iOS, and Windows — zero cost, AI-native by design`

## 第一梯队：精准社区（优先级最高）

### Reddit r/ObsidianMD
- [ ] 发帖，标题参考：`I built a free sync solution for Obsidian across macOS/iOS/Windows using iCloud + Git`
- [ ] 正文重点：解决了什么痛点、架构图、和 Obsidian Sync 的对比、AI 接入优势
- [ ] 时间：美东时间周二~周四上午 9-11 点（活跃高峰）
- [ ] 注意：先在社区里参与几天讨论再发，避免被当成纯广告

### Reddit r/selfhosted
- [ ] 发帖，角度切"数据所有权"：`Your notes on your disk — Obsidian + iCloud + Git, no cloud service needed`
- [ ] 这个社区喜欢：零依赖、零成本、本地优先

### Hacker News (Show HN)
- [ ] 标题：`Show HN: cc-md – AI-native Obsidian sync via iCloud + Git (zero cost)`
- [ ] HN 喜欢的点：极简、bash 脚本、无依赖、Claude Code 直接读写知识库
- [ ] 时间：美东时间周二~周四上午 8-10 点
- [ ] 注意：HN 标题不要太营销，朴素描述即可

## 第二梯队：中文社区

### V2EX
- [ ] 发到 /t/share 或 /t/apple 节点
- [ ] 标题参考：`分享一个 Obsidian 多端同步方案：iCloud + Git，零成本，AI 原生`
- [ ] V2EX 用户在意：是否真的免费、有没有坑、和现有方案的对比

### 少数派
- [ ] 写一篇完整文章（不是搬 README，要讲故事）
- [ ] 结构：为什么做 → 踩过的坑 → 最终方案 → 使用体验 → AI 知识库展望
- [ ] 少数派喜欢：有温度的个人叙述 + 实用干货

## 第三梯队：扩展传播

### X / Twitter
- [ ] 发一条英文推文，附终端 GIF
- [ ] 打标签：#Obsidian #ClaudeCode #AI #knowledgebase
- [ ] 如果有 Obsidian 或 AI 领域的 KOL 互动，可以 @ 他们

### Product Hunt
- [ ] 优先级最低（纯 CLI 工具没有 UI，不占优势）
- [ ] 如果要发，准备好：tagline、description、首图（可以用架构图）
- [ ] 找 1-2 个人帮忙 upvote 冲首页

## 宣发节奏

```
第 1 周：完成发布前准备
第 2 周：Reddit r/ObsidianMD + r/selfhosted（验证反馈）
第 3 周：根据反馈优化后，发 Hacker News
第 4 周：V2EX + 少数派（中文阵地）
第 5 周+：X/Twitter 持续传播，Product Hunt 看情况
```

## cc-md × cc-md-preview 联动

核心定位：cc-md-preview 不是通用 markdown 预览器，而是 **cc-md vault 的专属阅读器**。

### 高优先级
- [ ] **Vault 自动发现**：复用 cc-md 的 iCloud vault 扫描逻辑，cc-md-preview 启动即找到 vault，零配置打开
- [ ] **替换 Chrome Cache 模块**：sidebar 第二模块改为"同步状态"，展示最后同步时间、待同步文件数、健康状态（绿/黄/红）、一键手动同步
- [ ] **Vault 浏览体验**：文件夹打开后的布局不做通用文件管理器，而是为 vault 设计的专属浏览体验

### 差异化功能（杀手级）
- [ ] **Git 历史可视化**：利用 cc-md 每 5 分钟自动 commit 的精细历史，做时间线视图、渲染级 diff 预览、笔记活跃热力图
- [ ] **笔记演化时间线**：展示一篇笔记从初始想法到完整文章的成长过程

### 不做
- 不让 cc-md-preview 编辑 markdown（和 Obsidian 重叠）
- 不让 cc-md 依赖 cc-md-preview（保持零依赖纯 bash）
- 不合并两个项目（技术栈完全不同）

## 通用宣发 checklist（未来复用）

每个新产品发布前过一遍：

- [ ] GitHub README 中英双语
- [ ] 一句话 pitch（英文 + 中文）
- [ ] 演示素材（GIF / 截图 / 视频）
- [ ] 目标社区清单 + 各社区的发帖角度
- [ ] 发帖时间规划（按时区）
- [ ] 先参与社区再发帖（避免冷启动被忽略）
