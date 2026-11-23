#!/bin/sh
# ntfy 容器入口：认证初始化（幂等）+ 前台运行
# 关键顺序：先起 server 生成 auth.db → user/access CLI（每次都执行，确保重启/重建后状态正确）
set -e

CFG=/etc/ntfy/server.yml
AUTH_FILE=/var/lib/ntfy/auth.db
mkdir -p /etc/ntfy /var/lib/ntfy

if [ -n "$NTFY_USER" ] && [ -n "$NTFY_PASS" ]; then
  cat > "$CFG" <<YAML
listen-http: ":2586"
auth-file: $AUTH_FILE
auth-default-access: deny-all
YAML
else
  cat > "$CFG" <<YAML
listen-http: ":2586"
YAML
  echo "WARNING: 未设置 NTFY_USER/NTFY_PASS，ntfy 以无认证模式运行（公网不推荐）"
fi

# 1. 启动 server（首启生成 auth.db；已存在则直接运行）
ntfy serve &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' TERM INT
sleep 3

# 2. 幂等初始化（每次启动都执行，保证重启/重建后状态一致）
if [ -n "$NTFY_USER" ] && [ -n "$NTFY_PASS" ]; then
  if ! ntfy user list 2>/dev/null | grep -qw "$NTFY_USER"; then
    NTFY_PASSWORD="$NTFY_PASS" ntfy user add "$NTFY_USER" >/dev/null 2>&1 || true
  fi
  ntfy access "$NTFY_USER" "${NTFY_TOPIC:-agent}" read-write 2>/dev/null || true
  echo "=============================================="
  echo " ntfy 就绪: user=$NTFY_USER topic=${NTFY_TOPIC:-agent}"
  echo " Hermes 侧 NTFY_TOKEN 使用 Basic auth: $NTFY_USER:$NTFY_PASS"
  echo " 手机 App: 订阅 ${NTFY_TOPIC:-agent}，登录 $NTFY_USER + 你设的密码"
  echo "=============================================="
fi

# 3. 前台驻留（server 已在后台运行）
wait $SERVER_PID
