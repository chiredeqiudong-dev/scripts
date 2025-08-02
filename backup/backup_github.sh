#!/bin/bash

# ==============================================================================
# Shell 脚本，用于将目录增量备份到 GitHub 仓库
# 注意:
# 1. 请确保脚本有执行权限
# 2. 请确保 git 已安装，且已配置 ssh 密钥
# 3. 请确保远程仓库已创建
# 4. 请确保 rsync 已安装
# 5. 自行添加 .gitignore 文件
# 6. 系统环境：Linux
# ==============================================================================

# --- 变量 ---
# 源目录
SOURCE_DIR="/etc/nginx/conf.d"
# 备份目录
BACKUP_DIR="/home/xxxx/backup/xxxx"
# 本地仓库目录
LOCAL_REPO="/home/xxxx/backup"
# 远程仓库 url (ssh)
GITHUB_REPO="git@github.com:xxxx/xxxx.git"
# 日志文件路径
LOG_FILE="$LOCAL_REPO/log/xxxx.log"

# --- 脚本逻辑 ---
set -e
# --- 日志记录函数 ---
LOG_MESSAGES=""
log_action() {
    local message="$1"
    LOG_MESSAGES+="$message\n"
}
write_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]" >> "$LOG_FILE"
    printf "%b" "$LOG_MESSAGES" >> "$LOG_FILE"
    echo "----------------------------------------------" >> "$LOG_FILE"
}
# 注册 write_log 函数在脚本退出时调用，确保日志总是被写入
trap write_log EXIT
log_action "Backup script started."
# 源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    log_action "Error: Source directory '$SOURCE_DIR' not found."
    exit 1
fi
# 不存在则创建目录
mkdir -p "$LOCAL_REPO"
mkdir -p "$LOCAL_REPO/log"
mkdir -p "$BACKUP_DIR"
# 如果本地仓库尚未初始化，则进行初始化
if [ ! -d "$LOCAL_REPO/.git" ]; then
    log_action "Initializing Git repository in '$LOCAL_REPO'..."
    git init "$LOCAL_REPO"
    git --git-dir="$LOCAL_REPO/.git" remote add origin "$GITHUB_REPO"
    log_action "Git repository initialized and remote added."
fi
# 使用 rsync 进行增量备份。
log_action "Starting rsync backup from '$SOURCE_DIR' to '$BACKUP_DIR' ..."
rsync -a --update --exclude='*.tmp' --quiet "$SOURCE_DIR/" "$BACKUP_DIR"
log_action "Rsync backup finished."
# 使用 --git-dir 和 --work-tree 来避免 cron 环境下的当前工作目录问题
git --git-dir="$LOCAL_REPO/.git" --work-tree="$LOCAL_REPO" add .
# 检查是否有更改要提交，以避免空提交。
if git --git-dir="$LOCAL_REPO/.git" --work-tree="$LOCAL_REPO" diff-index --quiet HEAD --; then
    log_action "No changes to commit. Backup is up to date."
else
    commit_msg="Backup on $(date +'%Y-%m-%d %H:%M:%S')"
    git --git-dir="$LOCAL_REPO/.git" --work-tree="$LOCAL_REPO" commit -m "$commit_msg"
    log_action "Committed changes: $commit_msg"
    git --git-dir="$LOCAL_REPO/.git" --work-tree="$LOCAL_REPO" push origin master --force || log_action "ERROR: git push failed!" 
    log_action "Backup successfully pushed to GitHub."
fi
log_action "Backup process finished."