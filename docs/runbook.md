# 运维手册（双容器版）

## 日常操作

```bash
docker compose ps                        # 状态
docker compose logs -f hermes            # 网关日志
docker compose logs -f ntfy              # ntfy 日志（含每次启动的认证摘要）
docker compose restart hermes            # 重启单个服务
```

## 常见变更

### 换 LLM Key（官方镜像 exec 自动降权，无需 -u）

```bash
docker compose exec hermes hermes config set DEEPSEEK_API_KEY sk-新key
docker compose restart hermes
```

### 换 topic

```bash
# 1. .env 里改 NTFY_TOPIC
# 2. ntfy 侧授权新 topic（容器每次启动也会幂等授权）
docker compose exec ntfy ntfy access "$(printenv NTFY_USER)" 新topic read-write
# 3. hermes 侧生效
docker compose restart hermes
```

### 换密码

```bash
# 1. .env 里改 NTFY_PASS
# 2. 更新 ntfy 用户密码（auth.db 在 ntfy-auth 卷）
docker compose exec -e NTFY_PASSWORD=新密码 ntfy ntfy user change-pass "$(printenv NTFY_USER)"
# 3. 两侧重启
docker compose restart
# 手机 App 同步换登录密码
```

### 验证链路

```bash
curl -u 用户名:密码 -d "test" http://127.0.0.1:2586/你的topic
docker compose logs -f hermes   # 看处理与回复
```

## 数据与备份

- hermes 状态：卷 `hermes-home`（容器内 /opt/data）
- ntfy 账号库：卷 `ntfy-auth`（auth.db）
- 备份：

```bash
docker run --rm -v agent-infra_hermes-home:/data -v $(pwd):/backup alpine tar czf /backup/hermes-home.tgz -C /data .
docker run --rm -v agent-infra_ntfy-auth:/data -v $(pwd):/backup alpine tar czf /backup/ntfy-auth.tgz -C /data .
```

## 升级

```bash
docker load < agent-hermes-latest.tar   # 新版本两个 tar
docker load < agent-ntfy-latest.tar
docker compose down && docker compose up -d   # 卷复用，记忆保留
```

## 发布前自检清单（教训沉淀）

- [ ] 首启路径：全新卷启动 → 发消息 → 收到回复
- [ ] 重启路径：`docker compose restart` → 发消息 → 收到回复
- [ ] 重建路径：`down && up -d` → 记忆仍在、发消息正常
- [ ] 换 Key：runbook 流程实测生效
- [ ] 文档一致性：grep 所有引用旧路径/旧变量/旧版本号的文件

## 生产环境记录（ECS，2026-11-23 上线）

- 部署方式：Release tar ×2 + compose（README 流程），公网仅暴露 8443 HTTPS（安全组入方向 TCP 8443，2586 不公开）
- 验收：首启/重启/重建/公网 HTTPS/认证 全通过；手机自签证书信任流程见下节
- 已知观察项：
  1. hermes 的 ntfy 订阅流偶发断连（重启 hermes 恢复）——复发频繁再加看门狗
  2. ECS 为试用实例（约 71 天）——到期前备份 `hermes-home`/`ntfy-auth` 卷并决定续费/迁移
  3. Windows 终端 curl 发中文会以 GBK 编码被 ntfy 判为附件（400）——测试请用 `ssh <server> curl` 或手机 App
- 回滚：VM 侧旧主栈（systemd hermes-gateway）已 stop+disable，配置保留，需要时 `systemctl --user enable --now hermes-gateway` 恢复

## 自签 HTTPS（免域名免备案，已实测验证）

公网部署不想买域名时，用自签证书 + ntfy 原生 HTTPS（已验证：ntfy Android App 信任手机系统用户证书，HyperOS 实测通过）。

**服务器侧（30 秒）：**

```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout tls.key -out tls.crt -days 3650 \
  -subj "/CN=<服务器IP>" -addext "subjectAltName=IP:<服务器IP>,IP:127.0.0.1"
# ntfy 配置（server.yml）：
#   listen-https: ":8443"
#   key-file: .../tls.key
#   cert-file: .../tls.crt
```

**手机侧（一次）：** 证书传到手机 → 直接点击 .crt 文件 → 安装证书（HyperOS：设置 → 密码与安全 → 系统安全 → 加密与凭据 → 安装证书 → CA 证书）→ ntfy App 服务器填 `https://<IP>:8443`。

**注意：**
- 证书 SAN 必须包含手机实际连接的 IP；换服务器 IP = 重新签 + 手机重装证书
- 安装后系统可能提示「网络可能被监控」——正常现象
- 域名 + Let's Encrypt 路线仍是更省心的替代（约 30 元/年）

