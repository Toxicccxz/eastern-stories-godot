# Migration Tooling v1 — Final Re-Audit after P2F11

## Executive verdict

**BLOCKED — historical-evidence archival prerequisite failed.**

本次于 2026-09-16 执行前置门禁。用户明确要求：先验证 `b27b3a02` 归档；九份历史报告在当前 HEAD 的 SHA-256 任一不匹配即 BLOCKED，禁止修复或重写历史。

发现 **ARCHIVE-01**：P2F10 历史报告的 HEAD/index blob 与冻结原始字节不一致。工作区仍匹配冻结哈希，但提交中的 468 个 CRLF 已变为 LF。仅换行变化、不涉及正文字符变化，仍然不满足明确的 byte-identical 门禁。不能用工作区哈希替代已发布提交的 blob 哈希。

因此本次没有启动后续语义审计，不对 D1–D9、历史 17 个阻断项、测试或语料结果重新宣称 PASS/CLOSED。该发现属于归档证据前置条件失败；本次没有证据证明新的提取器语义缺陷。

## Frozen identities

- EXECUTABLE AUDITED SHA（本次指定的待审可执行基线，语义复审未启动）：`301fc35e9e719c6838c336aefb5054f7ccee4bde`。
- PRE-AUDIT REPOSITORY HEAD：`b27b3a02ad11852404e1fcfa1095f396df8cbb20`。
- 分支：`phase/migration-tooling-v1`。
- fetch 后本地 HEAD 与 origin phase 均为上述 `b27b3a02...`。
- 本地 main、origin/main、merge-base 均为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
- 初始 tracked/index clean，`git status --short` 为空。
- GitHub ALL-state 查询 `repo:Toxicccxz/eastern-stories-godot head:phase/migration-tooling-v1` 返回 `issues=[]`。
- 无本次新增提交，无新的 frozen audited HEAD。

## 15-commit history

重新读取 main→归档 HEAD 的全部 15 个提交，顺序、标题及每个单一父提交均符合用户提供序列；第一个父提交为冻结 main，其后逐项相连。

| # | Commit | Subject |
| --- | --- | --- |
| 1 | `0e5ff6a5cbc8d4091102e280c66868ba8763b4bb` | Analyze Migration Tooling v1 extraction contract |
| 2 | `8108763d6a4ddb3ad2b110200666424f4042e296` | Record Migration Tooling v1 P2 decisions |
| 3 | `8efc21ff8aa4c4c293347386f951631c56559fe2` | Add Migration Tooling v1 static room extractor |
| 4 | `1adb6534d579c5a2c1a4d21e166fb244096daa57` | Fix Migration Tooling v1 audit blockers |
| 5 | `864ebc4c8a749f3e56a39cd5cf0685b07765fd00` | Fix Migration Tooling v1 re-audit blockers |
| 6 | `c0c7ffb3de3e26cadf395772f7503e71d3690e11` | Complete weapon and armor migration exclusions |
| 7 | `820d478587fd69d3cf20c861e2694497eac8ef79` | Complete remaining standard object migration exclusions |
| 8 | `8cc5a01741232ed062aff52bee0e77b4d4351b39` | Fix comment-prefixed directive recognition |
| 9 | `a9b19467074b1cc697ba40a40d5954c20b4bc43a` | Fix multiline comments inside directives |
| 10 | `b10faeded5ddf39aefd136d0134bff81ca4446b5` | Fix raw echo directive semantics |
| 11 | `12a02e7fd989f40cb7da7059de74e9560b077c59` | Fix resolved include semantic hazards |
| 12 | `e0334346a3bfadbdd58fe213898361bdd6df6081` | Fix macro alias semantic hazards |
| 13 | `8ac248d40cc5e06add22a16a32ef2e37e20f3260` | Fix macro structural boundary and body hazards |
| 14 | `301fc35e9e719c6838c336aefb5054f7ccee4bde` | Fix create body directive segmentation |
| 15 | `b27b3a02ad11852404e1fcfa1095f396df8cbb20` | migration tool docs |

## b27 historical-audit archival validation

父提交恰为 `301fc35e9e719c6838c336aefb5054f7ccee4bde`；标题恰为 `migration tool docs`。完整提交差异恰为指定九份历史审计文件的新增：9 files, 3687 insertions；无其他路径变化。

`tools/migration`、`tools/tests`、`reference/es2`、`game`、`.github`、Save/runtime schema、DECISIONS、STATUS、ROADMAP 均无归档提交增量（全部差异仅九份新增报告）。可执行与测试树保持指定基线。

对每份文件分别读取 Git blob、index blob 和工作区原始 bytes；使用 Python `subprocess.check_output` 获取 Git 字节，未经过 PowerShell 文本管道或文本解码再编码。

| Historical document | Frozen SHA-256 | HEAD/index SHA-256 | Result |
| --- | --- | --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` | MATCH |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F9.md` | `ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4` | `ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4` | MATCH |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F10.md` | `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213` | `b3b746d7685120df5e4375f6e2250dc610f58738272b257e306a2cd91900cff6` | **MISMATCH** |

全部九份均已 tracked。工作区九份哈希全部匹配用户冻结值；HEAD/index 仅八份匹配。P2F10 具体证据：

| Property | Frozen-matching worktree | HEAD / index |
| --- | --- | --- |
| Bytes | 24,417 | 23,949 |
| CRLF pairs | 468 | 0 |
| Total LF bytes | 469 | 469 |
| SHA-256 | `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213` | `b3b746d7685120df5e4375f6e2250dc610f58738272b257e306a2cd91900cff6` |

内存中的 `worktree_bytes.replace(b"\r\n", b"\n") == head_blob` 为 true。这证明差异恰为上述 CRLF 规范化，没有写回任何文件。根 `.gitattributes` 为 `* text=auto eol=lf`；`git ls-files --eol` 显示该报告 `i/lf w/mixed`。因此 Git clean 状态与原始字节哈希不一致可以同时成立。

**ARCHIVE-01 remains OPEN / BLOCKING。** 不将换行等价自行解释为用户允许的 byte-identical 例外；也不改冻结值、历史文件或 Git 属性。

可重复的只读检查（仓库根目录运行，Python 可执行文件按本机配置）：

```python
import hashlib, pathlib, subprocess
p = 'docs/migration/MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F10.md'
head = 'b27b3a02ad11852404e1fcfa1095f396df8cbb20'
blob = subprocess.check_output(['git', 'show', head + ':' + p])
work = pathlib.Path(p).read_bytes()
print(hashlib.sha256(blob).hexdigest())
print(hashlib.sha256(work).hexdigest())
print(len(blob), len(work), work.replace(b'\r\n', b'\n') == blob)
```

忽略目录 `build/migration-tooling-v1/final-p2f11/` 保存本次 `archive_gate.py`、`archive-gate-evidence.json`、`pr-search.json`，以及该报告 `.head.bin` / `.worktree.bin` 两份原始字节快照。它们是本地复现证据，不是提交产物。

## Full milestone diff

NOT RUN：仅完成前置身份、15 提交链与归档提交差异检查。没有将其表述为 main→HEAD 全里程碑代码/安全审计完成。

## D1–D9

NOT RUN：归档门禁失败，D1–D9 保持锁定但本次未重新认证；material defect 数量未评估，不能报告为零。

## 17 historical blockers

NOT RUN：本次不基于旧测试日志重新标记任何历史阻断项 CLOSED。17 项的完整新验证须在前置门禁解决后执行。

## P2F11 directive segmentation

NOT RUN：原始 FR10-01、兄弟指令、LF/CRLF 及位置矩阵未执行。

## True malformed controls

NOT RUN：真实 malformed 控制与 include 提供分号控制未执行。

## Macro closure

NOT RUN：P2F10 宏边界、函数体、别名、循环及跨头文件闭包未重新验证。

## Include closure

NOT RUN：依赖摘要、嵌套/相对 include、坏依赖、create 内 include 未重新验证。

## Directive closure

NOT RUN：comment-prefix、continuation、multiline comment、raw echo 及物理行边界未重新验证。

## 14 ANSI exclusions

NOT RUN：接受的保守覆盖损失政策保持不变；本次未重新统计其名单或分类，也未以此作为阻断理由。

## Actual inventories

NOT RUN：指令、include、宏实际语料 inventory 未重新计算。

## Globals / weapon / armor

NOT RUN：本次未重新读取这些 LPC authority 或重新证明精确排除覆盖。

## SSERVER

NOT RUN：本次没有提出新的分类结论。

## Output security

NOT RUN：路径限制、writer reachability、symlink/路径攻击矩阵未执行。

## Closed schema / version compatibility

NOT RUN：1.0.0–1.0.11 完整 canonical 替换、manual/reviewed/未知输出拒绝矩阵未执行。

## Facts / exits

NOT RUN：允许事实、exit0/1/2、false quarantine 语义未重新认证。

## Provenance

归档原始字节 provenance 门禁失败，见 ARCHIVE-01。提取器全部 source span、SHA、line/column、fact ID、raw/raw_hex 未执行新验证。

## Fresh tests

只运行前置只读 Git/原始字节检查，以及本报告完成后的 `git diff --check` 和最终文件不变性检查。未运行 migration unittest、完整 Python suite 或 repository_checks；历史 280/326 不能计为本次通过数。未运行远端 CI。

未启动 Godot 实机验证：本次在归档门禁中止，且未修改或验收玩家运行时行为。

## Docs validation

已读取根 AGENTS、docs/AGENTS 与 `.gitattributes`；九份历史文档均读取原始字节进行哈希。因前置失败，完整链接/锚点/源引用及 P1–P2F11 内容审计未执行，不报告零失败。

本报告为阶段审计证据，放于 `docs/migration/`，按 BLOCKED 分支保留 untracked / unstaged。

## Corpus A/B

NOT RUN：没有新 A/B 提取；2336/485/13 等历史数量及历史 SHA 均不作本次通过证据。

## 13 quarantines

NOT RUN：八份 encoding 与五份 syntax 源文件尚未在本次逐字节复核。

## Real-source review

NOT RUN：六份选定真实 LPC 样本、13 quarantines 与14 ANSI 源文件的语义复核未启动。

## Manifest integrity

NOT RUN：源输入全覆盖、唯一 ID/path、summary、finding refs 与 deterministic ordering 未重新计算。

## Source immutability

当前 HEAD 与冻结 main 的 `reference/es2` Git tree 均为 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。初始 tracked/index clean；本次未修改 reference 或其他 tracked 文件。未以此替代全部源文件 manifest 的新计算。

## Security / artifacts

归档增量仅九份指定报告；无执行文件、测试、game/reference/Save/CI 增量。全里程碑 credentials、许可证、第三方代码与产物内容审计 NOT RUN。仅新增本报告及 ignored 目录中的本地复现材料。

## Residual risks

ARCHIVE-01 为用户明确的前置阻断条件，不能降为 residual risk。完整 HIGH/MEDIUM/LOW 残余风险评估未执行，包含 bounded lexer/preprocessing、macro/include 摘要、UNKNOWN/ANSI 保守拒绝、first-column 差异、旧源码损坏、driver 差异、TOCTOU、大小写、输出规模、schema 与 authorship、SSERVER、Native consumer、CI、公开发行许可等。此处未重开或改变既有合同。

## PR readiness

**NOT READY。** 分支仍为 `phase/migration-tooling-v1`，本地/远端仍为 `b27b3a02...`。无 phase PR，无本次 PR CI，无 merge；main 保持冻结值，本次未查询或重跑 post-merge main CI。里程碑未由本次认证 implementation-complete，也未集成到 main。

## Next owner gate

等待 owner 审阅归档字节差异并明确后续处理；本次不修复、不改 STATUS/ROADMAP/DECISIONS、不提交、不推送、不创建 PR、不合并、不开始 P3。不重置、revert、rebase、stash、clean、amend 或重写归档历史。

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F11 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
