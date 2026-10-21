#!/bin/bash
# 双击运行:启动 OpenMAIC(Docker → 数据库 → :3000 网页服务)
cd "$(dirname "$0")" || exit 1
./start.sh
rc=$?
echo
if [ $rc -eq 0 ]; then
  echo "✅ 完成。页面已在浏览器打开(http://localhost:3000),这个窗口可以关掉了(⌘W)"
else
  echo "❌ 启动出了问题,把上面窗口截图发给助手排查"
fi
