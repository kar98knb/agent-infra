# agent-infra 单容器镜像：Hermes + 自建 ntfy（首启自动初始化认证）
# 依赖全部自持：
#   - Hermes ← 你的 GitHub fork（完整源码，可改可推，构建时钉 tag/分支）
#   - ntfy   ← 你的 ntfy-bin 二进制镜像仓库
FROM python:3.12-slim

# ===== 自持依赖仓库（按需覆盖）=====
ARG HERMES_REPO=github.com/YOURNAME/hermes-agent
ARG HERMES_TAG=v0.23.3
ARG NTFY_REPO=YOURNAME/ntfy
ARG NTFY_VER=2.38.1
ARG UV_INDEX=https://pypi.org/simple

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir uv -i "$UV_INDEX"

ENV UV_DEFAULT_INDEX=$UV_INDEX
WORKDIR /opt/hermes
RUN git clone --depth 1 --branch "$HERMES_TAG" "https://${HERMES_REPO}" .
RUN uv sync --frozen --no-dev --extra messaging --extra cron

# ntfy 二进制来自 fork 的 Release（由 fork 内 Actions 从源码编译产出）
RUN curl -fsSL "https://github.com/${NTFY_REPO}/releases/download/v${NTFY_VER}/ntfy_${NTFY_VER}_linux_amd64.tar.gz" \
 | tar xz -C /usr/local/bin ntfy \
 && chmod +x /usr/local/bin/ntfy \
 && ntfy --version

COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2586 8642
ENTRYPOINT ["/entrypoint.sh"]
