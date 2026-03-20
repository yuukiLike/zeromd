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
SYNC_BRANCH="main"
UPSTREAM_ESTABLISHED_FILE="$STATE_DIR/upstream-established"

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

classify_git_error() {
    local action="$1" stderr_output="$2"

    if echo "$stderr_output" | grep -qiE 'invalid username or token|password authentication is not supported|authentication failed for .https://'; then
        echo "HTTPS authentication failed. GitHub no longer accepts account passwords for Git operations. Update your saved HTTPS credentials or switch origin to SSH."
    elif echo "$stderr_output" | grep -qiE 'permission denied \(publickey\)'; then
        echo "SSH authentication failed. Check your SSH key and GitHub SSH settings."
    elif echo "$stderr_output" | grep -qiE 'could not resolve host|failed to connect|connection timed out|operation timed out|network is unreachable'; then
        echo "Network error during $action. Check GitHub reachability and your connection."
    elif echo "$stderr_output" | grep -qiE 'conflict|could not apply'; then
        echo "$action failed because git hit a merge conflict. Resolve it manually and retry."
    elif echo "$stderr_output" | grep -qiE '\[rejected\]|non-fast-forward|fetch first'; then
        echo "$action failed because origin/$SYNC_BRANCH changed. Pull remote changes and retry."
    else
        echo "$action failed."
    fi
}

run_git_with_classified_error() {
    local action="$1"
    shift

    local err_file err_output error_message
    err_file="$(mktemp)"

    if env GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}" "$@" 2>"$err_file"; then
        if [ -s "$err_file" ]; then
            cat "$err_file" >> "$LOG_FILE"
        fi
        rm -f "$err_file"
        return 0
    fi

    err_output="$(cat "$err_file")"
    if [ -n "$err_output" ]; then
        printf '%s\n' "$err_output" >> "$LOG_FILE"
    fi
    rm -f "$err_file"

    error_message="$(classify_git_error "$action" "$err_output")"
    log "ERROR: $error_message"
    record_error "$error_message"
    return 1
}

upstream_signature() {
    local remote_url=""
    remote_url="$(git remote get-url origin 2>/dev/null || echo "")"
    printf '%s\t%s\t%s\n' "$VAULT_DIR" "$remote_url" "$SYNC_BRANCH"
}

mark_upstream_established() {
    upstream_signature > "$UPSTREAM_ESTABLISHED_FILE"
}

upstream_already_established() {
    [ -f "$UPSTREAM_ESTABLISHED_FILE" ] || return 1
    [ "$(cat "$UPSTREAM_ESTABLISHED_FILE")" = "$(upstream_signature)" ]
}

has_local_changes() {
    ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]
}

has_unpushed_commits() {
    git show-ref --verify --quiet "refs/remotes/origin/$SYNC_BRANCH" || return 1
    [ "$(git rev-list --count "origin/$SYNC_BRANCH..HEAD")" -gt 0 ]
}

create_backup_branch() {
    local backup_branch="zeromd-backup-$(date '+%Y%m%d-%H%M%S')"
    local snapshot_msg="backup: pre-first-sync snapshot $(date '+%Y-%m-%d %H:%M:%S')"

    if has_local_changes; then
        log "First upstream sync: snapshotting dirty worktree to $backup_branch"
        if ! git add -A 2>> "$LOG_FILE"; then
            log "ERROR: git add failed while creating first-sync backup."
            record_error "first-sync backup git add failed"
            exit 1
        fi
        if ! git commit -m "$snapshot_msg" --no-gpg-sign 2>> "$LOG_FILE"; then
            log "ERROR: git commit failed while creating first-sync backup."
            record_error "first-sync backup git commit failed"
            exit 1
        fi
    fi

    if ! git branch "$backup_branch" HEAD 2>> "$LOG_FILE"; then
        log "ERROR: failed to create backup branch $backup_branch."
        record_error "first-sync backup branch failed"
        exit 1
    fi

    log "First upstream sync: preserved local state in $backup_branch"
}

if [ "${ZEROMD_SYNC_SOURCE_ONLY:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

reset_main_to_origin() {
    if ! git checkout -B "$SYNC_BRANCH" "origin/$SYNC_BRANCH" >> "$LOG_FILE" 2>&1; then
        log "ERROR: failed to reset $SYNC_BRANCH to origin/$SYNC_BRANCH."
        record_error "first-sync reset failed"
        exit 1
    fi

    if ! git branch --set-upstream-to="origin/$SYNC_BRANCH" "$SYNC_BRANCH" >> "$LOG_FILE" 2>&1; then
        log "ERROR: failed to set upstream for $SYNC_BRANCH."
        record_error "first-sync upstream setup failed"
        exit 1
    fi
}

establish_upstream_if_needed() {
    if ! git remote get-url origin >/dev/null 2>&1; then
        return 0
    fi

    if upstream_already_established; then
        return 0
    fi

    log "First upstream sync on this machine, checking origin/$SYNC_BRANCH..."

    if ! run_git_with_classified_error "fetch" git fetch origin "$SYNC_BRANCH"; then
        exit 1
    fi

    local remote_ref="refs/remotes/origin/$SYNC_BRANCH"
    if ! git show-ref --verify --quiet "$remote_ref"; then
        mark_upstream_established
        return 0
    fi

    local local_head remote_head need_backup=0
    local_head="$(git rev-parse HEAD)"
    remote_head="$(git rev-parse "$remote_ref")"

    if [ "$local_head" = "$remote_head" ]; then
        mark_upstream_established
        return 0
    fi

    if has_local_changes; then
        need_backup=1
    fi

    if ! git merge-base --is-ancestor HEAD "$remote_ref" >/dev/null 2>&1; then
        need_backup=1
    fi

    if [ "$need_backup" -eq 1 ]; then
        create_backup_branch
    else
        log "First upstream sync: local main is behind origin/$SYNC_BRANCH, fast-forwarding."
    fi

    reset_main_to_origin
    mark_upstream_established
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

establish_upstream_if_needed

# 工作区干净但本地有未推送 commit：补推，不要直接 skip
if ! has_local_changes && has_unpushed_commits; then
    log "Local branch is ahead of origin/$SYNC_BRANCH, pushing existing commits..."
    if ! run_git_with_classified_error "push" git push origin main; then
        exit 1
    fi

    mark_upstream_established
    record_success
    log "Existing local commits pushed successfully."
    exit 0
fi

# 检查是否有变更
if ! has_local_changes; then
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
if ! run_git_with_classified_error "pull --rebase" git pull --rebase origin main; then
    exit 1
fi

# 推送
if ! run_git_with_classified_error "push" git push origin main; then
    exit 1
fi

mark_upstream_established
record_success
log "Sync completed successfully."
