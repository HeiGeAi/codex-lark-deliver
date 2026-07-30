# 宣传文案

我做了一个小的开源 Skill：Codex Lark Deliver。

它解决的是一个很具体但很高频的问题：Codex 或 Claude Code 跑任务的时候，人经常已经离开电脑了，桌面提示音听不到，手机端也不一定稳定。这个 Skill 会把 Codex 和飞书/Lark 的工作流接起来，让 Agent 每次完成任务后自动给你发飞书提醒。

更重要的是，我把“文件本体交付”也写进了规则里：如果任务生成了 PDF、PPT、Excel、Markdown、图片、网页快照、飞书云文档或其他文件，Agent 不能只说“我做好了”或者只丢一个链接，而是要尽量把文件本身也发到飞书里，并把发送结果和失败边界说清楚。

这个项目基于两个很棒的基础能力：

- Lark/飞书官方 CLI；
- Zara 做的开源项目 `lark-coding-agent-bridge`。

我额外做的事情是把安装、Skill 配置、Agent Markdown 提示词和交付纪律整理成一个可以复用的一键流程。适合已经在用 Codex、Claude Code、飞书，想把“任务完成提醒”和“文件交付”固定成默认工作流的人。

GitHub：<https://github.com/HeiGeAi/codex-lark-deliver>
