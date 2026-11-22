#!/bin/sh
# 单容器入口：拉起自建 ntfy（可选自动认证）+ Hermes 网关
set -e

AUTH_FILE=/var/lib/ntfy/auth.db
CFG=/var/lib/ntfy/server.yml
mkdir -p /var/lib/ntfy

if [ -n "$NTFY_USER" ] && [ -n "$NTFY_PASS" ]; then
  cat > "$CFG" <<YAML
listen-http: ":2586"
auth-file: $AUTH_FILE
auth-default-access: deny-all
YAML
  if ! ntfy --auth-file "$AUTH_FILE" user list 2>/dev/null | grep -qw "$NTFY_USER"; then
    printf '%s\n%s\n' "$NTFY_PASS" "$NTFY_PASS" | ntfy --auth-file "$AUTH_FILE" user add "$NTFY_USER" >/dev/null 2>&1 || true
    ntfy --auth-file "$AUTH_FILE" access "$NTFY_USER" "${NTFY_TOPIC:-agent}" read-write 2>/dev/null || true
    TOKEN=$(ntfy --auth-file "$AUTH_FILE" token add "$NTFY_USER" 2>/dev/null | grep -oE 'tk_[A-Za-z0-9]+' | head -1 || true)
    export NTFY_TOKEN="$TOKEN"
    echo "=============================================="
    echo " ntfy 认证已初始化: user=$NTFY_USER topic=${NTFY_TOPIC:-agent}"
    echo " Hermes token: $TOKEN (已自动注入)"
    echo " 手机 App: 订阅 ${NTFY_TOPIC:-agent}，登录 $NTFY_USER + 你设的密码"
    echo "=============================================="
  fi
else
  cat > "$CFG" <<YAML
listen-http: ":2586"
YAML
  echo "WARNING: 未设置 NTFY_USER/NTFY_PASS，ntfy 以无认证模式运行（公网不推荐）"
fi

ntfy serve --config "$CFG" &
sleep 2

export NTFY_SERVER_URL="${NTFY_SERVER_URL:-http://127.0.0.1:2586}"
export NTFY_ALLOWED_USERS="${NTFY_ALLOWED_USERS:-$NTFY_TOPIC}"
exec /opt/hermes/.venv/bin/hermes gateway run
