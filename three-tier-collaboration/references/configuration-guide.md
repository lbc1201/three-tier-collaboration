# config.toml 合并与恢复（v1.4）

## 目标与边界

已授权安装 v1.4 完整包时，安装脚本将同时维护 Skill、全局 AGENTS.md 触发段及下面五项配置。总控模型由用户选择，安装、更新与卸载均不写入或恢复顶层 `model`，既有值保持原状。用户仅要求调用、审阅、更新或打包 Skill 时，不修改正在使用的配置。

```toml
model_reasoning_effort = "medium"

[agents]
enabled = true
max_concurrent_threads_per_session = 3
default_subagent_model = "gpt-6-luna"
default_subagent_reasoning_effort = "medium"
```

这些字段已于 2026-10-28 对照 [OpenAI 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference) 核验。未来客户端版本不确定时，重新核验字段支持。下级默认模型名称写入成功不代表账号可访问或当前聊天已切换；显式会话参数、配置 profile、项目配置或管理策略仍可能优先。

全局位置为 `$CODEX_HOME/config.toml`；未设置 CODEX_HOME 时为 `~/.codex/config.toml`。完整包支持 `-ConfigPath`；未传入时取实际 AGENTS.md 所在目录中的 config.toml。不要覆盖全文件，不改认证、提供商、MCP、审批、安全、插件或其他配置。

## 执行方式

优先运行完整包的 `install.ps1` 或 `uninstall.ps1`，它们协调 Skill、触发段、配置和失败恢复。只有已安装 Skill 而没有完整包，且用户明确授权单独修改配置时，可使用 Skill 内的 `scripts/config-merge.py`。需要 Python 3.11+，不需要额外包。先校验路径与解释器，再执行：

1. `plan-install --config <绝对配置路径>` 或 `plan-uninstall --config <绝对配置路径>`：返回 JSON 计划，无文件写入。
2. 将计划 JSON 通过标准输入交给 `apply --backup-root <扫描目录外的备份目录>`。失败恢复可将同一计划传给 `rollback --backup-root <备份目录>`，其并发检查失败时保留当前文件并报告，不能强行覆盖。
3. 解析最终 TOML，核验目标值与其他配置未受影响；检查备份及所有权记录，再报告哪些值已写入、保持原样或因后续用户修改而未恢复。

计划含完整文件的编码副本，配置可能含凭据。调用时将计划捕获到内存后直接传递，不向聊天、工具输出或版本库打印原始计划、完整配置或备份。只报告五个目标字段、结果及必要文件位置。不要将真实配置或安装记录打进 ZIP 或上传 GitHub。

## 所有权与恢复

首次实际改动前保存整份配置备份，并在配置旁的 `config.toml.three-tier-collaboration.json` 记录本 Skill 改过的键及原值。配置原本已符合目标时不接管这些值；重复安装保留首次基线。v1.4 升级时放弃旧版对顶层 `model` 的管理而保留当前值；直接用 v1.4 卸载带旧版记录的安装时同样保留当前 `model`。卸载时，只将当前值仍等于上次安装值的其他已接管项恢复原值；用户后来改过的项保持原样。不会用整份旧备份覆盖当前配置。

合并保留非目标内容、注释和 UTF-8 BOM；被管理值恢复的是语义值，原引号风格不保证相同。卸载可保留空的 `[agents]` 表、空配置文件和已关闭的所有权记录。UTF-16、管理字段为复杂值、需要改写内联或点号 agents 定义等无法安全定位的情况会在写入前停止；先与用户确认具体转换范围，不声称已修改。存在旧别名 `agents.max_threads` 时先处理它与新键的冲突，不同时写入两者。

TOML 语法检查与全量语义差异检查只能证明文件可解析且改动范围符合目标，不能代替客户端实际加载和模型可用性验证。配置重载通常需重启客户端；不自行启动新研究阶段或启用总控身份。
