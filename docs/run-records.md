# Run Records 鈥?鎸?case 璁板綍"鍝簺渚嬪瓙鐪熺殑璺戣繃"

`docs/demo-matrix.md` 璇存槑鍝簺渚嬪瓙**鍙繍琛?*锛涙湰椤垫寜 case 璁板綍**瀹為檯鎵ц杩囦粈涔?*銆?瑙傛祴缁撴灉銆佽瘉鎹綅缃笌缁撹銆傝鍒欙細鍙繍琛?鈮?宸茶繍琛岋紱鎶ュ憡閫愬瓧寮曠敤锛涗笉寰楀紩鐢ㄧ鐩樹笂涓嶅瓨鍦ㄧ殑浜х墿銆?
鐢熸垚鐗╃粺涓€鏀惧湪 `examples/_reports/`锛堜笅鍒掔嚎鍓嶇紑 = 鏈湴浜х墿锛屽凡 git-ignore锛?姝ゅ墠鍙?`examples/.stack/`锛岄殣钘忕洰褰?+ 鍚嶅瓧涓庡疄闄呭唴瀹逛笉绗︼紝鏁呮敼鍚嶏級銆?
---

## Case R1 鈥?FP-1 鑱旈偊鍛堢幇锛坄agent-federated-presentation-local`锛?
| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鉁?宸叉墽琛屽苟閫氳繃锛?/4锛?|
| 杩愯鏃堕棿 | 2026-10-13 20:44锛坴alue report锛夛紡2026-10-14 09:08锛坙ive report锛夛紝鍐呭瀛楄妭鐩稿悓 |
| 鐜 | 鏈湴 PostgreSQL `5433`銆丯OMIVELA `1956`銆丒IDOVELA `1966`銆丩IMENORA `1897`锛涚敱 `adapters/presentation-client` 椹卞姩 |
| 缁撴灉 | FP-01 `200, proofs stripped`锛汧P-02 `407`锛汧P-05 `407`锛堥噸鏀捐鎷掞級锛汧P-07 鎷掔粷涓斾笂娓告湭瑙﹁揪 |
| 璇佹嵁 | 鏈湴 `.local-data/fp1-{value,live}-report.json`锛坓it-ignore锛?|
| 璁板綍 | [examples/agent-federated-presentation-local/RUN-RECORD.md](../examples/agent-federated-presentation-local/RUN-RECORD.md)锛堟寜 case 鍒嗚妭锛?|
| 缁撹 | 璇佹槑"鍚堟硶鍑嵁+鍙岃瘉鏄庘啋涓婃父涓斿墺绂昏瘉鏄?涓庝笁鏉℃嫆缁濊矾寰勶紱涓嶅惈鍚婇攢 SLO銆佸閮?IdP銆佸け璐ョ煩闃?|

## Case R2 鈥?涓氬姟 demo 姹囨€?dashboard锛坄scripts/report-value.ps1`锛?
| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鈿狅笍 宸叉墽琛屼絾**鏃犵粨鏋?*锛堜笉绠楅€氳繃锛?|
| 杩愯鏃堕棿 | 2026-10-12 19:29 |
| 缁撴灉 | `examples/_reports/all-demos-report.json` 鍐呭涓?`{"generated_at":"鈥?,"demos":[]}` 鈥斺€?**demos 涓虹┖** |
| 璁板綍 | 鏈〉 |
| 缁撹 | 璇ユ姹囨€绘棦鏈€氳繃涔熸湭澶辫触浠讳綍 demo锛涘繀椤荤敱鍚庣画姹囨€昏繍琛屾浛鎹紝**涓嶅緱浣滀负璇佹嵁寮曠敤** |

## Case R3 鈥?13 涓笟鍔?demo锛堝彲杩愯锛屼絾鏃犳墽琛岃褰曪級

| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鉂?鏈伐浣滃尯**鏃犳墽琛岃瘉鎹?* |
| 渚濇嵁 | [demo-matrix.md](demo-matrix.md) 涓瘡涓?demo 澹扮О浜у嚭 `*-value-report.json`锛屼絾纾佺洏涓婁笉瀛樺湪杩欎簺鎶ュ憡锛堜粎瀛樺湪 Case R1 鐨?FP-1 鎶ュ憡涓?Case R2 鐨勭┖ dashboard锛?|
| 濡備綍鍙樻垚"鏈夎褰? | 閫愪釜杩愯 `run-all.ps1`锛堟垨鏁翠綋 `scripts/report-value.ps1`锛夛紝鎶婁骇鍑虹殑鎶ュ憡鎸?Case R1 鐨勬牸寮忚惤鎴愬悇渚嬪瓙鑷繁鐨?`RUN-RECORD.md`锛屽苟鍥炲埌鏈〉鍔犱竴琛?|
| 缁撹 | 浠ｇ爜/閫傞厤鍣?鑴氭湰涓庤璁℃枃妗ｉ綈澶囷紝浣?璺戣繃"杩欎欢浜嬬洰鍓嶅彧鏄?*澹扮О** |

## Case R4 鈥?R6 bridge 鏈湴 bring-up锛坄agent-workflow-bridge-local`锛屾柊澧烇級

| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鉁?宸叉墽琛屽苟閫氳繃锛? 涓満鏅?case锛?|
| 杩愯鏃堕棿 | 2026-10-16 |
| 缁撴灉 | axond 鍚姩鏃ュ織鍑虹幇 `Orchestrator: Rheovela`锛堣琛屽彧鍦ㄧ湡瀹?AEGIVELA 鏂█璁よ瘉鎴愬姛鍚庢墦鍗帮級锛沗POST /v1/instances` 鈫?瀹炰緥 `active`锛沗GET /v1/instances/{id}` 鈫?`active`/`definition_id=expense`锛沗POST .../steps` 鈫?`ok`锛沗GET .../audit` 鈫?閫?|
| 澶辫触/璐熷悜 | F1 SDK 缂烘潈濞佸ご鈫?01锛堝凡淇級銆丗2 鏂█ TTL 瓒呴檺鈫?00锛堝凡淇級銆丗3 `evidence_ref` 褰㈢姸锛堢粫琛岋級銆丗4 缂虹鎴封啋fail-closed銆丗5 health 200鈮犺璇侀€氳繃銆丗6 婕忚 env鈫?01銆丗7 鏃犲嚟璇佽繙绋嬬洃鍚鎷?|
| 璁板綍 | [examples/agent-workflow-bridge-local/cases/](../examples/agent-workflow-bridge-local/cases/)锛坈ases 01鈥?5锛?|

---

## Case R5 鈥?鎻掍欢婊氬姩鏇存柊涓庡洖婊氾紙`plugin-rolling-update-local`锛屾柊澧烇級

| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鉁?宸叉墽琛屽苟閫氳繃锛? 涓満鏅?case锛屽浠堕┍鍔級 |
| 杩愯鏃堕棿 | 2026-10-15 / 2026-10-16 |
| 缁撴灉 | promote+rollback锛坖ournal `SUCCESS` 浜嬪疄锛夈€乣Assembly.RollbackPlugin`锛堟仮澶嶅苟鍦ㄤ綅浠ｅ彲鍐嶆 invoke锛夈€佺敓浜х鐞嗗櫒鍙戝竷澶辫触鍥炴粴锛堝叡浜浠跺**涓や釜**绠＄悊鍣ㄦ柇瑷€锛夈€丄pply 鍙楃鍚岃〃銆侀儴缃茶繘绋嬬敓鍛藉懆鏈?E2E锛坰tep-01..13锛?|
| 涓轰粈涔堟槸濂椾欢椹卞姩 | 娌荤悊 HTTP 闈粎鍦ㄨ閰嶆帶鍒堕潰鏃舵寕杞斤紝涓旂湡瀹炲寘闇€绛惧悕+artifact+淇′换鏍癸紱鑳藉姏鏈韩鍦ㄧ湡瀹?host/journal 涓嬪凡鍙畬鍏ㄨ鐩?|
| 璁板綍 | [examples/plugin-rolling-update-local/](../examples/plugin-rolling-update-local/)锛坈ases 01鈥?4 + RUN-RECORD锛?|

---

## Case R6 鈥?韬唤涓庤鑹插垽瀹氾紙`identity-auth-local`锛屾柊澧烇級

| 椤?| 鍐呭 |
| --- | --- |
| 鐘舵€?| 鉁?宸叉墽琛屽苟閫氳繃锛? 涓満鏅?case锛屽浠堕┍鍔級 |
| 杩愯鏃堕棿 | 2026-10-16 |
| 缁撴灉 | 鏃?閿欏嚟璇?`401`銆佹湰鍦板洖閫€鍙粰鏈€浣庤鑹层€佸鎵圭己鍐崇瓥 `400`锛堜笉榛樿鎵瑰噯锛夈€佹彃浠?toggle 鐣稿舰 body `400`銆佽鑹插眰绾т笌绌?鏈煡瑙掕壊鎷掔粷銆佽法绉熸埛 `404`銆?*杩滅▼鏃犲嚟璇佹嫆缁濆惎鍔?* |
| 璁板綍 | [examples/identity-auth-local/](../examples/identity-auth-local/)锛坈ases 01鈥?3 + RUN-RECORD锛?|

---

## Case R7 — 负载矩阵（`praxovela-e2e`，**已执行 2026-10-16，PASS**）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（共享栈 + N 路并发驱动器；一次启动 AEGIVELA+LIMENORA+PG） |
| 运行时间 | 2026-10-16 |
| 结果 | 档 1/8/32 × 每档 20 回合（20/160/640 样本）：p99 **17.1 / 17.4 / 262.8 ms**、max 451 ms、0 错误/超时、continuation 覆盖 20/20·160/160·640/640；每档 **PASS（p99 < 5s）** |
| 门槛 | 1/8/32 并发档、每档 ≥20 回合、每档 p99 < 5s、报告 workload/load/sample count |
| 证据 | [报告](../../demo-repository/praxovela-e2e/_reports/c7-load-matrix-20261016-212009.json) · [门槛与跑法](../../demo-repository/praxovela-e2e/LOAD-MATRIX.md)（Case C7） |

---

## Case R9 — 业务 demo 实跑尝试：**中断，无结果**（2026-10-16）

| 项 | 内容 |
| --- | --- |
| 尝试 | `examples/order-fulfillment-local/run-all.ps1`（start-services → 场景 → verify） |
| 结果 | 未产生任何结果：启动阶段缺少预构建服务二进制（本次报 `<...>\ONTOVELA\backend\ontovela.exe` 不存在），随后被中断；**不得计入"已运行"** |
| 残留清理 | 已停止本次留下的 `limenora-edge` 进程（pid 24176），无残留监听 |
| 准备条件 | 按各 demo 的 `operations-guide.md` / `start-services.ps1` 先构建所需服务二进制（Ontovela、Rheovela、Symbivela、Moduregis、Praxovela AXON，可选 Orchadyn），并配好 `local.env.ps1` |
| 影响 | 13 个业务 demo 仍为"**可运行但无执行记录**"（见本页 Case R3） |

---

## 如何记录新运行（规范）

1. 运行例子（`run-all.ps1`）或汇总（`scripts/report-value.ps1`）。
2. 在该例子写/更新 `RUN-RECORD.md`，按 case 分节：日期、环境/端口、逐字报告、证明了什么、没证明什么。
3. 回到本页对应 case 补一行（状态/时间/结果/证据位置）。

报告不得总结掉 skip 或 fail；不得引用磁盘上不存在的报告；本地产物放 `examples/_reports/` 或各例子的 `.local-data/`。