# 三层项目协作 Skill 安装说明

## 1. 解压安装（Windows，约 2 分钟）

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

## 2. 不同版本的目录

截至 2026-10-28，OpenAI 官方文档列出的个人目录为 `$HOME/.agents/skills`，对应 Windows 的 `%USERPROFILE%\.agents\skills`。本次使用的客户端实际从 `%USERPROFILE%\.codex\skills` 识别了此 Skill，因此上面给出本机路径。

在其他电脑或版本安装时，优先采用该客户端已使用的个人 Skill 目录；没有既有目录时，可按官方文档使用 `%USERPROFILE%\.agents\skills`，自行创建缺失目录。最终层级同样应为 `skills\three-tier-collaboration\SKILL.md`。同一 Skill 只安装一份，避免两个目录都放。

官方依据：[OpenAI：Build skills](https://learn.chatgpt.com/docs/build-skills)。文档说明 Skill 通常自动发现；未出现时可重启 Codex。

## 3. 使用与启用是两件事

安装后，可输入以下消息调用规则检查：

```text
使用 $three-tier-collaboration 检查当前项目的三层协作启用条件和工具能力。
```

若要启用项目的三层协作：

1. 由用户把目标聊天名称改为严格的“总控”。
2. 在该聊天直接发送：`添加总控身份`。本 Skill 可自动匹配该口令；若未加载，再补充发送：`使用 $three-tier-collaboration`。
3. 由助手核验真实会话名称、ID 和项目，完成登记；缺少信息时按提示补充。

调用 Skill 不等于已经启用。新增独立子会话仍须先审阅并批准具体方案；迁移和 Astra 使用仍须按规则单独授权。完整架构能否运行取决于客户端实际工具及其用途限制，安装成功不代表完整架构测试通过。

## 4. TOML 配置参考

`references/fallback-config.toml` 保留用户提供的原始配置，仅供参考，不会自动执行或加载。安装 Skill 无需把它复制到全局配置，也不要用它覆盖 `config.toml`。其中字段、模型名和并发设置的实际支持情况需要按当前客户端另行核验。

此包不会自动修改全局 `AGENTS.md`。原规则中提到由全局文件提供规则的内容，在 Skill 中已有加载方式的适配说明。

## 5. 卸载与交付范围

卸载时，把安装的 `three-tier-collaboration` 文件夹移到所有 Skill 扫描目录之外；若客户端仍显示旧条目，重启 Codex。项目成果和协作记录不会因此删除。

本 ZIP 只提供 Skill 文件及说明，没有自动安装脚本。制作方本次仅更新交付包，未执行安装或修改全局配置。
