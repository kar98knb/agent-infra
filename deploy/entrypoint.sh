#!/bin/sh
# 单容器入口：拉起自建 ntfy（可选自动认证）+ Hermes 网关
# 关键顺序：先起 server 生成 auth.db → 再执行用户/授权/token CLI → 最后以非 root 用户运行 Hermes
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

# 1. 先启动 server（首启会生成 auth.db）
ntfy serve &
sleep 3

# 2. 认证初始化（auth.db 存在后 CLI 才可用）
if [ -n "$NTFY_USER" ] && [ -n "$NTFY_PASS" ]; then
  if ! ntfy user list 2>/dev/null | grep -qw "$NTFY_USER"; then
    NTFY_PASSWORD="$NTFY_PASS" ntfy user add "$NTFY_USER" >/dev/null 2>&1 || true
    ntfy access "$NTFY_USER" "${NTFY_TOPIC:-agent}" read-write 2>/dev/null || true
    TOKEN=$(ntfy token add "$NTFY_USER" 2>/dev/null | grep -oE 'tk_[A-Za-z0-9]+' | head -1 || true)
    export NTFY_TOKEN="$TOKEN"
    echo "=============================================="
    echo " ntfy 认证已初始化: user=$NTFY_USER topic=${NTFY_TOPIC:-agent}"
    echo " Hermes token: $TOKEN (已自动注入)"
    echo " 手机 App: 订阅 ${NTFY_TOPIC:-agent}，登录 $NTFY_USER + 你设的密码"
    echo "=============================================="
  fi
fi

# 3. Hermes 以非 root 运行（Hermes 官方镜像要求）
export NTFY_SERVER_URL="${NTFY_SERVER_URL:-http://127.0.0.1:2586}"
export NTFY_ALLOWED_USERS="${NTFY_ALLOWED_USERS:-$NTFY_TOPIC}"
exec runuser -u hermes -- /opt/hermes/.venv/bin/hermes gateway run
