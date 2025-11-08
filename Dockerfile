# 使用轻量 Alpine 基础镜像
FROM alpine:latest

# 作者信息
LABEL maintainer="HgTrojan" \
      description="MTProto Proxy with nineseconds/mtg" \
      version="1.0"

# 安装必要工具
RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    jq \
    qrencode \
    openssl \
    coreutils \
    && rm -rf /var/cache/apk/*

# 复制脚本
COPY mtg-install.sh /usr/local/bin/mtg-install.sh
RUN chmod +x /usr/local/bin/mtg-install.sh

# 创建配置目录
ENV MTG_CONFIG=/etc/mtg
RUN mkdir -p $MTG_CONFIG

# 环境变量默认值（可通过 docker run -e 覆盖）
ENV MTG_PORT=8443 \
    MTG_DOMAIN=www.cloudflare.com \
    MTG_CONTAINER=mtg \
    MTG_IMAGENAME=nineseconds/mtg:latest

# 暴露端口（动态映射）
EXPOSE ${MTG_PORT}

# 启动命令：自动安装 + 启动
CMD ["/bin/bash", "-c", "mtg-install.sh auto"]
