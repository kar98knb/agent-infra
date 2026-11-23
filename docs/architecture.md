# 架构

## 组件

| 组件 | 版本 | 来源 |
|---|---|---|
| Hermes Agent | fork dev 分支（上游 v0.23.x 主干） | kar98knb/hermes-agent，**上游 Dockerfile** 构建 |
| ntfy | 2.38.1 | kar98knb/ntfy fork CI 编译二进制 → alpine 镜像 |
| 基础镜像 | python:3.14-slim（hermes）/ alpine:3.20（ntfy） | Docker Hub |
| LLM | DeepSeek | DEEPSEEK_API_KEY |

## 进程模型（双容器）

```
ntfy 容器（agent-ntfy）
  └─ ntfy-entrypoint.sh：
      1. 写 /etc/ntfy/server.yml（auth-file + deny-all）
      2. 启动 server（首启生成 auth.db，已存在则直接运行）→ 幂等校验/创建 user + access
      3. 前台驻留；auth.db 持久化于 ntfy-auth 卷

hermes 容器（agent-hermes，上游镜像）
  └─ 上游镜像体系：s6-overlay 监管、HERMES_HOME=/opt/data 单卷持久化、
     docker exec 自动降权、amd64+arm64、内置 Chromium
```

## 认证模型

- 未认证请求：deny-all（连 topic 是否存在都不可见）
- 手机（人）：Basic auth（NTFY_USER + NTFY_PASS），read-write
- Hermes（机）：同账号 Basic auth（compose 里 NTFY_TOKEN=user:pass 注入）——不依赖 token 生成/传递，重启/重建零状态问题
- topic 名不承担秘密职责，可随意取名

## 构建链

- GitHub Actions：clone fork dev → 上游 Dockerfile 构建 hermes 镜像；Dockerfile.ntfy 构建 ntfy 镜像
- 产物：`agent-hermes-latest.tar` + `agent-ntfy-latest.tar`（Release 附件）
- 部署侧：`docker load` ×2 + `compose up`，无需 Docker Hub/GitHub 在线

## 通道可替换性

Hermes 平台层即插槽：换 ntfy 服务器（NTFY_SERVER_URL）、加其他平台插件，都不动镜像结构。
