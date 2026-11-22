# 运维手册（容器版）

## 日常操作

```bash
# 查看日志（含首启认证信息）
docker logs -f agent

# 重启
docker restart agent

# 状态
docker ps | grep agent
```

## 常见变更

### 换 topic / 账号密码

```bash
docker rm -f agent
docker run -d --name agent -p 2586:2586 --restart unless-stopped \
  -e DEEPSEEK_API_KEY=sk-xxx \
  -e NTFY_TOPIC=新topic \
  -e NTFY_USER=kar98k -e NTFY_PASS=新密码 \
  -v agent-home:/root/.hermes \
  agent-infra:latest
```

认证初始化只发生在首次启动（auth.db 在容器层）；已初始化后改密码需进容器执行：

```bash
docker exec -it agent ntfy --auth-file /var/lib/ntfy/auth.db user change-pass kar98k
```

### 换 LLM Key

```bash
docker exec agent /opt/hermes/.venv/bin/hermes config set DEEPSEEK_API_KEY sk-xxx
docker restart agent
```

### 验证链路

```bash
# 手机发消息后看网关日志
docker logs -f agent | grep -iv "nous\|auxiliary"

# 服务端直接测发布（Basic auth）
curl -u kar98k:密码 -d "test" http://127.0.0.1:2586/agent
```

## 数据与备份

- Hermes 状态：卷 `agent-home`（/root/.hermes）
- 备份：`docker run --rm -v agent-home:/data -v $(pwd):/backup alpine tar czf /backup/agent-home.tgz -C /data .`

## 升级

```bash
docker load < agent-infra-latest.tar   # 新版本 tar
docker rm -f agent && docker run ...   # 用新镜像重建（卷复用，记忆保留）
```
