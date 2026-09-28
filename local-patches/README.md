# OpenMAIC 本地补丁说明

> **2026-09-28 已升级到官方 v1.1.1**(rebase 自 a686481e),补丁已随之精简。
> 本目录 = 仓库内提交的副本(随 `local-patches` 分支走),patch 文件始终基于当时最新上游重新生成。

## 补丁现状(v1.1.1 之后:4 项保留,2 项已退役)

| # | 文件 | 问题 | 状态 |
|---|------|------|------|
| ①② | image/video-settings.tsx 读 `data.error` | 测试连接显示 `undefined` | ✅ **官方已修**(PR #1459 合入),本地补丁退役 |
| ⑥ | instrumentation.ts undici 15 分钟超时 | interactive 场景撞 5 分钟超时 | ✅ **官方已修**(#1404,`LLM_FETCH_TIMEOUT_MS`=15min),本地补丁退役 |
| ③ | settings.ts `ensureValidProviderSelections` 空模型自愈 | "No model configured" 永久卡死 | **保留**(上游仍只校验 provider 不校验 model) |
| ④ | settings.ts `resolveMediaModels` 按 id 去重 | 重复模型条目 / React duplicate key | **保留**(上游仍不去重;v1.1.1 已删除 media-popover.tsx,新 UI `course-model-config.tsx` 同样不去重,如遇重复条目需给新文件补) |
| ⑤ | image/video-settings.tsx 测试按钮兜底 `builtInModels[0]` | 空模型时测试直接 400 | **保留** |
| ⑦ | seedream-adapter.ts `resolveArkRoot` 剥完整端点 | Base URL 粘成完整端点→路径重复 404 | **保留**(与官方新增的 `/v\d+` 判断已合并) |

## 日常使用

- **停留在 `local-patches` 分支**(当前 dev server 跑的就是它)
- 云端备份:`git push fork local-patches`(fork = github.com/SeanLiew523/OpenMAIC)

## 官方更新时的标准升级流程

```bash
cd ~/OpenMAIC
git fetch origin
git rebase origin/main        # 在 local-patches 分支上
# 冲突按本 README 的清单判断:官方已修的→删我方;未修的→保我方;双方都改的→合并
pnpm install                  # lockfile 有变时
# 跑下面的回归清单
git diff origin/main HEAD -- components lib instrumentation.ts > local-patches/openmaic-local-patches.patch
git add -A && git commit -m "docs(local-patches): refresh patch file and status"
git push fork local-patches
```

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
