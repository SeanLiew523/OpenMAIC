# OpenMAIC 本地补丁说明(基于官方 commit 29735f1,2026-09-10 制作)

补丁文件:`openmaic-local-patches-20260910.patch`(6 文件,+61/-13)

## 当前管理方式(2026-09-10 起):local-patches 分支

全部补丁已提交到本仓库的 **`local-patches` 分支**(commit `0fe3a71`,基于官方 `29735f1`)。
**日常使用请停留在此分支**(当前运行的 dev server 就是这个分支的内容)。

### 官方更新时的标准升级流程

```bash
cd ~/OpenMAIC
git fetch origin
git rebase origin/main        # 在 local-patches 分支上执行
# 有冲突:逐个文件解决(本 README 的清单就是冲突地图),git rebase --continue
pnpm install                  # 若 lockfile 有变
# 然后跑下面的「30 秒回归清单」
```

### 灾难恢复(仓库被删/重克隆时)

```bash
cd ~/OpenMAIC && git checkout -b local-patches
git apply -3 local-patches/openmaic-local-patches-20260910.patch
# 或从仓库外的双保险副本:git apply -3 /Users/seanliew/openmaic-local-patches/openmaic-local-patches-20260910.patch
git add -A && git commit -m "fix: local operation patches (replay)"
```

## 上游回馈状态

| 问题 | 上游链接 | 状态 |
|------|---------|------|
| 测试连接显示 undefined(字段读错) | [issue #1457](https://github.com/THU-MAIC/OpenMAIC/issues/1457) / [PR #1459](https://github.com/THU-MAIC/OpenMAIC/pull/1459) | PR 已提交(2 行修复) |
| interactive 场景 5 分钟超时 | [issue #1458](https://github.com/THU-MAIC/OpenMAIC/issues/1458) | 已报告,等官方定方向 |

**PR 被合并后**:下次 rebase 时对应补丁若冲突,以官方版本为准(官方已修);无冲突也会成为冗余补丁,可在 rebase 时手动剔除该 hunk。

## 补丁内容清单(共 6 项修复)

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| 1 | `components/settings/image-settings.tsx` | 测试连接失败时前端读 `data.message`,服务端返回字段是 `error`,UI 永远显示"连接失败: undefined",真实报错被吞 | 改读 `data.error` |
| 2 | `components/settings/video-settings.tsx` | 同 #1(视频面板同一处笔误) | 改读 `data.error` |
| 3 | `lib/store/settings.ts` `ensureValidProviderSelections` | 空 `imageModelId`/`videoModelId` 一旦持久化(如切到 ComfyUI 等空目录服务商),每次页面加载都不会自愈 → 一切生成/测试报 "No model configured" | rehydrate 时发现空模型自动填该服务商第一个可用模型(只填空,不覆盖已有选择) |
| 4 | `lib/store/settings.ts` `resolveMediaModels` + `components/generation/media-popover.tsx` `providerModels` | 自定义模型与内置模型同 ID 时列表出现重复条目 → React "duplicate key" 报错、选择歧义 | 合并后按 id 去重(保留首个) |
| 5 | `components/settings/image-settings.tsx` + `video-settings.tsx` 测试函数 | 模型 ID 为空时测试请求直接被服务端 400 拒绝 | 空模型时兜底发送 `builtInModels[0]?.id` |
| 6 | `instrumentation.ts` | undici 默认 headersTimeout=300s,非流式 LLM 生成 interactive 场景常超 5 分钟 → "Headers Timeout Error" 死循环重试 | 启动时全局 dispatcher 提到 900s(15 分钟) |
| 7 | `lib/media/adapters/seedream-adapter.ts` `resolveArkRoot` | Base URL 误填完整端点(带 /images/generations)时路径叠成 `/api/v3/images/generations/images/generations` → Ark 404 InvalidAction | 解析时剥掉结尾的 `/images/generations` |

## 升级后 30 秒回归清单(逐条验证补丁仍生效)

1. 图片/视频设置页点「测试连接」→ 断网或填错 key 测试:红字应显示**具体错误**(不是 `undefined`)→ 验证 #1#2
2. DevTools 控制台执行 `JSON.parse(localStorage.getItem('媒体设置存储键'))` 或直接看课件生成:不再报 "No model configured" → 验证 #3
3. 打开首页媒体弹窗:模型列表无重复项、控制台无 duplicate key 报错 → 验证 #4
4. 日志(/tmp/openmaic-dev.log)中 interactive 场景生成可超过 5 分钟不报 Headers Timeout → 验证 #6
5. Seedream Base URL 即使填完整端点,日志中请求路径不重复 → 验证 #7

## 非补丁类配置(升级不受影响,但换浏览器/清缓存会丢)

- GLM(z.ai coding plan):Base URL 必须 `https://api.z.ai/api/coding/paas/v4`,模型 glm-5.3(普通端点上 5.x 报 Insufficient balance,flash 免费但带不动 interactive 场景)
- 火山 Seedream:模型需在方舟控制台逐个「开通」;Base URL 填 `https://ark.cn-beijing.volces.com/api/v3`
- 以上都在浏览器 localStorage 里,服务端 .env.local 为空
