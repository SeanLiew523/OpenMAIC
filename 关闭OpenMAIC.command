#!/bin/bash
# 双击运行:关闭 OpenMAIC(网页服务 + 数据库;Docker Desktop 保持开启)
cd "$(dirname "$0")" || exit 1
./stop.sh
rc=$?
echo
if [ $rc -eq 0 ]; then
  echo "✅ 已全部关闭,这个窗口可以关掉了(⌘W)。课件数据保存在数据库卷里,不会丢"
else
  echo "❌ 关闭过程出了问题,把上面窗口截图发给助手排查"
fi
