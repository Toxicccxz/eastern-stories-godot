# Migration Tooling v1 — P2F36 fail-closed Git output protection

2026-09-24。Owner仅授权修复FR35-01（HIGH / D7、D9 / owner E / Gate-B E），即第42项语义阻塞。本次为实现修复与验收，不是再次Final Re-Audit，不恢复Gate B。

## Authorization and frozen identities

- Branch: phase/migration-tooling-v1。
- Frozen parent: 996a5ada08129925ccdc02c6d7f379dcea68ea7c。
- Parent subject: Recognize directive-separated macro pairing uncertainty。
- Frozen main / origin main / merge-base: cd07808cb76147d0b8c0dad9b82d078b49fefe64。
- Fresh fetch和all-state PR查询已完成：parent/origin phase一致，无phase PR，续做初始恰好3个授权tracked文件未暂存，index clean；STATUS/ROADMAP未改。
- P2F35 OWNER APPROVED / CLOSED；FR34-01已有实现修复。Gate A PASS/FROZEN；AR-01 ACCEPTED/NON-BLOCKING。
- Final Re-Audit after P2F35已执行且BLOCKED；Gate B仍BLOCKED/INCOMPLETE。FR35-01本次实现修复，等待owner review，不宣称里程碑审计PASS。

依据：[P2F35](MIGRATION_TOOLING_V1_P2F35_DIRECTIVE_SEPARATED_PAIRING_UNCERTAINTY.md)、[D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)、[root instructions](../../AGENTS.md)、[docs instructions](../AGENTS.md)。完整读取owner-local P2F35 Final Re-Audit；其文件未添加为tracked文档链接，也不入提交。

## Resume / Attempt 1 disposition

本次是既有P2F36候选的RESUME，不是Attempt 2、新修复切片或新语义FR。Owner把Attempt 1的38个失败定性为NON-SEMANTIC RELEASE/VERSION-REGISTRY ACCEPTANCE GAP；当时按硬停止规则保留现场，没有创建P2F36提交。不存在FR36-01。

本次保留cli.py安全修复和room_extractor.py版本常量字节；只修正产品测试中的6处版本登记：ScanAndCliTests.test_previous_complete_100_output_upgrades_atomically、P2F2RegressionTests.test_all_known_versions_upgrade_with_real_atomic_replace、P2F12RegressionTests.test_original_reproducer_real_cli的当前输出断言改为1.0.36；metadata-only、nested/closed-schema、atomic-upgrade三个完整历史集合追加1.0.36并保留1.0.35。没有全局替换历史版本fixture，也没有修改parser语义或结构期待值。

先从头运行migration，再运行full Python，再完成focused/combined及其余全部门禁。以下pre-commit结果来自resume命名空间；Attempt 1的通过或部分证据未代作本次验收。

## Pre-fix reproduction

在任何实现编辑前，于冻结parent上重新执行真实CLI和独立in-process确认：

| Case | Before repair |
| --- | --- |
| 正常Git探测，外部tracked canonical目标 | exit2 / unchanged |
| 同一checkout，Git ownership probe fatal128 | exit0 / target changed / index保持旧bytes |
| 独立checkout，forced fatal rev-parse，真实writer wrap spy | exit0 / writer1 / target changed / index unchanged |
| successful probe + fatal ls-files control | exit2 / writer0 / unchanged |
| fatal probe + manual noncanonical control | exit2 / writer0 / unchanged |

真实ownership实验只使用临时checkout和子进程环境GIT_TEST_ASSUME_DIFFERENT_OWNER=1，进程级safe.directory空值用于确保触发拒绝；没有修改实际owner或用户/global/local配置，没有使用safe.directory=*或绕过Git安全检查。

原真实CLI目标before SHA为1faf09354561dc886e6ce8adf895d1aaf2dfbce957b2523c08ebd486011299cc，after为30baf6ae26ca3c4db55a552124a9e60d7f32cdbc23b64ce793da443b49d851cb；tracked index blob 9f5b7ce17c71d78a24acdd975cddae33582cb6e7，index bytes未改变。

## Root cause and bounded repair

[cli.py](../../tools/migration/cli.py)原先只在rev-parse返回0时检查ls-files。非零既可能表示普通非Git目录，也可能表示真实仓库无法安全访问；旧实现将两者一律放行到canonical识别和写入，构成fail-open。

修复仅增加destination()的失败分支：

1. 保留既有read-only rev-parse探测。
2. 成功时保留既有checkout/ls-files逻辑。
3. 失败时，从目标最近现存祖先向文件系统root逐级检查.git，调用lstat，不读取marker内容、不跟随它的indirection。
4. 任意.git目录、文件、链接或其他存在形态均视为ambiguous/protected，抛ToolError。
5. 除FileNotFoundError之外的marker检查OSError转成ToolError；检查失败不作为“不存在”。
6. 只有整条祖先链没有.git标记时，才继续既有普通non-Git外部输出规则。

不解析Git stderr，不依赖语言或版本消息，不读repository config、不执行hook、不尝试信任或修复Git marker。安全判断使用结构信息。不能将所有rev-parse非零一律拒绝，否则普通外部目录会回归；本修复保留它们。

正常ls-files契约完全不变：0→tracked拒绝；1→untracked继续；其他→ToolError/exit2。writer、scan和schema实现未改。es2_source.py未改。room_extractor.py只更新两个版本常量为1.0.36和已知1.0.0–1.0.36共37版本；与parent的其余原始字节一致。schema_version=1，profile=static-room-v1。

## Focused tests and independent output matrix

新增18个产品契约测试；独立矩阵另用不同fixture、期待值与真实canonical/index建立，不以产品输出反推期待值。修复后全部通过：

| Matrix | Evidence |
| --- | --- |
| 真实.git目录 / 真实.git文件（separate-git-dir形式） | 各9种状态；包含tracked、working tree缺失但index存在、nested新路径、nested canonical、healthy untracked、ls-files fatal、real ownership fatal |
| marker-free / stray目录 / stray文件LF及CRLF / modeled link / inspection denied / inspection I/O error | 各new/canonical/nested-new，共21种 |
| 独立矩阵合计 | 39次cli.main；每条核验scan/writer次数、exit、目标bytes、适用index bytes |
| 另行真实subprocess CLI | 正常tracked及真实ownership拒绝各1次，共2次；均exit2，target/index unchanged |
| 受保护或有歧义的路径 | exit2 / scan0 / writer0，无新Migration IR写入 |
| 普通non-Git外部new/recognized overwrite/nested-new | exit0 / scan1 / writer1，继续允许 |
| healthy untracked Git目标 | 保留允许输出；实际ls-files返回1 |
| successful probe + tracked / fatal ls-files | 拒绝，writer0，原目标和index不变 |

.git文件只用存在性作为失败分支保护，不解析gitdir内容；正常Git探测成功时仍由Git处理合法文件式worktree/submodule布局。stray marker拒绝是允许的保守输出拒绝，属于工具exit2而非source quarantine。链接分支使用modeled lstat presence；不新增native symlink/junction qualification。

独立spy对scan/atomic_write使用wraps，保持真实逻辑；受保护目标在destination阶段拒绝。产品测试还验证canonical未调用。故障不会被转换为QUARANTINED、corpus exit1或成功exit0。

## Complete output security and compatibility

保留既有输出安全测试与独立矩阵：repository/game/reference/docs保护、absolute/parent-relative escape、source/output overlap、外部tracked checkout、approved build与ordinary external输出、manual/reviewed/future/unknown/malformed/empty拒绝、invalid UTF-8 raw_hex、modeled symlink/junction、source read/schema/internal/invalid destination/atomic replace错误。

- 37个历史canonical版本逐一经真实CLI替换；输入历史证据不变，新输出版本1.0.36。
- 33个实际嵌套dictionary位置逐一注入未知metadata：exit2 / writer0 / target unchanged。
- 6类不安全已有文档拒绝，writer0且原始bytes不变。
- 8项repository保护路径组合通过；既有产品路径/escape测试全部保留。
- 原7项failure-route probes通过。
- 新增5项独立serialization exception、round-trip mismatch、stream write、flush、fsync故障通过。前两项writer0；写入期间故障writer1但目标bytes不变、无temp residue；全部exit2。
- FR35-01主复现、39项Git/非Git矩阵与2项真实CLI全部通过。

## Structural regression / product suites

Gate A只重跑既定回归，不重新探索parser：

| Gate | Fresh pre-commit result |
| --- | ---: |
| P2F36 focused | 18 PASS |
| P2F35 focused | 10 PASS |
| Combined P2F22/26–36 | 157 PASS |
| Migration suite | 586 PASS |
| Full Python suite | 632 PASS |
| FR34 primary / independent | 4 CLI + 4 direct invocation traces PASS |
| P2F35 pairing matrix | 984 CLI PASS：600旧false-Q修复、360 OOS、24真损坏controls |
| Gate A frozen structural | 13,634 CLI / 72 families PASS |
| AR-01 final safety | 20 PASS |
| Canonical compatibility | 37 PASS |
| Nested metadata pollution | 33 PASS |

所有产品测试零failure、零error、零skip。结构回归无object delta，未修改任何手写结构期待值。AR-01仍为接受的非阻塞残余，不借机修复。repository_checks.py、git diff --check、Markdown相对链接/anchor/whitespace检查也必须通过才提交。

## Corpus A/B / exact parent projection

两次独立P2F36真实CLI全源扫描：exit1，完整输出2336文件；485 supported/PARTIAL、0 EXTRACTED、1838 OUT_OF_SCOPE、13 QUARANTINED、2736 facts、4296 findings。

每份9808627 bytes，A/B byte-identical；P2F36 SHA-256 **9e780e357dfe06c0cf838b1bb15d333c1436c6e64f00d2a90c93379f22135417**。

从git show读取exact P2F35 parent的Python工具字节，在隔离module namespace重新扫描原始source，不执行LPC。parent SHA为f864ada742317b69fffd4e2fdd5ac9b1656ec00f23ed1048d93682bdbf4b76d8。对完整document剔除extractor_version后精确相等：affected paths=[]；candidate/status/facts/findings/provenance/direct-inherits零差异；13 quarantines相同。

实际bytes回归确认8 encoding和5 syntax的path、reason/span、raw、facts[]不变；这不是恢复Gate B全路径认证。14 ANSI对象全部false/OOS/facts[]。

9587 provenance记录重新核验：2736 facts、4296 findings、1799 direct inherits、756 normalization inputs；path/hash/raw/raw_hex/span/line/Unicode column/scope/construct/ordinal/normalization/ID公式/order/refs/manifest/summary/UNREVIEWED均通过，无重复、ghost/orphan或dangling ID，无auto APPROVED。

## Source, archive and33 owner-local evidence

Reference tree：4106480ab28cce8cd7b55704f8ae9ae062d42d03。

2336-file raw manifest：744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80。

ARCHIVE-01 CLOSED；10份tracked历史审计raw hashes和P2F10的24417 bytes / 468 CRLF保留；.gitattributes例外规则未改。

33份owner-local历史证据全部untracked/unstaged/byte-identical。第32份P2F35 Final Re-Audit：27162 bytes，SHA-256 3a1c6e806b2427be108b5df83d8266bf5c7c20f26e4459eaa8c72a1d5fd701bd，原始Git blob identity f532b3acc0589671de13871578b74d936c93332a。第33份为MIGRATION_TOOLING_V1_P2F36_FAIL_CLOSED_GIT_OUTPUT_PROTECTION_ATTEMPT1_BLOCKED.md：9964 bytes，SHA-256 b1249375ee4bf457c558290f13d5fa42d69346cbb9545810d8aaaeeb3161169f，raw Git blob ec88ca31609797247acc365bcec35758c53368a4；历史BLOCKED结论未改。没有把它们作为实现提交的一部分。

## Scope and acceptance evidence

恰好六个授权文件：cli.py、room_extractor.py（version constants only）、test_migration_tooling.py、本报告、STATUS.md、ROADMAP.md。无DECISIONS/es2_source/schema/reference/game/runtime/workflow/dependency变化。

Ignored证据位于build/migration-tooling-v1/p2f36/；包括preflight、修复前output-probe/confirm-output、resume/post-git36、resume/post-gate-a、product logs、security/compatibility、A/B corpus、parent、provenance/ordinals、raw quarantine regression、docs、integrity及acceptance36汇总。测试输出不是Native migration output，不提交。

提交subject固定为：Fail closed when Git output protection cannot be verified。parent必须为996a5ada08129925ccdc02c6d7f379dcea68ea7c。提交后必须在immutable commit重跑全部上述要求，全部通过才允许正常push；post运行使用新输出namespace，不复用resume结果。最终交付SHA和immutable结果由post-acceptance36.json / post-integrity.json及owner完成报告记录，无amend。

## Remaining qualifications / owner gate

- 仍保留已披露的filesystem TOCTOU限制；不引入锁或跨Git/index事务。
- stray .git可保守拒绝；这是允许的输出安全取舍。
- 不扩大bare repository或任意GIT_DIR/GIT_WORK_TREE组合支持；本次最低契约是普通.git目录/文件worktree的完整保护。
- format/schema识别不等于作者身份；tracked保护独立于canonical格式。
- Python 3.12 stdlib only；无新依赖，不运行LPC或Godot。此纯工具安全修改不要求live gameplay。
- Gate A保持PASS/FROZEN；Gate B仍BLOCKED/INCOMPLETE；42项历史阻塞有实现修复不等于里程碑Final Re-Audit认证。
- 无新Final Re-Audit、无Gate-B continuation、无P2F37、无PR、无merge、无P3、无Native生成、无remote-CI acceptance claim。

**P2F36 IMPLEMENTED — AWAIT OWNER REVIEW.**
