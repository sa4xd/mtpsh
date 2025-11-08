#!/bin/bash
set -e

# 颜色定义
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[36m'; PURPLE='\033[35m'; PLAIN='\033[0m'
CHECK="Checkmark"; CROSS="Cross"; INFO="Information"

# 配置路径
export MTG_CONFIG="${MTG_CONFIG:-/etc/mtg}"
export MTG_ENV="$MTG_CONFIG/env"
export MTG_SECRET="$MTG_CONFIG/secret"
export MTG_CONTAINER="${MTG_CONTAINER:-mtg}"
export MTG_IMAGENAME="${MTG_IMAGENAME:-nineseconds/mtg:latest}"
export MTG_PORT="${MTG_PORT:-443}"
export MTG_DOMAIN="${MTG_DOMAIN:-www.cloudflare.com}"

# 容器内 IP（通过网关）
IP=$(hostname -i | awk '{print $1}')

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

auto_install() {
    echo -e "${BLUE}${INFO} 正在自动安装 MTProto 代理...${PLAIN}"

    mkdir -p "$MTG_CONFIG"

    # 写入环境配置
    cat > "$MTG_ENV" <<EOF
MTG_IMAGENAME=$MTG_IMAGENAME
MTG_PORT=$MTG_PORT
MTG_CONTAINER=$MTG_CONTAINER
MTG_DOMAIN=$MTG_DOMAIN
EOF

    # 启动 Docker 服务（Alpine 使用 openrc）
    rc-update add docker boot 2>/dev/null || true
    service docker start 2>/dev/null || true

    # 拉取镜像
    colorEcho $BLUE "${INFO} 拉取镜像: $MTG_IMAGENAME"
    docker pull "$MTG_IMAGENAME"

    # 生成密钥
    colorEcho $BLUE "${INFO} 生成 TLS 密钥..."
    docker run --rm "$MTG_IMAGENAME" generate-secret tls -c "$MTG_DOMAIN" > "$MTG_SECRET"

    # 停止旧容器
    docker rm -f "$MTG_CONTAINER" 2>/dev/null || true

    # 启动代理
    colorEcho $BLUE "${INFO} 启动 MTProto 代理..."
    docker run -d \
        --name "$MTG_CONTAINER" \
        --restart unless-stopped \
        --ulimit nofile=51200:51200 \
        -p "0.0.0.0:${MTG_PORT}:3128" \
        -v "$MTG_CONFIG:$MTG_CONFIG" \
        "$MTG_IMAGENAME" run "$(cat "$MTG_SECRET")"

    sleep 3
    if docker ps | grep -q "$MTG_CONTAINER"; then
        colorEcho $GREEN "${CHECK} 代理启动成功！"
    else
        colorEcho $RED "${CROSS} 启动失败"
        exit 1
    fi

    # 输出信息
    SECRET=$(cat "$MTG_SECRET")
    LINK="https://t.me/proxy?server=$IP&port=$MTG_PORT&secret=$SECRET"

    echo -e "\n${PURPLE}=============== MTProto 代理信息 ===============${PLAIN}"
    echo -e " ${BLUE}IP:${PLAIN} ${GREEN}$IP${PLAIN}"
    echo -e " ${BLUE}端口:${PLAIN} ${GREEN}$MTG_PORT${PLAIN}"
    echo -e " ${BLUE}域名:${PLAIN} ${GREEN}$MTG_DOMAIN${PLAIN}"
    echo -e " ${BLUE}密钥:${PLAIN} ${GREEN}$SECRET${PLAIN}"
    echo -e " ${BLUE}订阅链接:${PLAIN} ${GREEN}$LINK${PLAIN}"

    if command -v qrencode &>/dev/null; then
        echo -e "\n${BLUE}订阅二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "$LINK"
    fi

    echo -e "${PURPLE}================================================${PLAIN}\n"
    colorEcho $GREEN "${CHECK} 安装完成！"
}

if [[ "$1" == "auto" ]]; then
    auto_install
else
    echo "用法: docker run -e MTG_PORT=443 -e MTG_DOMAIN=xxx.com mtg-proxy"
fi
