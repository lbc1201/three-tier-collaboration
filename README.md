# 三层项目协作 Skill 安装说明

## 1. 自动安装与卸载（Windows，约 1 分钟）

解压整个 ZIP 后，在解压目录空白处右键，选择“在终端中打开”。如果使用 GitHub 的“Download ZIP”，先进入同时包含 `install.ps1` 和 `README.md` 的目录。

安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

卸载：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

无需管理员权限。`-ExecutionPolicy Bypass` 仅作用于本次启动的 PowerShell 进程，不修改系统的永久执行策略。也可在 PowerShell 7 中直接执行 `pwsh -NoProfile -File .\install.ps1` 或对应卸载命令。

脚本会先查找已安装的同名 Skill；未安装时，依次考虑已设置的 `CODEX_HOME\skills`、已有的个人 Skill 目录。全新环境默认使用 `%USERPROFILE%\.agents\skills`。本机已有 `.codex\skills`，通常会采用该目录。若发现多个已有安装，脚本停止并要求指定目录。

指定安装目录（卸载时使用同一个目录）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot "$env:USERPROFILE\.codex\skills"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -InstallRoot "$env:USERPROFILE\.codex\skills"
```

`-InstallRoot` 指向父目录 `skills`，不要指向 `three-tier-collaboration` 本身。追加 `-WhatIf` 可以只预览，不修改文件。

安装前会校验文件复制结果，更新时将已有版本移到所选 `skills` 目录旁的 `skill-backups`。卸载也采用移动备份方式，保留已修改的文件；重复卸载不会报错。备份路径会显示在终端。恢复时，将备份目录以 `three-tier-collaboration` 为名移回原 `skills` 目录，已有同名安装先移出备份。

脚本拒绝操作符号链接、目录联接或身份不符的同名目录。不要分开移动 `install.ps1`、`uninstall.ps1`、`scripts` 和 Skill 文件夹；它们需要保持包内的相对位置。脚本只负责 Skill 文件，不修改全局配置、不启用总控身份、不删除项目成果。已有聊天中已加载的规则不会因移动文件立即从上下文消失。

## 2. 手动安装（Windows，约 2 分钟）

1. 右键 `three-tier-collaboration.zip`，选择“全部解压缩”。
2. 打开解压目录，找到 `three-tier-collaboration` 文件夹；其内部应直接包含 `SKILL.md`、`agents` 和 `references`。
3. 按 `Win + R`，输入 `%USERPROFILE%\.codex\skills` 并回车。这是本包制作时当前电脑已验证能被识别的个人 Skill 目录。目录不存在时，先查看下一节的版本差异。
4. 把整个 `three-tier-collaboration` 文件夹复制进去。同名目录已存在时，先将旧目录移到安装目录之外备份，再复制新版，不直接覆盖。
5. 在 Codex 输入 `$three-tier-collaboration` 检查是否识别；若没有出现，重启 Codex 后再试。

正确的安装层级：

```text
%USERPROFILE%\.codex\skills\three-tier-collaboration\SKILL.md
%USERPROFILE%\.codex\skills\three-tier-collaboration\agents\openai.yaml
%USERPROFILE%\.codex\skills\three-tier-collaboration\references\architecture-rules.md
%USERPROFILE%\.codex\skills\three-tier-collaboration\references\fallback-config.toml
```

不要只复制 `SKILL.md`，也不要多套一层同名目录。压缩包根目录的本说明无需复制到 Skill 安装目录。

## 3. 不同版本的目录

截至 2026-10-28，OpenAI 官方文档列出的个人目录为 `$HOME/.agents/skills`，对应 Windows 的 `%USERPROFILE%\.agents\skills`。本次使用的客户端实际从 `%USERPROFILE%\.codex\skills` 识别了此 Skill，因此上面给出本机路径。

在其他电脑或版本安装时，优先采用该客户端已使用的个人 Skill 目录；没有既有目录时，可按官方文档使用 `%USERPROFILE%\.agents\skills`，自行创建缺失目录。最终层级同样应为 `skills\three-tier-collaboration\SKILL.md`。同一 Skill 只安装一份，避免两个目录都放。

官方依据：[OpenAI：Build skills](https://learn.chatgpt.com/docs/build-skills)。文档说明 Skill 通常自动发现；未出现时可重启 Codex。

## 4. 使用与启用是两件事

安装后，可输入以下消息调用规则检查：

```text
使用 $three-tier-collaboration 检查当前项目的三层协作启用条件和工具能力。
```

若要启用项目的三层协作：

1. 由用户把目标聊天名称改为严格的“总控”。
2. 在该聊天直接发送：`添加总控身份`。本 Skill 可自动匹配该口令；若未加载，再补充发送：`使用 $three-tier-collaboration`。
3. 由助手核验真实会话名称、ID 和项目，完成登记；缺少信息时按提示补充。

调用 Skill 不等于已经启用。新增独立子会话仍须先审阅并批准具体方案；迁移和 Astra 使用仍须按规则单独授权。完整架构能否运行取决于客户端实际工具及其用途限制，安装成功不代表完整架构测试通过。

## 5. TOML 配置参考

`references/fallback-config.toml` 保留用户提供的原始配置，仅供参考，不会自动执行或加载。安装 Skill 无需把它复制到全局配置，也不要用它覆盖 `config.toml`。其中字段、模型名和并发设置的实际支持情况需要按当前客户端另行核验。

此包不会自动修改全局 `AGENTS.md`。原规则中提到由全局文件提供规则的内容，在 Skill 中已有加载方式的适配说明。

## 6. 验证与交付范围

卸载时，把安装的 `three-tier-collaboration` 文件夹移到所有 Skill 扫描目录之外；若客户端仍显示旧条目，重启 Codex。项目成果和协作记录不会因此删除。

开发者可运行 `tests/test-installers.ps1` 验证脚本。测试仅在随机临时目录执行，并保留测试文件便于检查。覆盖首次安装、升级备份、可恢复卸载、重复卸载、预览模式、身份校验及安装目录选择；不等于已验证完整三层协作架构。

本 ZIP 提供 Skill、README、安装与卸载脚本、共用路径检查脚本及测试。制作方本次仅在临时目录测试，未安装到真实 Codex Skill 目录，也未修改全局配置。
