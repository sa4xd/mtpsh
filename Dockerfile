# 使用轻量 Alpine 基础镜像（3.22 兼容）
FROM alpine:3.22

# 作者信息
LABEL maintainer="HgTrojan" \
      description="MTProto Proxy with nineseconds/mtg" \
      version="1.0"

# 更新包索引（包括 community 仓库），安装必要工具
RUN apk update && \
    apk add --no-cache \
    bash \
    curl \
    docker-cli \
    jq \
    libqrencode-tools \  # 修复：qrencode 的正确包名（提供 qrencode 命令）
    openssl \
    coreutils && \
    rm -rf /var/cache/apk/*  # 清理缓存，减小镜像体积

# 复制脚本（假设你有 mtg-install.sh）
COPY mtg-install.sh /usr/local/bin/mtg-install.sh
RUN chmod +x /usr/local/bin/mtg-install.sh

# 创建配置目录
ENV MTG_CONFIG=/etc/mtg
RUN mkdir -p $MTG_CONFIG

# 环境变量默认值（可通过 docker run -e 覆盖）
ENV MTG_PORT=443 \
    MTG_DOMAIN=www.cloudflare.com \
    MTG_CONTAINER=mtg \
    MTG_IMAGENAME=nineseconds/mtg:latest

# 暴露端口（动态映射）
EXPOSE ${MTG_PORT}

# 启动命令：自动安装 + 启动
CMD ["/bin/bash", "-c", "mtg-install.sh auto"]
