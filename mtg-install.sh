#!/bin/bash
set -e

# 颜色定义
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[36m'; PURPLE='\033[35m'; PLAIN='\033[0m'
CHECK="✔"; CROSS="✗"; INFO="ℹ"

# 配置路径
export MTG_CONFIG="${MTG_CONFIG:-/etc/mtg}"
export MTG_ENV="$MTG_CONFIG/env"
export MTG_SECRET="$MTG_CONFIG/secret"
export MTG_CONTAINER="${MTG_CONTAINER:-mtg}"
export MTG_IMAGENAME="${MTG_IMAGENAME:-nineseconds/mtg:latest}"
export MTG_PORT="${MTG_PORT:-443}"
export MTG_DOMAIN="${MTG_DOMAIN:-www.cloudflare.com}"

# 获取本机 IP（容器内通过 Docker 网关）
IP=$(hostname -i | awk '{print $1}')

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

# 自动模式：直接安装并启动
auto_install() {
    echo -e "${BLUE}${INFO} 正在自动安装 MTProto 代理...${PLAIN}"

    mkdir -p "$MTG_CONFIG"

    # 写入配置
    cat > "$MTG_ENV" <<EOF
MTG_IMAGENAME=$MTG_IMAGENAME
MTG_PORT=$MTG_PORT
MTG_CONTAINER=$MTG_CONTAINER
MTG_DOMAIN=$MTG_DOMAIN
EOF

    # 安装 Docker（如果未安装）
    if ! command -v docker &>/dev/null; then
        colorEcho $YELLOW "${INFO} 正在安装 Docker..."
        apk add --no-cache docker-cli || {
            curl -fsSL https://get.docker.com | sh
            rc-update add docker boot
            service docker start
        }
    fi

    # 启动 Docker 服务
    service docker start 2>/dev/null || true

    # 拉取镜像
    colorEcho $BLUE "${INFO} 正在拉取镜像: $MTG_IMAGENAME"
    docker pull "$MTG_IMAGENAME"

    # 生成密钥
    colorEcho $BLUE "${INFO} 正在生成 TLS 密钥..."
    docker run --rm "$MTG_IMAGENAME" generate-secret tls -c "$MTG_DOMAIN" > "$MTG_SECRET"

    # 停止旧容器
    docker rm -f "$MTG_CONTAINER" 2>/dev/null || true

    # 启动新容器
    colorEcho $BLUE "${INFO} 正在启动 MTProto 代理..."
    docker run -d \
        --name "$MTG_CONTAINER" \
        --restart unless-stopped \
        --ulimit nofile=51200:51200 \
        -p "0.0.0.0:${MTG_PORT}:3128" \
        -v "$MTG_CONFIG:$MTG_CONFIG" \
        "$MTG_IMAGENAME" run "$(cat "$MTG_SECRET")"

    sleep 3

    # 检查状态
    if docker ps | grep -q "$MTG_CONTAINER"; then
        colorEcho $GREEN "${CHECK} MTProto 代理启动成功！"
    else
        colorEcho $RED "${CROSS} 启动失败，请查看日志：docker logs $MTG_CONTAINER"
        exit 1
    fi

    # 输出信息
    SECRET=$(cat "$MTG_SECRET")
    LINK="https://t.me/proxy?server=$IP&port=$MTG_PORT&secret=$SECRET"

    echo -e "\n${PURPLE}=============== MTProto 代理信息 ===============${PLAIN}"
    echo -e " ${BLUE}● 服务器IP:${PLAIN} ${GREEN}$IP${PLAIN}"
    echo -e " ${BLUE}● 代理端口:${PLAIN} ${GREEN}$MTG_PORT${PLAIN}"
    echo -e " ${BLUE}● TLS 域名:${PLAIN} ${GREEN}$MTG_DOMAIN${PLAIN}"
    echo -e " ${BLUE}● 安全密钥:${PLAIN} ${GREEN}$SECRET${PLAIN}"
    echo -e " ${BLUE}● 订阅链接:${PLAIN} ${GREEN}$LINK${PLAIN}"

    # 二维码
    if command -v qrencode &>/dev/null; then
        echo -e "\n${BLUE}● 订阅二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "$LINK"
    fi

    echo -e "${PURPLE}================================================${PLAIN}\n"
    colorEcho $GREEN "${CHECK} 安装完成！容器持续运行中..."
}

# 主逻辑
if [[ "$1" == "auto" ]]; then
    auto_install
else
    echo "用法: docker run -e MTG_PORT=443 -e MTG_DOMAIN=xxx.com mtg-proxy"
fi
