# 架构

## 组件

| 组件 | 版本 | 来源 |
|---|---|---|
| Hermes Agent | v0.23.3（构建时钉 tag） | NousResearch/hermes-agent 公开仓库 |
| ntfy | 2.38.1（构建时钉版本） | 官方 GitHub Release 单二进制 |
| 基础镜像 | python:3.12-slim | Docker Hub（国内构建可用镜像加速器） |
| LLM | DeepSeek | DEEPSEEK_API_KEY |

## 进程模型（单容器）

entrypoint.sh 负责：
1. 写 ntfy server 配置（有 NTFY_USER/PASS 时启用 auth-file + deny-all）
2. 首次启动自动：建用户 → 授权 topic read-write → 生成 token → **自动注入 Hermes 的 NTFY_TOKEN**
3. 后台拉起 ntfy → `exec hermes gateway run`（Hermes 为 PID 1，信号处理干净）

## 认证模型

- 未认证请求：deny-all（连 topic 是否存在都不可见）
- 手机（人）：Basic auth（NTFY_USER + NTFY_PASS），read-write
- Hermes（机）：access token（自动生成注入），read-write
- topic 名不再承担秘密职责，可随意取名

## 构建链（无墙友好）

- GitHub Actions（runner 海外网络）：官方 PyPI + GitHub 直连
- 本地/国内构建：`--build-arg UV_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple`，hermes/ntfy 拉取走代理
- 产物：`agent-infra-latest.tar`（Release 附件），部署侧只需 `docker load && docker run`

## 通道可替换性

Hermes 平台层即插槽：换 ntfy 服务器（NTFY_SERVER_URL）、加 Telegram/Matrix 等其他平台，都不动镜像结构。
