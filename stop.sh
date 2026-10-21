#!/bin/bash
# OpenMAIC 关闭脚本(v1.2.1):网页服务(:3000)→ PostgreSQL 容器
# 用法:终端里运行  ./stop.sh
# Docker Desktop 保持开启(关库不关 Docker);要连 Docker 一起退出,取消最后一行注释
cd "$(dirname "$0")" || exit 1

# ---- 1/2 网页服务 ----
pids=$(lsof -nP -tiTCP:3000 -sTCP:LISTEN 2>/dev/null)
if [ -n "$pids" ]; then
  echo "[1/2] 停止 OpenMAIC(PID:$(echo $pids | tr '\n' ' '))…"
  kill $pids 2>/dev/null
  for i in $(seq 1 15); do
    lsof -nP -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1 || break
    sleep 1
  done
  if lsof -nP -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "      还没退干净,强制结束…"
    kill -9 $(lsof -nP -tiTCP:3000 -sTCP:LISTEN) 2>/dev/null
  fi
  echo "      网页服务已停止"
else
  echo "[1/2] :3000 上没有在跑的服务"
fi

# ---- 2/2 数据库 ----
echo "[2/2] 停止数据库容器(课件数据在卷里,不会丢)…"
pnpm db:down || { echo "✗ 数据库停止失败,把上面的报错发给助手排查"; exit 1; }

echo
echo "✓ 已全部关闭(Docker Desktop 仍开着;要连它一起退出,手动右键菜单栏鲸鱼图标选 Quit,或把本脚本最后一行取消注释)"
# osascript -e 'quit app "Docker"'
