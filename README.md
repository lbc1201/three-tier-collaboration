# 三层项目协作 Skill v1.3

v1.3 修订总控漏派发问题：已登记总控每轮实质执行前先派给匹配的直属子会话，修改派回原会话；“简单任务”“报告结构调整”不能绕过。全局触发段也覆盖已登记成员的后续项目任务。保留 v1.2 的配置合并恢复与 v1.1 的触发段安装卸载功能。

## 1. 自动安装（约 1 分钟）

1. 解压 `three-tier-collaboration-v1.3.zip`（仓库内也提供 `three-tier-collaboration.zip`）。
2. 在同时包含 `install.ps1`、`README.md` 的目录空白处右键，选择“在终端中打开”。
3. 执行安装命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

无需管理员权限；需要已安装、命令行可调用的 Python 3.11+，不需要额外 Python 包。缺少依赖时会在修改前停止。`-ExecutionPolicy Bypass` 仅作用于本次启动的进程，不修改永久执行策略。PowerShell 7 也可使用 `pwsh -NoProfile -File .\install.ps1`。

脚本先查找已有同名安装；未安装时，优先使用已设置的 `CODEX_HOME\skills`，其次选择已有个人 Skill 目录。全新环境默认 `%USERPROFILE%\.agents\skills`；本机已有 `.codex\skills`，通常会选择该目录。多个已有安装会要求明确指定目录。

自定义目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot "$env:USERPROFILE\.codex\skills"
```

`-InstallRoot` 指向父目录 `skills`。追加 `-WhatIf` 只预览，不写文件。请保持 `install.ps1`、`uninstall.ps1`、`scripts`、`assets` 和 `three-tier-collaboration` 的相对位置。

## 2. 全局 AGENTS.md 的修改方式

全局规则默认位于 `%USERPROFILE%\.codex\AGENTS.md`；设置了 `CODEX_HOME` 时使用该目录下的 `AGENTS.md`。`-InstallRoot` 不改变这个全局位置。测试或特殊部署可另传 `-AgentsPath "D:\指定目录\AGENTS.md"`，卸载时使用相同参数。

触发段模板为 `assets/agents-trigger.md`。只管理以下标记之间的内容：

```text
<!-- BEGIN three-tier-collaboration managed trigger -->
<!-- END three-tier-collaboration managed trigger -->
```

安装前先校验文件和标记，对现有 `AGENTS.md` 保存完整备份，再追加或更新触发段；文件不存在时创建。重复安装不会重复添加触发段。保留标记外的原文、UTF-8/UTF-16 编码和 BOM。个人规则应写在标记外；标记内的内容会在更新时替换、卸载时移除。原有完整三层规则若已写在标记外，不会自动删除或迁移。

若同目录存在非空的 `AGENTS.override.md`，它会优先于 `AGENTS.md` 加载；安装脚本会在修改前停止，要求用户处理该优先级，不擅自修改 override 文件。标记缺失配对、重复、顺序错误、编码不支持或检测到并发改写时，也会停止并报告原因。

安装完成后新开聊天，使全局规则加载；必要时重启 Codex。已有聊天中的规则不会因磁盘文件改变立即替换。触发段提高发现可靠性，但模型指令不能保证每次执行绝对一致，也不能增加平台权限。

## 3. 卸载、升级与备份

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

自定义安装目录或规则文件时，卸载传入与安装相同的 `-InstallRoot`、`-AgentsPath` 参数。可追加 `-WhatIf` 预览。

升级前将旧 Skill 移到所选 `skills` 目录旁的 `skill-backups`，卸载也采用移动备份，不递归删除文件。`AGENTS.md` 每次实际修改前均保留完整备份，位置显示在终端。

卸载只移除标记段，不用旧版整份文件覆盖当前文件，因而保留用户后来添加的其他规则。分隔空行及安装时新建的空规则文件可保留。即使 Skill 已被手动移走，完整包的卸载脚本仍可清理孤立触发段及本包接管的配置值。重复卸载不会报错；不删除项目成果、状态或登记记录。

安装失败时会尽量恢复原 Skill，并保留相关副本。恢复 Skill 可将备份目录以 `three-tier-collaboration` 为名移回原 `skills` 目录；全局规则需先对比当前内容与备份，避免覆盖之后的编辑。仅恢复 Skill 文件不会自动恢复触发段，可重新运行安装脚本。

## 4. 使用与启用

安装后，在名称严格为“总控”的聊天中直接发送：

```text
添加总控身份
```

全局触发段会要求先加载 `three-tier-collaboration` Skill，再核验会话名称、真实 ID 和项目，完成身份登记。必要时可明确调用：

```text
使用 $three-tier-collaboration
```

讨论、引用或转换规则不构成启用。新增子会话、迁移与 Astra 使用仍按完整规则审批。安装成功不等于完整三层架构通过验证。

## 5. 手动安装与版本目录

若只手动复制 `three-tier-collaboration` 文件夹到个人 Skill 目录，则不会写入全局触发段，也不会应用配置。完整 v1.3 安装请使用 `install.ps1`。正确目录层级是 `skills\three-tier-collaboration\SKILL.md`，不要多套同名目录，也不要只复制一个文件。

截至 2026-10-28，官方文档列出的个人 Skill 目录为 `$HOME/.agents/skills`，Windows 对应 `%USERPROFILE%\.agents\skills`；当前客户端实际也从 `%USERPROFILE%\.codex\skills` 识别过本 Skill。优先使用客户端已有目录，同一 Skill 只安装一份。

官方依据：[Build skills](https://learn.chatgpt.com/docs/build-skills)、[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。

`three-tier-collaboration/references/fallback-config.toml` 保存六项配置目标。v1.2 安装器会按这些目标合并配置，不用此文件覆盖整份全局配置。字段依据见 [OpenAI 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)。模型可用性和客户端实际加载结果需另行核验。

## 6. config.toml 的合并与恢复

安装器管理的六项配置为：

```toml
model = "gpt-6.1-sol"
model_reasoning_effort = "medium"

[agents]
enabled = true
max_concurrent_threads_per_session = 3
default_subagent_model = "gpt-6-luna"
default_subagent_reasoning_effort = "medium"
```

配置位置默认是实际 `AGENTS.md` 所在目录的 `config.toml`。可传入 `-ConfigPath "D:\指定目录\config.toml"`，卸载时使用相同参数。`-WhatIf` 会预检，但不修改配置或生成所有权记录。

保留其他字段和注释，包括提供商、MCP、插件、审批与安全配置。写入前检查 TOML 语法，生成修改计划，备份原文件，再验证修改后解析结果只涉及目标字段。六项目标已经满足时，不改写配置内容，也不接管这些已有值。

配置旁的 `config.toml.three-tier-collaboration.json` 记录本包实际修改的键及原值。重复安装保留原始基线；卸载只恢复当前仍等于本包安装值的受管项。用户后来手动改过的项保持原样，不用整份旧备份覆盖配置。可能保留空 `[agents]` 表、空文件及已关闭的记录；被管理值按语义恢复，不保证原引号样式。

支持 UTF-8、UTF-8 BOM 及常见根级键和 `[agents]` 表。复杂内联或点号 agents 写法需要先整理为普通表；不支持 UTF-16 配置。发现旧别名 `agents.max_threads` 时会停止，避免与新键重复。布局不支持、语法错误或并发修改均在覆盖前报告，不强行重写。

安装器发生后续失败时，会尝试恢复已经写入的触发段、配置与原 Skill，保留备份。配置备份可能包含凭据，请仅保存在个人本机，不上传 GitHub 或发到聊天。安装完重启 Codex 后再核验实际加载，不代表当前聊天模型已自动切换。

## 7. 测试与交付范围

v1.3 对以下情况规定了不同处理方式：

| 收到的要求 | 总控应如何处理 |
| --- | --- |
| 调整报告结构，同时改变问题层级、数据或方法 | 先派原负责子会话实质修改，再验收整合 |
| “直接改”“很简单”“你决定”，但改变了研究内容 | 仍先派发；这些话不指定总控亲自执行 |
| 对已验收内容改编号、链接、排版 | 总控可直接机械整合，无需形式派发 |
| 下级尚在运行或只有旧成果 | 核验任务接续，等待本轮所需成果，不提前宣称完整完成 |
| 没有匹配下级或工具受限 | 说明缺口，按已有规则复用、审批或处理依赖，不静默接管 |

用户明确指定总控亲自执行的具体任务可按授权范围例外。总控仍负责关键独立验收，不将整项重做包装为验收。若已经漏派，保留事实，将草稿交下级实质核验或修改；补做审查不等于原流程已合规。

这些是指令与验收边界，不是运行时拦截器；不能保证模型绝不漏派。规则和安装脚本验证通过不代表真实多会话行为或完整架构已经通过测试。正在进行的总控聊天需显式重新加载已更新 Skill；更新磁盘文件不会撤回已发生的执行，也不保证替换所有旧上下文。

`tests/test-installers.ps1` 仅在随机临时目录中运行，并显式使用临时 `AGENTS.md` 和 `config.toml`。覆盖安装、升级备份、可恢复卸载、配置合并与恢复、重复执行、预览、原规则及后续编辑保留、AGENTS 编码、异常标记、并发编辑、override 优先级、孤立触发段清理与目录选择。`python tests/test_config.py` 另测配置的备份、语义保留、幂等、回滚及冲突处理。测试文件保留供检查。

本包含 Skill、README、VERSION、安装卸载脚本、触发模板、辅助脚本和测试。本次制作仅在临时目录验证配置合并；已安装 Skill 的指引与辅助脚本可单独更新，真实全局规则与配置仅在用户明确授权应用或运行完整安装器后修改。
