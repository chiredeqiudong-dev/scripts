#!/bin/bash
# 云服务器数据备份脚本
# 功能：SSH 连接云服务器 → tar 压缩指定目录 → scp 拉取到本地 → 清理远程临时文件
#
# 前置条件：
#   1. 将本地公钥复制到云服务器（两种方式）：
#      方式一：ssh-copy-id -p 端口 user@server（首次需输入密码）
#      方式二：手动复制
#        - 本地：cat ~/.ssh/id_rsa.pub | pbcopy
#        - 服务器：echo "公钥内容" >> ~/.ssh/authorized_keys
#   2. SSH 用户对备份目录有读取权限
#   3. 服务器安装 tar，本地安装 scp

# ========================= 配置区 =========================

# 本地备份目录（按服务器 IP 自动分目录，文件名格式：目录路径_时间戳.tar.gz）
LOCAL_BACKUP_DIR="$HOME/Backups/servers"

# 远程临时压缩包存放路径
REMOTE_TMP_DIR="/tmp"

# 是否使用 sudo 执行远程压缩（目录权限不足时设为 true, 需要设置sudo免密）
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

mkdir -p "$LOCAL_BACKUP_DIR"
TOTAL=0; SUCCESS=0; FAILED=0

backup_server() {
    local config="$1"
    IFS='|' read -r server port user remote_dirs <<< "$config"

    local server_safe="${server//[^a-zA-Z0-9._-]/_}"
    local date_tag
    date_tag=$(date '+%Y%m%d_%H%M%S')

    log_info "========== 开始备份：${server}:${port} =========="

    IFS=',' read -ra dirs <<< "$remote_dirs"

    for dir in "${dirs[@]}"; do
        dir=$(echo "$dir" | xargs)
        [ -z "$dir" ] && continue

        TOTAL=$((TOTAL + 1))

        local dir_safe
        dir_safe=$(echo "${dir#/}" | tr '/' '_')
        local archive_name="${dir_safe}_${date_tag}.tar.gz"
        local remote_archive="${REMOTE_TMP_DIR}/${archive_name}"
        local server_dir="${LOCAL_BACKUP_DIR}/${server}"
        mkdir -p "${server_dir}"
        local local_archive="${server_dir}/${archive_name}"

        log_info "压缩远程目录：${dir}"

        # 1. SSH 压缩
        local tar_cmd="tar czf '${remote_archive}' -C '$(dirname "${dir}")' '$(basename "${dir}")' 2>/dev/null"
        [ "$USE_SUDO" = true ] && tar_cmd="sudo ${tar_cmd}"

        if ! ssh -p "${port}" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
            "${user}@${server}" \
            "if [ ! -d '${dir}' ]; then echo '目录不存在: ${dir}' >&2; exit 1; fi && \
             ${tar_cmd}"; then
            log_error "压缩失败：${server}:${dir}"
            FAILED=$((FAILED + 1))
            continue
        fi

        log_info "拉取备份文件：${archive_name}"

        # 2. SCP 拉取
        if ! scp -P "${port}" -o ConnectTimeout=10 \
            "${user}@${server}:${remote_archive}" \
            "${local_archive}"; then
            log_error "拉取失败：${server}:${dir}"
            local rm_cmd="rm -f '${remote_archive}'"
            [ "$USE_SUDO" = true ] && rm_cmd="sudo ${rm_cmd}"
            ssh -p "${port}" -o ConnectTimeout=10 "${user}@${server}" "${rm_cmd}" 2>/dev/null || true
            FAILED=$((FAILED + 1))
            continue
        fi

        log_info "清理远程临时文件：${remote_archive}"

        # 3. 清理远程临时文件
        local rm_cmd="rm -f '${remote_archive}'"
        [ "$USE_SUDO" = true ] && rm_cmd="sudo ${rm_cmd}"
        if ! ssh -p "${port}" -o ConnectTimeout=10 "${user}@${server}" "${rm_cmd}"; then
            log_warn "远程清理失败（本地备份已完成）：${remote_archive}"
        fi

        local file_size
        file_size=$(du -h "${local_archive}" | cut -f1)
        log_info "备份完成：${local_archive}（${file_size}）"
        SUCCESS=$((SUCCESS + 1))
    done

    log_info "========== 备份结束：${server}:${port} =========="
    echo ""
}

# ========================= 主流程 =========================

log_info "开始云服务器备份任务"
echo ""

for config in "${SERVERS[@]}"; do
    backup_server "$config"
done

echo ""
log_info "==================== 备份汇总 ===================="
log_info "总计：${TOTAL} 个目录  成功：${SUCCESS}  失败：${FAILED}"
log_info "本地备份目录：${LOCAL_BACKUP_DIR}"

if [ "$FAILED" -gt 0 ]; then
    log_warn "存在 ${FAILED} 个备份失败，请检查日志"
    exit 1
fi

log_info "全部备份完成"
