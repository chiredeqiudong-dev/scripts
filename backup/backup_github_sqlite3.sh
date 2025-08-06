#!/bin/bash

# 备份 SQLite 数据库+其他单独文件,并同步到 GitHub

# 数据目录路径
DATA_DIR="/home/xx/app/xx/data"                    
# DATA_DIR目录下的文件
DB_FILE="db.sqlite3"                       
RSA_KEY_FILE="xx.pem"   
# 本地仓库
LOCAL_REPO="/home/xx/backup"
# 备份目录路径
BACKUP_DIR="$LOCAL_REPO/xx_bak"            
# GitHub 仓库信息（SSH）
GITHUB_REPO="git@github.com:xx/xx.git" 
# 其他文件
COMPOSE_FILE="/home/xx/app/xx/compose.yaml"      
# 日志文件路径
LOG_FILE="$LOCAL_REPO/log/xx_bak.log"         

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查必要条件
[ ! -d "$DATA_DIR" ] && log "错误：数据目录不存在：$DATA_DIR" && exit 1
[ ! -f "$DATA_DIR/$DB_FILE" ] && log "错误：数据库文件不存在：$DATA_DIR/$DB_FILE" && exit 1
[ ! -f "$DATA_DIR/$RSA_KEY_FILE" ] && log "错误：xx文件不存在：$DATA_DIR/$RSA_KEY_FILE" && exit 1
[ ! -f "$COMPOSE_FILE" ] && log "错误：compose文件不存在：$COMPOSE_FILE" && exit 1
command -v sqlite3 >/dev/null 2>&1 || { log "错误：请安装 sqlite3"; exit 1; }

# 准备备份
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="db-backup-${TIMESTAMP}.sqlite3"
# 确保备份目录和日志目录存在
mkdir -p "$BACKUP_DIR"
mkdir -p ""$LOCAL_REPO/"log"

# 备份数据库
log "开始备份数据库..."
sqlite3 "$DATA_DIR/$DB_FILE" ".backup '$BACKUP_DIR/$BACKUP_FILE'"
[ $? -ne 0 ] && log "错误：数据库备份失败" && exit 1
log "数据库备份成功：$BACKUP_FILE"
# 压缩备份
log "开始压缩......"
gzip "$BACKUP_DIR/$BACKUP_FILE"
[ $? -ne 0 ] && log "警告：压缩备份失败"
log "压缩成功：$BACKUP_DIR/$BACKUP_FILE"
# 备份配置文件
log "备份配置文件..."
# 备份 compose.yaml
cp -f "$COMPOSE_FILE" "$BACKUP_DIR"
[ $? -ne 0 ] && log "错误：备份 compose.yaml 失败" && exit 1
log "compose.yaml 备份成功"
# 备份 xx 
cp -f "$DATA_DIR/$RSA_KEY_FILE" "$BACKUP_DIR"
log "rsa_key.pem 备份成功"
# 同步到 GitHub
log "同步到 GitHub..."
# 如果不是 Git 仓库，初始化它
if [ ! -d "$LOCAL_REPO/.git" ]; then
    git -C "$LOCAL_REPO" init
    git -C "$LOCAL_REPO" remote add origin "$GITHUB_REPO"
fi
# 检查是否有更改需要提交
if ! git -C "$BACKUP_DIR" diff-index --quiet HEAD -- 2>/dev/null || \
    [ -n "$(git -C "$BACKUP_DIR" ls-files --others --exclude-standard)" ]; then
    # 有更改，执行提交和推送
    git -C "$BACKUP_DIR" add .
    git -C "$BACKUP_DIR" commit -m "Backup $TIMESTAMP"
    git -C "$BACKUP_DIR" push origin master || log "警告：GitHub 同步失败"
    log "已同步更改到 GitHub"
else
    log "没有需要同步的更改"
fi

log "-------------------备份完成------------------"