#!/bin/bash
# OpenMAIC 启动脚本(v1.2.1):Docker Desktop → PostgreSQL → 网页服务(:3000)
# 用法:终端里运行  ./start.sh
# 服务后台运行,日志在 /tmp/openmaic-dev.log;关闭用 ./stop.sh
cd "$(dirname "$0")" || exit 1
# 双击运行(.command)时 .zshrc 未必加载,显式补齐 pnpm 等的搜索路径
export PATH="$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# ---- 1/3 Docker ----
if docker info >/dev/null 2>&1; then
  echo "[1/3] Docker 已在运行"
else
  echo "[1/3] Docker 未运行,正在启动 Docker Desktop(冷启动可能要 30~60 秒)…"
  open -a Docker
  ok=""
  for i in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then ok=1; break; fi
    sleep 2
  done
  if [ -z "$ok" ]; then
    echo "✗ 等了 2 分钟 Docker 还没就绪。请手动打开 Docker Desktop,"
    echo "  等菜单栏鲸鱼图标稳定后再运行一次本脚本。"
    exit 1
  fi
  echo "      Docker 已就绪"
fi

# ---- 2/3 PostgreSQL ----
echo "[2/3] 启动数据库容器(db:up 会等它健康检查通过)…"
pnpm db:up || { echo "✗ 数据库启动失败,把上面的报错发给助手排查"; exit 1; }

# ---- 3/3 网页服务 ----
if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[3/3] :3000 已有服务在跑,跳过(想重启请先 ./stop.sh)"
  echo
  echo "✓ OpenMAIC 可用:http://localhost:3000"
  exit 0
fi

echo "[3/3] 启动 OpenMAIC(后台运行,日志 /tmp/openmaic-dev.log)…"
nohup pnpm dev > /tmp/openmaic-dev.log 2>&1 &

for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://localhost:3000/ 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo
    echo "✓ OpenMAIC 已就绪:http://localhost:3000"
    exit 0
  fi
  sleep 2
done

echo "✗ 服务 2 分钟内没有响应,看看日志:tail -50 /tmp/openmaic-dev.log"
exit 1
