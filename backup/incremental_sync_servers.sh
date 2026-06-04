#!/bin/bash
# 云服务器数据增量同步脚本
# 功能：通过 SSH + rsync 增量同步云服务器指定目录到本地，仅传输变化的文件
#
# 前置条件：
#   1. 将本地公钥复制到云服务器（两种方式任选）：
#      方式一：ssh-copy-id -p 端口 user@server（首次需输入密码）
#      方式二：手动复制
#        - 本地：cat ~/.ssh/id_rsa.pub | pbcopy
#        - 服务器：echo "公钥内容" >> ~/.ssh/authorized_keys
#   2. SSH 用户对备份目录有读取权限
#   3. 服务器安装 rsync，本地安装 rsync

# ========================= 配置区 =========================

# 本地同步目录（按服务器 IP 自动分目录）
LOCAL_SYNC_DIR="$HOME/Sync/servers"

# 远程临时目录（rsync 中转用，一般不需要改）
REMOTE_TMP_DIR="/tmp"

# 排除的文件/目录模式（rsync --exclude 规则，每行一个）
EXCLUDES=()

# 是否使用 sudo 执行远程 rsync（目录权限不足时设为 true）
USE_SUDO=false

# 服务器列表（格式："地址|端口|用户名|目录1,目录2"）
SERVERS=(
    "192.168.1.10|22|root|/opt/app/data,/etc/nginx/conf.d"
    "192.168.1.11|2222|root|/home/deploy/app"
)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"; }

mkdir -p "$LOCAL_SYNC_DIR"
TOTAL=0; SUCCESS=0; FAILED=0

# 构建 rsync exclude 参数
build_exclude_args() {
    local args=""
    if [ "${#EXCLUDES[@]}" -gt 0 ]; then
        for pattern in "${EXCLUDES[@]}"; do
            args+=" --exclude '${pattern}'"
        done
    fi
    echo "$args"
}

sync_server() {
    local config="$1"
    IFS='|' read -r server port user remote_dirs <<< "$config"

    log_info "========== 开始同步：${server}:${port} =========="

    IFS=',' read -ra dirs <<< "$remote_dirs"

    for dir in "${dirs[@]}"; do
        dir=$(echo "$dir" | xargs)
        [ -z "$dir" ] && continue

        TOTAL=$((TOTAL + 1))

        local dir_safe
        dir_safe=$(echo "${dir#/}" | tr '/' '_')
        local local_dir="${LOCAL_SYNC_DIR}/${server}/${dir_safe}"
        mkdir -p "${local_dir}"

        log_info "同步目录：${dir} → ${local_dir}"

        local exclude_args
        exclude_args=$(build_exclude_args)

        # rsync 增量同步（-a 归档模式，-z 压缩传输，-P 显示进度+断点续传）
        local sudo_arg=""
        [ "$USE_SUDO" = true ] && sudo_arg="--rsync-path='sudo rsync'"

        if ! eval rsync -azP \
            -e "'ssh -p ${port} -o ConnectTimeout=10'" \
            ${sudo_arg} \
            ${exclude_args} \
            "'${user}@${server}:${dir}/'" \
            "'${local_dir}/'"; then
            log_error "同步失败：${server}:${dir}"
            FAILED=$((FAILED + 1))
            continue
        fi

        local dir_size
        dir_size=$(du -sh "${local_dir}" | cut -f1)
        log_info "同步完成：${local_dir}（${dir_size}）"
        SUCCESS=$((SUCCESS + 1))
    done

    log_info "========== 同步结束：${server}:${port} =========="
    echo ""
}

# ========================= 主流程 =========================

log_info "开始云服务器增量同步"
echo ""

for config in "${SERVERS[@]}"; do
    sync_server "$config"
done

echo ""
log_info "==================== 同步汇总 ===================="
log_info "总计：${TOTAL} 个目录  成功：${SUCCESS}  失败：${FAILED}"
log_info "本地同步目录：${LOCAL_SYNC_DIR}"

if [ "$FAILED" -gt 0 ]; then
    log_warn "存在 ${FAILED} 个同步失败，请检查日志"
    exit 1
fi

log_info "全部同步完成"
