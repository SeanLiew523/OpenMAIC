#!/bin/bash
# OpenMAIC 启动脚本(v1.2.1):Docker Desktop → PostgreSQL → 网页服务(:3000)
# 用法:终端里运行  ./start.sh
# 服务后台运行,日志在 /tmp/openmaic-dev.log;关闭用 ./stop.sh
cd "$(dirname "$0")" || exit 1
# 双击运行(.command)时 .zshrc 未必加载,把 pnpm 等所在目录追加为兜底
# (追加而非前置:避免压过 .zshrc 里配置的新版 node)
export PATH="$PATH:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin"

# ---- 1/3 Docker ----
docker_procs() { pgrep -f "/Applications/Docker.app" 2>/dev/null | wc -l | tr -d ' '; }

if docker info >/dev/null 2>&1; then
  echo "[1/3] Docker 已在运行"
else
  echo "[1/3] Docker 未运行,准备启动 Docker Desktop…"

  # 上一次 Docker Desktop 可能还在退出中:此时 open 会转交给垂死的旧实例而被"吞掉"。
  # 先等旧进程退干净;超过 40 秒还在就强制结束(守护进程已停,强杀安全)。
  if [ "$(docker_procs)" -gt 0 ]; then
    echo "      检测到旧的 Docker Desktop 正在退出,等它退干净…"
    for i in $(seq 1 20); do
      [ "$(docker_procs)" -eq 0 ] && break
      sleep 2
    done
    if [ "$(docker_procs)" -gt 0 ]; then
      echo "      40 秒还没退完,强制结束残留进程…"
      pkill -9 -f "/Applications/Docker.app" 2>/dev/null
      sleep 3
    fi
  fi

  # 启动应用,并确认进程真的出现(最多重试 3 次)
  launched=""
  for round in 1 2 3; do
    open -a Docker 2>/dev/null || open -a "Docker Desktop" 2>/dev/null
    for i in $(seq 1 8); do
      if [ "$(docker_procs)" -gt 0 ]; then launched=1; break; fi
      sleep 2
    done
    [ -n "$launched" ] && break
    echo "      第 $round 次启动没看到 Docker 进程,再试一次…"
    sleep 3
  done
  if [ -z "$launched" ]; then
    echo "✗ 反复启动都没拉起 Docker Desktop 进程。请在启动台/应用程序里"
    echo "  手动双击 Docker,看到窗口后再运行一次本脚本。"
    exit 1
  fi

  # 等引擎就绪:冷启动一般 30~90 秒,给足 4 分钟;进程若中途消失则重新拉起
  echo "      等 Docker 引擎就绪(一般 30~90 秒)…"
  ready=""
  for i in $(seq 1 120); do
    if docker info >/dev/null 2>&1; then ready=1; break; fi
    if [ "$i" -gt 10 ] && [ "$(docker_procs)" -eq 0 ]; then
      echo "      Docker 进程中途退出了,重新拉起…"
      open -a Docker 2>/dev/null || open -a "Docker Desktop" 2>/dev/null
    fi
    if [ $((i % 5)) -eq 0 ]; then
      echo "      … 已等待 $((i * 2)) 秒"
    fi
    sleep 2
  done
  if [ -z "$ready" ]; then
    echo "✗ 等了 4 分钟 Docker 引擎还没就绪。请手动检查:"
    echo "  1. 菜单栏鲸鱼图标点开,看有没有弹窗等你确认(服务条款/更新/登录)"
    echo "  2. 打开 Docker Desktop 主窗口,等它左下角变成绿色再跑一次本脚本"
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
