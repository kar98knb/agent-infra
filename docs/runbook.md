# 运维手册（双容器版）

## 日常操作

```bash
docker compose ps                        # 状态
docker compose logs -f hermes            # 网关日志
docker compose logs -f ntfy              # ntfy 日志（含每次启动的认证摘要）
docker compose restart hermes            # 重启单个服务
```

## 常见变更

### 换 LLM Key（镜像内置降权 shim，无需 -u）

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

- hermes 状态：卷 `hermes-home`（容器内 /home/hermes/.hermes）
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
