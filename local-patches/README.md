# OpenMAIC 本地补丁说明

> **2026-10-21 已升级到官方 v1.2.1**(server-first 架构;rebase --onto v1.2.1,补丁③④⑤退役,⑦⑧保留)。
> 此前:2026-10-14 升到 v1.1.4;2026-09-28 升到 v1.1.1。
> **v1.2.x 是架构重写**:课程/模型配置/key 全部搬服务端,强制 PostgreSQL,浏览器只是客户端。
> 本目录 = 仓库内提交的副本(随 `local-patches` 分支走),patch 文件始终基于当前基线重新生成。

## 补丁现状(v1.2.1 基线:2 项保留,3 项退役)

| # | 文件 | 问题 | 状态 |
|---|------|------|------|
| ③ | settings.ts 空模型自愈 | "No model configured" 卡死 | ❌ **退役**(客户端 settings store 已被服务端模型配置取代,原代码不复存在) |
| ④ | settings.ts 模型按 id 去重 | 重复模型条目 | ❌ **退役**(同上;服务端配置如遇重复需在新代码路径观察) |
| ⑤ | image/video-settings.tsx 测试按钮兜底 | 空模型时测试 400 | ❌ **退役**(UI 整体重写;新 UI 行为如有问题另行补) |
| ⑦ | seedream-adapter.ts `resolveArkRoot` 剥完整端点 | Base URL 粘成完整端点→路径重复 404 | ✅ **保留**(对 v1.2.1 的文件可原样套用,零冲突) |
| ⑧ | ssrf-guard.ts:198.18.0.0/15 改受 `ALLOW_LOCAL_NETWORKS` 管辖 | 本机代理 Fake-IP DNS 把公网域名全解析到该段→守卫拒绝→所有服务商调用全断 | ✅ **保留**(原样套用零冲突;56 个 ssrf 测试全过;`.env.local` 已设 `ALLOW_LOCAL_NETWORKS=true`) |

### ⑧ 在 v1.2.x 的新注意点

v1.2.1 给"客户端自填端点"(BYOK)加了**严格公网策略**:用户在设置界面自填的 Base URL,
私有段(含 fake-IP 段)会被拒,且 `ALLOW_LOCAL_NETWORKS` **不解锁**该路径。
因此 GLM/Seedream 等 provider 要配成**服务端管理**(写 `.env.local` 的 `*_API_KEY/`*_BASE_URL/`*_MODELS`,
当前就是这么做),不要在网页设置里以用户身份自填端点,否则会被严格策略拦。

### v1.2.x 对本机的行为变化(重要)

- **数据在服务端**:课件、聊天、模型设置导入 PostgreSQL;浏览器旧数据在升级后**首次用原浏览器打开 localhost:3000** 时一次性自动导入(每浏览器一次)。本机课件原本全在浏览器里(Dia),没有 `data/classrooms` 可迁。
- **必须 PostgreSQL**:本机用 `docker-compose.db.yml`(`pnpm db:up`),`DATABASE_URL=postgres://openmaic:openmaic-dev@127.0.0.1:5432/openmaic`,单用户模式 `OWNER_SINGLE_USER=true`。
- **key 加密存服务端**(`OPENMAIC_SECRET_KEY` 已生成,与数据库备份同存)。
- **模型授权**:服务端凭据必须配 `*_MODELS` 列表,否则启动日志警告、模型被拒(浏览器自带的 key 不受限,但走严格公网策略,见上)。
- 课堂聊天只走 Pi,要求模型支持工具调用(glm-5.3 满足);`NEXT_PUBLIC_PI_CHAT_ENABLED` 必须保持未设置。
- 升级前的完整备份在 `~/OpenMAIC-backups/pre-1.2-migration-20261021/`(含浏览器存储原件、提取的模型配置 model-config-clean.json、旧 .env.local、git tag `pre-1.2-migration`)。

## 日常使用

- **停留在 `local-patches` 分支**
- **启动/关闭:Finder 里双击项目文件夹下的 `启动OpenMAIC.command` / `关闭OpenMAIC.command`**(弹出终端窗口自动跑,⌘W 关窗);启动成功会**自动用默认浏览器打开 http://localhost:3000**;终端手动跑 `./start.sh` / `./stop.sh` 等价。start 自动按序:Docker Desktop 没开会先拉起(含退出残留等待/启动重试)→ PostgreSQL 容器 → :3000 网页服务后台运行(日志 /tmp/openmaic-dev.log);stop 停服务 + 停库(数据在卷里不丢,Docker Desktop 保持开启)
- 手动等价操作:数据库 `pnpm db:up` / `pnpm db:down`,服务 `pnpm dev`(:3000)
- 云端备份:`git push --force-with-lease fork local-patches`(fork = github.com/SeanLiew523/OpenMAIC;rebase 改写历史需强推)

## 官方更新时的标准升级流程

```bash
cd ~/OpenMAIC
git fetch origin --tags
# 只重放本地提交到新基线(务必 --onto,直接 rebase origin/main 会把 main 线提交一起重放):
git rebase --onto <新基线标签> <旧基线标签> local-patches
# 例(2026-10-21):git rebase --onto v1.2.1 v1.1.4 local-patches
# 冲突原则:官方已修/已重写的→checkout --ours(采纳上游);补丁仍需要的→保留我方
pnpm install
pnpm vitest run tests/server/ssrf-guard.test.ts   # ⑧ 的回归
# 数据库大版本升级另行处理(compose 里 postgres:16,数据卷独立)
git diff <新基线> HEAD -- components lib instrumentation.ts > local-patches/openmaic-local-patches.patch
git add -A && git commit -m "docs(local-patches): refresh patch file and status"
git push --force-with-lease fork local-patches
```

> 基线选择:1.2.x 跟 main 线标签(如 v1.2.1)。若上游再出 1.2.2,直接 `--onto v1.2.2 v1.2.1`。

## 升级后回归清单

1. `pnpm vitest run tests/server/ssrf-guard.test.ts` 全过(56 个)
2. 服务启动日志无 "no explicit model list" 类警告(服务端凭据的 provider 都要 `*_MODELS`)
3. 浏览器(原 Dia)打开 localhost:3000 → 课件/模型设置自动导入,课件列表完整
4. GLM 对话正常;Seedream 生图正常(日志路径无重复);fake-IP 代理下所有服务商可调用
5. Seedream Base URL 粘完整端点时,日志中请求路径不重复(⑦)
6. 课堂聊天选 glm-5.3(Classroom 槽位),Pi 正常出话

## 灾难恢复(整库丢失时)

```bash
git clone -b local-patches https://github.com/SeanLiew523/OpenMAIC.git OpenMAIC
cd OpenMAIC && pnpm install && pnpm db:up && pnpm dev
# .env.local 与浏览器数据备份见 ~/OpenMAIC-backups/(模型配置可对照 model-config-clean.json 手工重填)
# 浏览器旧数据导入是一次性的:换浏览器/清缓存后,旧的本地课件不会再导入,只能靠 .maic.zip 导出件恢复
```

## 服务端 .env.local 里的模型配置(2026-10-21 从浏览器备份迁移)

- GLM:`https://api.z.ai/api/coding/paas/v4`,glm-5.3
- Seedream:`https://ark.cn-beijing.volces.com/api/v3`,doubao-seedream-5-0-260128
- Seedance:火山方舟,doubao-seedance-2-0-260128
- TTS/ASR:qwen3-tts-flash / qwen3-asr-flash;搜索:tavily/exa/brave;文档:mineru-cloud
- 明文在 `.env.local`(0600);备份同 `~/OpenMAIC-backups/`。浏览器自填端点走严格公网策略,勿用。
