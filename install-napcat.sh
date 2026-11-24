#!/usr/bin/env bash
# NapCat v4.18.42 一键部署脚本（社区归档版）
# 上游 NapNeko/NapCatQQ 已停止维护，镜像归档自 Luna-channel/NapCatQQ-final
set -uo pipefail

VERSION="v4.18.42"
IMAGE="mlikiowa/napcat-docker:${VERSION}"
GH="https://github.com/Luna-channel/NapCatQQ-final/releases/download/${VERSION}"
PROXY="https://gh-proxy.com/"

# ---- 0. 前置检查 ----
if ! command -v docker >/dev/null 2>&1; then
  echo "[x] 未检测到 docker，请先安装 Docker 再运行本脚本"
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  COMPOSE=""
fi

# ---- 1. 镜像 ----
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "[=] 镜像 $IMAGE 已存在，跳过下载"
else
  case "$(uname -m)" in
    x86_64|amd64)  ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) echo "[x] 不支持的架构: $(uname -m)"; exit 1 ;;
  esac

  FILE="napcat-docker-${VERSION}-${ARCH}.tar"
  echo "[*] 架构 ${ARCH}，导入镜像 ${FILE}"

  echo "[*] 尝试 GitHub 直链..."
  if ! curl -fL --connect-timeout 10 "${GH}/${FILE}" | docker load; then
    echo "[!] GitHub 直连失败，切换到加速镜像..."
    if ! curl -fL --connect-timeout 10 "${PROXY}${GH}/${FILE}" | docker load; then
      echo "[x] 两个下载源都失败了，请检查网络后重试"
      exit 1
    fi
  fi

  # arm64 归档包导入的镜像名不同，统一改名以匹配 compose 配置
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    SRC=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'napcat-docker:v4.18.42' | head -1)
    if [ -n "$SRC" ]; then
      docker tag "$SRC" "$IMAGE"
      echo "[=] 已将 $SRC 改名为 $IMAGE"
    else
      echo "[x] 导入后未找到 napcat 镜像，请检查 docker images 输出"
      exit 1
    fi
  fi
fi

echo "[=] 镜像就绪: $IMAGE"

# ---- 2. 启动 ----
DIR="$(cd "$(dirname "$0")" && pwd)"
YML=""
for c in "$DIR/astrbot.yml" "$DIR/compose/astrbot.yml" "$DIR/docker-compose.yml"; do
  [ -f "$c" ] && YML="$c" && break
done

if [ -z "$COMPOSE" ]; then
  echo "[!] 未找到 docker compose，镜像已导入，请自行安装 compose 后启动"
  exit 0
fi

if [ -n "$YML" ]; then
  echo "[*] 使用 $YML 启动..."
  NAPCAT_UID=$(id -u) NAPCAT_GID=$(id -g) $COMPOSE -f "$YML" up -d
  echo "[=] 完成。NapCat WebUI: http://<服务器IP>:6099 （第二个实例为 7099）"
else
  echo "[!] 镜像已导入，但未找到 compose 文件（astrbot.yml）"
  echo "    请将 yml 放到本脚本同目录后重新运行，或手动执行 compose up -d"
fi
