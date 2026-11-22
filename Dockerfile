# agent-infra 单容器镜像：Hermes + 自建 ntfy（首启自动初始化认证）
# 构建全程不依赖 Docker Hub 之外的任何私有资产：
#   - Hermes 从上流公开仓库按 tag 拉取（ARG HERMES_TAG，默认 v0.23.3）
#   - ntfy 从官方 GitHub Release 下载（ARG NTFY_VER，默认 2.38.1）
#   - PyPI 索引可用 UV_INDEX 覆盖（国内构建传清华镜像即可）
FROM python:3.12-slim

ARG HERMES_TAG=v0.23.3
ARG NTFY_VER=2.38.1
ARG UV_INDEX=https://pypi.org/simple

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir uv -i "$UV_INDEX"

ENV UV_DEFAULT_INDEX=$UV_INDEX
WORKDIR /opt/hermes
RUN git clone --depth 1 --branch "$HERMES_TAG" https://github.com/NousResearch/hermes-agent .
RUN uv sync --frozen --no-dev --extra messaging --extra cron

RUN curl -fsSL "https://github.com/binwiederhier/ntfy/releases/download/v${NTFY_VER}/ntfy_${NTFY_VER}_linux_amd64.tar.gz" \
  | tar xz -C /usr/local/bin ntfy && chmod +x /usr/local/bin/ntfy

COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2586 8642
ENTRYPOINT ["/entrypoint.sh"]
