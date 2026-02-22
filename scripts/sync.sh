#!/bin/bash
# zeromd sync script
# 将 iCloud 中 Obsidian vault 的变更自动同步到 Git 远程仓库
#
# vault 查找策略（按优先级）：
#   1. 环境变量 ZEROMD_VAULT_DIR（install.sh 设置的）
#   2. ~/.zeromd/vault-path 文件里记录的路径
#   3. 自动扫描 iCloud Obsidian 目录，找到第一个有 .git 的 vault
# 这意味着即使你重命名了 vault，第 3 步也能自动找到它。

set -uo pipefail
# 注意：不用 set -e，所有错误通过显式检查处理，确保 record_error 被调用

STATE_DIR="${ZEROMD_STATE_DIR:-$HOME/.zeromd}"
LOG_FILE="${ZEROMD_LOG_FILE:-$STATE_DIR/sync.log}"
ICLOUD_OBSIDIAN="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"

mkdir -p "$STATE_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    # 交互模式下同时输出到屏幕
    if [ -t 1 ]; then
        echo "$msg"
    fi
}

record_error() {
    echo "$1" > "$STATE_DIR/last-error"
    local count=0
    [ -f "$STATE_DIR/consecutive-failures" ] && count=$(cat "$STATE_DIR/consecutive-failures")
    echo $((count + 1)) > "$STATE_DIR/consecutive-failures"
}

record_success() {
    echo "$(date +%s)" > "$STATE_DIR/last-sync"
    rm -f "$STATE_DIR/last-error"
    echo "0" > "$STATE_DIR/consecutive-failures"
}

# ---------- 查找 vault ----------

find_vault() {
    # 策略 1：环境变量
    if [ -n "${ZEROMD_VAULT_DIR:-}" ] && [ -d "${ZEROMD_VAULT_DIR}/.git" ]; then
        echo "$ZEROMD_VAULT_DIR"
        return
    fi

    # 策略 2：配置文件
    if [ -f "$STATE_DIR/vault-path" ]; then
        local saved
        saved="$(cat "$STATE_DIR/vault-path")"
        if [ -d "$saved/.git" ]; then
            echo "$saved"
            return
        fi
    fi

    # 策略 3：自动扫描 iCloud 目录，找有 .git 的 vault
    if [ -d "$ICLOUD_OBSIDIAN" ]; then
        for dir in "$ICLOUD_OBSIDIAN"/*/; do
            if [ -d "$dir/.git" ]; then
                # 找到了，顺便更新配置文件，下次直接命中策略 2
                echo "$dir" > "$STATE_DIR/vault-path"
                echo "${dir%/}"
                return
            fi
        done
    fi

    return 1
}

VAULT_DIR="$(find_vault)" || {
    log "ERROR: 找不到任何有 .git 的 Obsidian vault"
    record_error "vault not found"
    exit 1
}

# 检查是否是 Git 仓库（双重保险）
if [ ! -d "$VAULT_DIR/.git" ]; then
    log "ERROR: Not a git repo: $VAULT_DIR"
    record_error "not a git repo"
    exit 1
fi

# 心跳：每次执行都写，表明 daemon 还活着
echo "$(date +%s)" > "$STATE_DIR/last-heartbeat"

cd "$VAULT_DIR"

# rebase 卡死检测
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    log "ERROR: Git rebase in progress. Run 'cd $VAULT_DIR && git rebase --abort' or resolve manually."
    record_error "REBASE_CONFLICT"
    exit 1
fi

# 检查是否有变更
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "No changes detected, skip."
    exit 0
fi

log "Changes detected, syncing..."

# 添加所有变更（iCloud 文件锁可能导致失败）
if ! git add -A 2>> "$LOG_FILE"; then
    log "ERROR: git add failed. Likely iCloud file lock, will retry next cycle."
    record_error "git add failed (iCloud file lock)"
    exit 1
fi

# 提交
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if ! git commit -m "auto-sync: $TIMESTAMP" --no-gpg-sign 2>> "$LOG_FILE"; then
    log "Nothing to commit after staging."
    exit 0
fi

# 拉取远程变更并 rebase
if ! git pull --rebase origin main 2>> "$LOG_FILE"; then
    log "ERROR: pull --rebase failed. May need manual conflict resolution."
    record_error "pull --rebase failed"
    exit 1
fi

# 推送
if ! git push origin main 2>> "$LOG_FILE"; then
    log "ERROR: push failed."
    record_error "push failed"
    exit 1
fi

record_success
log "Sync completed successfully."
