# agent-infra

个人常驻 AI agent 单容器镜像：**Hermes Agent + 自建 ntfy + 自动认证**。

> 依赖全部自持：Hermes 走你的 GitHub fork（完整源码，改代码推分支即可用），
> ntfy 走 `ntfy-bin` 二进制镜像仓库——构建不依赖任何上游仓库在线状态。

## 仓库结构

| 仓库 | 内容 |
|---|---|
| `agent-infra`（本仓库） | Dockerfile、CI 流水线、入口脚本、文档 |
| `hermes-agent`（fork 自 NousResearch/hermes-agent） | 完整源码 + 全量 tag，想改就改 |
| `ntfy`（fork 自 binwiederhier/ntfy） | Go 源码 + `deploy/ntfy-fork-build.yml` 编译发版，想改就改 |

## 架构

```
手机 (ntfy App) ──HTTP──> [容器]
                           ├─ ntfy（自建 :2586，deny-all + 账号认证）
                           └─ Hermes Gateway（订阅/发布 ntfy，24/7）
                                ↕ API
                          DeepSeek（LLM）
```

## 部署（docker load + docker run 两步）

```bash
# 1. 加载镜像（tar 从 GitHub Release 下载，经宿主机中转或直连）
docker load < agent-infra-latest.tar

# 2. 运行
docker run -d --name agent \
  -p 2586:2586 \
  --restart unless-stopped \
  -e DEEPSEEK_API_KEY=sk-xxx \
  -e NTFY_TOPIC=agent \
  -e NTFY_USER=kar98k -e NTFY_PASS=你的密码 \
  -v agent-home:/root/.hermes \
  agent-infra:latest
```

- 首次启动自动初始化 ntfy 认证（deny-all 策略），Hermes token 自动生成并注入，日志中打印
- 手机 App：服务器 `http://<服务器IP>:2586`，订阅 `agent`，登录 `kar98k` + 密码
- 不设 NTFY_USER/NTFY_PASS 则以无认证模式运行（仅限内网）

## 构建 / 发版（GitHub Actions 自动）

推 tag（`v*`）或在 Actions 页手动触发 → 自动构建并产出 `agent-infra-latest.tar` 挂到 Release / Artifact。

本地构建：

```bash
docker build \
  --build-arg UV_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple \
  -t agent-infra:latest .
```

## 配置参考

| 环境变量 | 必填 | 说明 |
|---|---|---|
| `DEEPSEEK_API_KEY` | ✅ | LLM Key |
| `NTFY_TOPIC` | ✅ | 频道名（认证保护，可随意取） |
| `NTFY_USER` / `NTFY_PASS` | 推荐 | 手机登录账号；不设 = 无认证 |
| `NTFY_TOKEN` | 自动 | 首启自动生成并注入 Hermes |

## 安全底线

- `.env`/密钥永不入库
- 公网部署务必设置 NTFY_USER/NTFY_PASS
- 镜像内 ntfy 端口 2586 为非标端口，如需 HTTPS 可在前面挂反代
