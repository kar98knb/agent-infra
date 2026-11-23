# agent-infra

个人常驻 AI agent 部署：**Hermes Agent（自建瘦身镜像，fork dev @v0.23.3 已验证基线）+ 自建 ntfy（账号认证）**，双容器编排。

> 依赖全部自持：Hermes 走你的 GitHub fork（dev 分支，钉 v0.23.3），
> ntfy 走你的 fork（CI 编译二进制）——构建不依赖任何上游仓库在线状态。
> 镜像路线：加法路线——467MB 基线 + 非 root 运行 + exec 降权 shim + 卷约定，
> 不引入上游全家桶（Chromium/前端等）。

## 仓库结构

| 仓库 | 内容 |
|---|---|
| `agent-infra`（本仓库） | CI 流水线、compose、ntfy 认证容器、文档 |
| `hermes-agent`（fork 自 NousResearch/hermes-agent） | 完整源码，main 跟上游镜像，dev 为构建分支 |
| `ntfy`（fork 自 binwiederhier/ntfy） | Go 源码，main 跟上游镜像，dev 为构建分支（含编译流水线） |

## Fork 分支策略

两个 fork 采用同一约定：

- **main**：保持与上游仓库镜像一致，随时 `git fetch upstream && git rebase/merge` 跟进社区
- **dev**：生产构建分支 = main + 一个「移除无关目录」的提交（tests/website/docs 等），构建快、改动小
- 改代码：在 dev（或从 dev 拉出的功能分支）上改 → 推 dev → 重新构建镜像

## 架构

```
手机 (ntfy App) ──HTTP :2586──> [ntfy 容器]      ← deny-all + 账号认证（auth.db 持久化于卷）
                                    ↕ 容器内网
                               [hermes 容器]      ← 自建瘦身镜像（非 root + exec 降权 shim + 单卷）
                                    ↕ API
                              DeepSeek（LLM）
```

## 部署（docker load ×2 + compose up）

```bash
# 1. 从 GitHub Release 下载两个 tar 并加载（经宿主机中转或直连）
docker load < agent-hermes-latest.tar
docker load < agent-ntfy-latest.tar

# 2. 配置
cp .env.example .env   # 填 DEEPSEEK_API_KEY / NTFY_TOPIC / NTFY_USER / NTFY_PASS

# 3. 起服务
docker compose up -d

# 4. 启用 ntfy 平台（一次性；官方镜像的 exec 自动降权到 hermes 用户）
docker compose exec hermes hermes config set platforms.ntfy.enabled true
docker compose restart hermes
```

- 手机 App：服务器 `http://<服务器IP>:2586`，订阅 `NTFY_TOPIC`，登录 `NTFY_USER` + `NTFY_PASS`
- 数据持久化：hermes 记忆/配置在 `hermes-home` 卷（/home/hermes/.hermes），ntfy 账号在 `ntfy-auth` 卷
- 重启、重建容器均安全（ntfy 认证初始化幂等，每次启动校验 user/access）
- `docker compose exec hermes hermes ...` 自动降权（镜像内置 shim）
- 公网部署建议前置 HTTPS 反代（2586 为明文 Basic auth）

## 构建 / 发版（GitHub Actions 自动）

推 tag（`v*`）或在 Actions 页手动触发 → 自动构建并产出两个 tar 挂到 Release：

| 产物 | 内容 |
|---|---|
| `agent-hermes-latest.tar` | 上游 Dockerfile + fork dev 构建的 Hermes 镜像 |
| `agent-ntfy-latest.tar` | alpine + fork 编译二进制 + 认证自动初始化 |

## 配置参考

| 环境变量 | 必填 | 说明 |
|---|---|---|
| `DEEPSEEK_API_KEY` | ✅ | LLM Key |
| `NTFY_TOPIC` | ✅ | 频道名（认证保护，可随意取） |
| `NTFY_USER` / `NTFY_PASS` | ✅（公网） | 手机登录账号；Hermes 侧自动用同账号 Basic auth |

## 安全底线

- `.env`/密钥永不入库
- 公网部署务必设置 NTFY_USER/NTFY_PASS
- 如需 HTTPS 在 2586 前挂反代（Caddy 等）
