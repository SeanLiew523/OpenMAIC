# OpenMAIC 本地补丁说明(基于官方 commit 29735f1,2026-09-10 制作)

补丁文件:`openmaic-local-patches-20260910.patch`(6 文件,+61/-13)

## 重新应用方法

```bash
cd ~/OpenMAIC && git apply --check /Users/seanliew/openmaic-local-patches/openmaic-local-patches-20260910.patch  # 先干跑检查
git apply /Users/seanliew/openmaic-local-patches/openmaic-local-patches-20260910.patch
```

若 `git apply` 因官方代码变化失败,改用三路合并(成功率更高):
```bash
git apply -3 /Users/seanliew/openmaic-local-patches/openmaic-local-patches-20260910.patch
```

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
