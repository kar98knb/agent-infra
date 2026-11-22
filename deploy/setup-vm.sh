#!/usr/bin/env bash
# 本地裸机部署脚本（非容器形态，VM 开发环境用）
# 生产部署请用容器版（README「部署」章节）
set -euo pipefail

HERMES_TAG="${HERMES_TAG:-v0.23.3}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> 基础依赖"
sudo apt-get update -qq
sudo apt-get install -y -qq curl git ca-certificates openssl python3 python3-venv

echo "==> uv"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Hermes（上游公开仓库，钉 tag）"
git clone --depth 1 --branch "$HERMES_TAG" https://github.com/NousResearch/hermes-agent "$HERE/hermes-src"
cd "$HERE/hermes-src"
UV_DEFAULT_INDEX="${UV_INDEX:-https://pypi.org/simple}" uv sync --frozen --no-dev --extra messaging --extra cron
ln -sf "$HERE/hermes-src/.venv/bin/hermes" "$HOME/.local/bin/hermes"

echo "==> 配置（按提示填写，或之后用 hermes config set 改）"
hermes config set DEEPSEEK_API_KEY "sk-替换"
hermes config set NTFY_SERVER_URL "https://ntfy.sh"
TOPIC="agent-$(openssl rand -hex 8)"
hermes config set NTFY_TOPIC "$TOPIC"
hermes config set NTFY_ALLOWED_USERS "$TOPIC"
hermes config set platforms.ntfy.enabled true

echo "==> 常驻服务"
hermes gateway install
sudo loginctl enable-linger "$USER"

echo "==> 完成，topic: $TOPIC"
