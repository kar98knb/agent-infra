#!/bin/sh
# hermes 容器入口：以 hermes 用户运行网关
# PID1/僵尸回收由 docker run --init（compose 里 init: true）提供
exec runuser -u hermes -- /opt/hermes/.venv/bin/hermes gateway run
