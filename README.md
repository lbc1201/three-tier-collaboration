# 三层项目协作 Skill v1.3

在 Codex 中按“总控会话 → 独立子会话 → 子代理”组织项目，支持逐级派发、验收、状态保存与恢复。

## 1. 安装方式

### 方式一：向 Codex 发送安装指令

将下面的内容直接发送给 Codex，也可以先下载并附上 [v1.3 完整 ZIP](https://github.com/lbc1201/three-tier-collaboration/blob/main/three-tier-collaboration-v1.3.zip)：

```text
请安装 https://github.com/lbc1201/three-tier-collaboration 的 v1.3 完整包。
先读取 README，再使用完整包的 install.ps1 安装 Skill、全局 AGENTS.md 触发段和六项 config.toml 默认配置，不要只复制 SKILL.md。
保留其他全局规则和配置，修改前备份，完成后核验安装版本、触发段和配置结果。若已有完整三层规则写在标记段之外，先指出其位置，不要静默删除。若仓库不可访问或缺少依赖，说明具体缺口。
```

此仓库为公开仓库，可直接浏览并下载安装包，无需私有仓库访问授权。安装需要 Windows PowerShell 5.1 或 PowerShell 7，以及命令行可调用的 **Python 3.11+**；不需要额外 Python 包或管理员权限。

### 方式二：使用 PowerShell 命令

1. 下载并完整解压 [v1.3 ZIP](https://github.com/lbc1201/three-tier-collaboration/blob/main/three-tier-collaboration-v1.3.zip)。
2. 在同时包含 `install.ps1` 和 `README.md` 的目录打开终端。
3. 执行安装命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

先预览安装影响、不写文件：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
```

PowerShell 7 也可使用 `pwsh -NoProfile -File .\install.ps1`。`-ExecutionPolicy Bypass` 仅作用于本次进程，不修改永久执行策略。安装后重启 Codex，核验新配置是否加载。

### 安装位置、升级与卸载

Skill 目录优先复用已有同名安装；未安装时，优先使用 `$CODEX_HOME\skills`，其次选择已有个人 Skill 目录，全新环境默认 `%USERPROFILE%\.agents\skills`。当前制作环境使用 `%USERPROFILE%\.codex\skills`；多个已有安装会要求明确指定目录。

全局规则默认位于 `%USERPROFILE%\.codex\AGENTS.md`，已设置 `CODEX_HOME` 时使用该目录；配置默认是实际 `AGENTS.md` 同目录的 `config.toml`。自定义安装示例：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot "$env:USERPROFILE\.codex\skills"
```

还可传入 `-AgentsPath "D:\指定目录\AGENTS.md"`、`-ConfigPath "D:\指定目录\config.toml"`。`-InstallRoot` 指向父目录 `skills`；卸载时使用与安装相同的自定义参数。

升级无需先卸载：解压目标版本后重新运行该版本的 `install.ps1`，安装器会备份旧版。卸载命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

也可向 Codex 发送：

```text
请使用 three-tier-collaboration 完整包的 uninstall.ps1 卸载该 Skill，移除全局 AGENTS.md 中本 Skill 的标记触发段，并按安装记录恢复本 Skill 改过且之后未被我更改的配置项。保留其他规则、配置及项目成果，完成后核验卸载结果。
```

请保持包内 `install.ps1`、`uninstall.ps1`、`scripts`、`assets` 和 `three-tier-collaboration` 的相对位置。仅下载、解压或手动复制 Skill 文件夹，不会完成全局触发段和配置的安装。

## 2. 使用方式

### 首次启用项目

1. 由用户将项目的主要聊天名称改为严格的“总控”。
2. 在该聊天直接发送：

```text
添加总控身份
```

助手应加载 Skill，核验真实会话名称、ID 和项目并登记身份。仅安装 Skill、调用 Skill、讨论或引用规则，都不等于启用三层架构。

没有自动识别时，可明确调用：

```text
使用 $three-tier-collaboration。添加总控身份。
```

### 启用后的日常使用

在总控中直接提出具体任务，例如“梳理文献综述框架”“修改第二部分的研究逻辑”“继续上次任务”。总控应复用已登记的直属子会话，实质修改派回原负责会话；确需新建独立子会话时，先展示具体方案，取得用户批准后创建。

用户可直接进入子会话继续工作。用户批准的项目内直属双向通信，在原任务范围内沿用授权，不需要逐条重新确认；迁移、阶段推进和 Astra 调用仍按各自要求核验。

### 升级后如何生效

新版规则要求在版本变化、未加载或上下文不确定时主动重读 Skill。正在进行的旧聊天，建议升级后发送一次：

```text
读取已安装的 three-tier-collaboration v1.3，并按新版规则继续。
```

**不需要每轮重复发送“重新加载”。** 更新磁盘文件不保证所有运行中聊天立即采用新版上下文；必要时重启 Codex。

## 3. 具体功能

| 功能 | 具体行为 |
| --- | --- |
| 三层分工 | 总控管理独立、可恢复的子会话；子会话按需管理直属子代理。优先复用，不把临时代理冒充独立子会话，也不越级调度 |
| 先派发、后整合 | 总控在实质检索、分析、编程、计算或内容改写前先实际派发。改变研究问题、数据范围、方法、机制、结论或问题层级，不能以“简单”“报告结构调整”为由自行执行 |
| 逐级验收与恢复 | 分别核验消息发送、任务接续、成果返回与验收；保存真实 ID、职责、任务、状态和交接。额度恢复后检查相关直属子会话，按依赖恢复未完成任务 |
| 模型与授权管理 | 总控目标模型为 `gpt-6.1-sol`，各层目标推理强度为 `medium`；直属下级按任务选择 Luna、Terra、Sol。新增子会话、迁移和 Astra 调用遵守相应授权边界 |
| 安装、备份与卸载 | 安装 Skill 和全局触发段，合并六项默认配置；备份旧版本与被修改文件。卸载移出 Skill、移除标记段，并按所有权记录恢复配置 |

总控可直接处理协调、关键独立验收，以及已验收内容的排版、编号和机械整合；用户明确指定总控亲自完成的具体任务可按授权范围例外。没有匹配下级、授权或工具时，说明具体缺口，不静默接管。漏派后补做复核可修复质量问题，但不能追认原流程合规。

### 全局规则的维护

只追加或更新 `AGENTS.md` 中以下标记之间的触发段，完整架构规则保留在 Skill 中：

```text
<!-- BEGIN three-tier-collaboration managed trigger -->
<!-- END three-tier-collaboration managed trigger -->
```

修改前备份整份文件，重复安装不重复添加触发段；卸载只移除该段，保留标记之外的原文与后续用户编辑。个人规则应写在标记外。支持 AGENTS.md 的 UTF-8/UTF-16 编码与 BOM；若存在优先加载的非空 `AGENTS.override.md`、标记异常或并发编辑，先停止并说明原因。原有完整三层规则若在标记之外，不自动删除。

### 六项默认配置

从 v1.2 起，完整安装器合并以下配置，不覆盖整份 `config.toml`：

```toml
model = "gpt-6.1-sol"
model_reasoning_effort = "medium"

[agents]
enabled = true
max_concurrent_threads_per_session = 3
default_subagent_model = "gpt-6-luna"
default_subagent_reasoning_effort = "medium"
```

保留其他字段和注释，包括提供商、MCP、插件、审批及安全配置。写入前检查 TOML 语法及完整语义差异；已满足目标的值不改写、不接管。配置旁的 `config.toml.three-tier-collaboration.json` 记录本 Skill 实际改过的键及原值。重复安装保留原始基线；卸载只恢复当前仍等于安装值的受管项，保留用户后来修改的值，不用整份旧备份覆盖配置。

配置合并支持 UTF-8、UTF-8 BOM 及常见根级键和 `[agents]` 表。UTF-16 配置、无法安全定位的复杂布局、旧别名 `agents.max_threads` 冲突、语法错误或并发改写会在覆盖前报告。被管理值按语义恢复，不保证原引号样式；卸载可保留空表、空文件及已关闭的记录。备份位置显示在终端；配置备份可能含凭据，请仅保存在个人本机。

### 能力边界与验证

Skill 提供执行指令和验收要求，不是运行时拦截器，不能保证模型绝不漏派，也不能增加客户端权限。文件写入成功不等于账号支持目标模型或当前聊天已切换；profile、项目配置、会话参数和管理策略仍可能优先。新建、通信、恢复、迁移和完整架构必须分别按真实工具与证据核验。

安装与配置测试分别为 `tests/test-installers.ps1` 和 `python tests/test_config.py`，仅在临时目录执行。安装流程已在 PowerShell 5.1、7 验证，配置专项测试 10 项通过；这些结果不代表真实多会话行为或完整架构已经全部验证。

官方说明：[Skills](https://learn.chatgpt.com/docs/build-skills)、[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)、[配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)。

## 4. 版本迭代

**当前版本：v1.3。** 按新到旧排列，日期均为北京时间。

| 版本 | 日期 | 新增或修订 | 完整安装时的全局文件影响 |
| --- | --- | --- | --- |
| **v1.3** | 2026-10-28 | 修订总控漏派发：实质执行前实际派发、修改交回原子会话；明确纯排版与实质改写的边界；区分发送、接续、返回和验收；触发段覆盖已登记项目的后续任务 | 更新受管理的 `AGENTS.md` 触发段；沿用六项 `config.toml` 配置合并与恢复 |
| **v1.2** | 2026-10-28 | 新增六项配置合并、备份及所有权记录；重复安装保留基线；卸载逐项恢复并保留后续用户修改；新增 TOML 专项测试，需要 Python 3.11+ | `AGENTS.md` 触发段及六项 `config.toml` 配置，保留其他配置 |
| **v1.1** | 2026-10-28 | 新增全局触发段的安装、更新与卸载；保留其他规则、编码和备份 | 仅 `AGENTS.md` 的受管理触发段，不修改 `config.toml` |
| **v1.0** | 2026-10-28 | 将三层架构规则与兜底 TOML 转为 Skill，提供 README、安装卸载脚本、版本备份和可恢复卸载 | 不修改全局 `AGENTS.md` 或 `config.toml`；TOML 仅作参考 |

历史安装包：[v1.3](https://github.com/lbc1201/three-tier-collaboration/blob/main/three-tier-collaboration-v1.3.zip) · [v1.2](https://github.com/lbc1201/three-tier-collaboration/blob/main/three-tier-collaboration-v1.2.zip) · [v1.1](https://github.com/lbc1201/three-tier-collaboration/blob/main/three-tier-collaboration-v1.1.zip)。`three-tier-collaboration.zip` 为当前版本；v1.0 在此保留迭代记录。

从 v1.0/v1.1 升级到 v1.2 及以后版本，会新增六项全局配置的合并行为，可先用 `-WhatIf` 预览。后续功能迭代在本节追加记录，并同步版本标识与安装包；本次仅整理 README，版本保持 v1.3。
