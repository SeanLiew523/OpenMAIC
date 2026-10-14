# OpenMAIC 本地补丁说明

> **2026-10-14 已升级到官方 v1.1.4**(rebase --onto v1.1.4,带入 1.1.2/1.1.3/1.1.4 三个安全版本;无冲突,补丁零退役)。
> 此前:**2026-09-28 升级到 v1.1.1**(rebase 自 a686481e),补丁已随之精简。
> 本目录 = 仓库内提交的副本(随 `local-patches` 分支走),patch 文件始终基于当时最新上游重新生成。
> **基线注意**:从 v1.1.4 起,基线不再是 `origin/main` 而是稳定版标签 `v1.1.4`(release/1.1.x 线)。main 上 1.2.0 起强制 PostgreSQL、架构重写,暂不跟随。

## 补丁现状(v1.1.4 之后:5 项全部保留,本轮无退役)

| # | 文件 | 问题 | 状态 |
|---|------|------|------|
| ①② | image/video-settings.tsx 读 `data.error` | 测试连接显示 `undefined` | ✅ **官方已修**(PR #1459 合入),本地补丁退役 |
| ⑥ | instrumentation.ts undici 15 分钟超时 | interactive 场景撞 5 分钟超时 | ✅ **官方已修**(#1404,`LLM_FETCH_TIMEOUT_MS`=15min),本地补丁退役 |
| ③ | settings.ts `ensureValidProviderSelections` 空模型自愈 | "No model configured" 永久卡死 | **保留**(上游仍只校验 provider 不校验 model) |
| ④ | settings.ts `resolveMediaModels` 按 id 去重 | 重复模型条目 / React duplicate key | **保留**(上游仍不去重;v1.1.1 已删除 media-popover.tsx,新 UI `course-model-config.tsx` 同样不去重,如遇重复条目需给新文件补) |
| ⑤ | image/video-settings.tsx 测试按钮兜底 `builtInModels[0]` | 空模型时测试直接 400 | **保留** |
| ⑦ | seedream-adapter.ts `resolveArkRoot` 剥完整端点 | Base URL 粘成完整端点→路径重复 404 | **保留**(与官方新增的 `/v\d+` 判断已合并) |
| ⑧ | ssrf-guard.ts:198.18.0.0/15 改为受 `ALLOW_LOCAL_NETWORKS` 管辖 | 本机代理 Fake-IP DNS 把所有公网域名解析到该段→守卫无条件拒绝→**所有服务商调用全断** | **保留**(v1.1.2 安全修复只新增了 `validateClientBaseUrl`,未动该段的判定;`.env.local` 已设 `ALLOW_LOCAL_NETWORKS=true`;配套调整了 3 个 ssrf 测试断言) |

## v1.1.2–1.1.4 带来的行为变化(与本机相关)

- Provider 请求改走严格传输(pinned connection):DNS 解析结果钉死、拒绝重定向。本机 fake-IP 代理走系统 TUN 路由,不受影响;但若曾依赖 `HTTP_PROXY` 环境变量转发 provider 请求,现在**不会**再走(1.1.2 起 pinned 请求直连)。
- 手填的 Provider Base URL 含查询串/`#` 会被拒(`validateClientBaseUrl`);手填 URL 上游重定向会被拒——填最终地址。
- 上游错误不再透传给前端(固定文案),「测试连接」红字变笼统是预期行为,排查要看服务端日志。
- 课件文档读写均消毒 HTML(1.1.3 XSS 修复);已删课程不再提供媒体文件;服务端托管 provider 按 `*_MODELS` 授权(本机用浏览器自配 key,不受限)。

## 日常使用

- **停留在 `local-patches` 分支**(当前 dev server 跑的就是它)
- 云端备份:`git push fork local-patches`(fork = github.com/SeanLiew523/OpenMAIC)

## 官方更新时的标准升级流程

```bash
cd ~/OpenMAIC
git fetch origin --tags
# 只重放本地提交到新基线(直接 rebase origin/main 会把 main 线提交一起重放,务必用 --onto):
git rebase --onto <新基线标签或提交> <旧基线,见 git merge-base HEAD v旧标签> local-patches
# 例(2026-10-14):git rebase --onto v1.1.4 a686481e local-patches
# 冲突按本 README 的清单判断:官方已修的→删我方;未修的→保我方;双方都改的→合并
pnpm install                  # lockfile 有变时
# 跑下面的回归清单
git diff <新基线> HEAD -- components lib instrumentation.ts > local-patches/openmaic-local-patches.patch
git add -A && git commit -m "docs(local-patches): refresh patch file and status"
git push --force-with-lease fork local-patches   # rebase 改写历史,需强推
```

> 选基线:稳定版跟 1.1.x 标签(如 `v1.1.4`,在 release/1.1.x 线上,不在 main);
> main 已进入 1.2.0(server-first 重写,强制 PostgreSQL),迁移前不要 rebase 上去。

## 升级后回归清单(每条 ~30 秒)

1. 图片/视频设置页:填错 key 点「测试连接」→ 红字显示**具体上游错误**(非 `undefined`)
2. 课件生成:不再报 "No model configured"
3. 模型列表无重复条目、控制台无 duplicate key
4. interactive 场景生成可超过 5 分钟(日志无 Headers Timeout;官方上限 15 分钟)
5. Seedream Base URL 粘完整端点,日志中请求路径不重复

## 灾难恢复(整库丢失时)

```bash
git clone -b local-patches https://github.com/SeanLiew523/OpenMAIC.git OpenMAIC
cd OpenMAIC && pnpm install && pnpm dev
```

## 非补丁类配置(升级不受影响,但换浏览器/清缓存会丢)

- GLM(z.ai coding plan):Base URL `https://api.z.ai/api/coding/paas/v4`,模型 glm-5.3
- 火山 Seedream:模型需在方舟控制台逐个开通;Base URL `https://ark.cn-beijing.volces.com/api/v3`
- 以上均存浏览器 localStorage;服务端 .env.local 为空
