# agent-infra hermes 容器（加法路线）
# 基线：fork dev（钉 v0.23.3 已验证版本）瘦身自建镜像 ~470MB
# 加法：非 root 运行、docker exec 降权 shim、/home/hermes/.hermes 卷约定
FROM python:3.14-slim

# ===== 自持依赖仓库（按需覆盖）=====
ARG HERMES_REPO=github.com/kar98knb/hermes-agent
ARG HERMES_BRANCH=dev
ARG UV_INDEX=https://pypi.org/simple

# Debian 源换清华（国内构建免代理；GitHub runner 同样可用）
RUN sed -i "s|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list.d/debian.sources 2>/dev/null || true \
 && apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir uv -i "$UV_INDEX"

# 固定使用基础镜像自带的 python（避免 uv 托管 Python 落在 /root 导致非 root 用户无法执行）
ENV UV_DEFAULT_INDEX=$UV_INDEX \
    UV_PYTHON_PREFERENCE=only-system
WORKDIR /opt/hermes
RUN git clone --depth 1 --branch "$HERMES_BRANCH" "https://${HERMES_REPO}" .
RUN uv sync --frozen --no-dev --extra messaging --extra cron --python /usr/local/bin/python3.14

# 非 root 运行（Hermes 官方约束）+ docker exec 降权 shim
RUN useradd -r -m hermes \
 && mkdir -p /home/hermes/.hermes \
 && chown -R hermes:hermes /home/hermes /opt/hermes \
 && printf '#!/bin/sh\nexec runuser -u hermes -- /opt/hermes/.venv/bin/hermes "$@"\n' > /usr/local/bin/hermes \
 && chmod 0755 /usr/local/bin/hermes

COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 数据卷：hermes 用户 HOME 下的 .hermes（记忆/配置持久化）
VOLUME /home/hermes/.hermes
EXPOSE 8642
ENTRYPOINT ["/entrypoint.sh"]
