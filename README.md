# 三层项目协作 Skill v1.1

v1.1 新增：安装时向全局 `AGENTS.md` 写入受管理的触发段；卸载时仅移除该段。完整三层规则仍放在 Skill 中。v1.0 不会写全局规则。

## 1. 自动安装（约 1 分钟）

1. 解压 `three-tier-collaboration-v1.1.zip`（仓库内也提供 `three-tier-collaboration.zip`）。
2. 在同时包含 `install.ps1`、`README.md` 的目录空白处右键，选择“在终端中打开”。
3. 执行安装命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

无需管理员权限。`-ExecutionPolicy Bypass` 仅作用于本次启动的进程，不修改永久执行策略。PowerShell 7 也可使用 `pwsh -NoProfile -File .\install.ps1`。

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

卸载只移除标记段，不用旧版整份文件覆盖当前文件，因而保留用户后来添加的其他规则。分隔空行及安装时新建的空规则文件可保留。即使 Skill 已被手动移走，卸载脚本仍可清理孤立触发段。重复卸载不会报错；不修改 `config.toml`，不删除项目成果、状态或登记记录。

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

若只手动复制 `three-tier-collaboration` 文件夹到个人 Skill 目录，则不会写入全局触发段。完整 v1.1 安装请使用 `install.ps1`。正确目录层级是 `skills\three-tier-collaboration\SKILL.md`，不要多套同名目录，也不要只复制一个文件。

截至 2026-10-28，官方文档列出的个人 Skill 目录为 `$HOME/.agents/skills`，Windows 对应 `%USERPROFILE%\.agents\skills`；当前客户端实际也从 `%USERPROFILE%\.codex\skills` 识别过本 Skill。优先使用客户端已有目录，同一 Skill 只安装一份。

官方依据：[Build skills](https://learn.chatgpt.com/docs/build-skills)、[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。

`three-tier-collaboration/references/fallback-config.toml` 为原始配置参考，不自动加载，不要用它覆盖全局 `config.toml`。配置字段、模型名和并发设置须按当前客户端另行核验。

## 6. 测试与交付范围

`tests/test-installers.ps1` 仅在随机临时目录中运行，并显式使用临时 `AGENTS.md`。覆盖安装、升级备份、可恢复卸载、重复执行、预览、原规则及后续编辑保留、UTF-8/UTF-16 编码、异常标记、并发编辑、override 优先级、孤立触发段清理与目录选择。测试文件保留供检查。

本包含 Skill、README、VERSION、安装卸载脚本、触发模板、辅助脚本和测试。制作方仅在临时目录测试，未安装到你的真实 Codex Skill 目录，也未改写实际全局 `AGENTS.md`。只有你运行安装脚本后才会修改。
