# agent-infra 单容器镜像：Hermes + 自建 ntfy（首启自动初始化认证）
# 依赖全部自持：
#   - Hermes ← 你的 GitHub fork（main 镜像上游，dev 为构建分支）
#   - ntfy   ← 你的 GitHub fork（dev 分支 CI 编译，Release 分发二进制）
# 分支策略详见 README「Fork 分支策略」
FROM python:3.12-slim

# ===== 自持依赖仓库（按需覆盖）=====
ARG HERMES_REPO=github.com/kar98knb/hermes-agent
ARG HERMES_BRANCH=dev
ARG NTFY_REPO=kar98knb/ntfy
ARG NTFY_VER=2.38.1
ARG UV_INDEX=https://pypi.org/simple

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir uv -i "$UV_INDEX"

ENV UV_DEFAULT_INDEX=$UV_INDEX
WORKDIR /opt/hermes
RUN git clone --depth 1 --branch "$HERMES_BRANCH" "https://${HERMES_REPO}" .
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
