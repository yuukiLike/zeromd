#!/bin/bash
# sync.sh 核心逻辑测试

SYNC_CMD="$PROJECT_DIR/scripts/sync.sh"

# ---------- 辅助函数 ----------

_setup_bare_remote() {
    local bare_remote
    bare_remote="$(mktemp -d)"
    git init --bare --quiet "$bare_remote"
    git -C "$ZEROMD_TEST_VAULT" remote add origin "$bare_remote"
    git -C "$ZEROMD_TEST_VAULT" push -u origin main --quiet 2>/dev/null
    echo "$bare_remote"
}

_push_commit_to_remote() {
    local bare_remote="$1" filename="$2" content="$3"
    local clone_dir
    clone_dir="$(mktemp -d)"

    git clone --quiet --branch main "$bare_remote" "$clone_dir" >/dev/null 2>&1
    git -C "$clone_dir" config user.email "test@test.com"
    git -C "$clone_dir" config user.name "Test"
    echo "$content" > "$clone_dir/$filename"
    git -C "$clone_dir" add "$filename"
    git -C "$clone_dir" commit -m "remote update" --quiet --no-gpg-sign
    git -C "$clone_dir" push origin main --quiet

    rm -rf "$clone_dir"
}

_find_backup_branch() {
    git -C "$ZEROMD_TEST_VAULT" for-each-ref --format='%(refname:short)' 'refs/heads/zeromd-backup-*' | head -n1
}

_install_git_wrapper() {
    local wrapper_dir="$1" command_to_fail="$2" stderr_text="$3"
    local real_git
    real_git="$(command -v git)"

    mkdir -p "$wrapper_dir"
    cat > "$wrapper_dir/git" <<EOF
#!/bin/bash
if [ "\$1" = "$command_to_fail" ]; then
    printf '%s\n' "$stderr_text" >&2
    exit 1
fi
exec "$real_git" "\$@"
EOF
    chmod +x "$wrapper_dir/git"
}

_install_git_wrapper_with_env_check() {
    local wrapper_dir="$1" command_to_fail="$2" env_dump_file="$3" stderr_text="$4"
    local real_git
    real_git="$(command -v git)"

    mkdir -p "$wrapper_dir"
    cat > "$wrapper_dir/git" <<EOF
#!/bin/bash
if [ "\$1" = "$command_to_fail" ]; then
    printf 'GIT_TERMINAL_PROMPT=%s\nGIT_SSH_COMMAND=%s\n' "\${GIT_TERMINAL_PROMPT:-}" "\${GIT_SSH_COMMAND:-}" > "$env_dump_file"
    printf '%s\n' "$stderr_text" >&2
    exit 1
fi
exec "$real_git" "\$@"
EOF
    chmod +x "$wrapper_dir/git"
}

# ---------- 心跳 ----------

test_heartbeat_written() {
    local before
    before=$(date +%s)

    bash "$SYNC_CMD" >/dev/null 2>&1 || true

    if [ ! -f "$ZEROMD_STATE_DIR/last-heartbeat" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    last-heartbeat file not found\n"
        return
    fi

    local hb
    hb=$(cat "$ZEROMD_STATE_DIR/last-heartbeat")
    local after
    after=$(date +%s)

    # 心跳应在 before 和 after 之间
    if [ "$hb" -lt "$before" ] || [ "$hb" -gt "$after" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    heartbeat $hb not between $before and $after\n"
    fi
}

# ---------- 无变更 ----------

test_no_changes_skip() {
    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "0" "$rc" "should exit 0 with no changes"

    if [ -f "$ZEROMD_STATE_DIR/last-sync" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    last-sync should not exist when no changes\n"
    fi
}

test_pushes_existing_local_commit_when_branch_is_ahead() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    echo "already committed" > "$ZEROMD_TEST_VAULT/already-committed.md"
    git -C "$ZEROMD_TEST_VAULT" add already-committed.md
    git -C "$ZEROMD_TEST_VAULT" commit -m "local ahead" --quiet --no-gpg-sign

    printf '%s\t%s\t%s\n' \
        "$ZEROMD_TEST_VAULT" \
        "$bare_remote" \
        "main" > "$ZEROMD_STATE_DIR/upstream-established"

    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "0" "$rc" "sync should push existing local commit when branch is ahead"

    local branch_line remote_head head_after
    branch_line=$(git -C "$ZEROMD_TEST_VAULT" status --short --branch | head -n1)
    head_after=$(git -C "$ZEROMD_TEST_VAULT" rev-parse HEAD)
    remote_head=$(git -C "$ZEROMD_TEST_VAULT" rev-parse origin/main)

    assert_eq "$remote_head" "$head_after" "origin/main should catch up to local HEAD"
    if echo "$branch_line" | grep -q '\[ahead '; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    branch should no longer be ahead after sync push\n"
    fi

    rm -rf "$bare_remote"
}

test_first_sync_marks_upstream_established_without_last_sync() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "0" "$rc" "first upstream check should succeed"

    if [ ! -f "$ZEROMD_STATE_DIR/upstream-established" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    upstream-established should be written on first successful upstream check\n"
    fi

    if [ -f "$ZEROMD_STATE_DIR/last-sync" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    last-sync should still not exist when there are no changes\n"
    fi

    rm -rf "$bare_remote"
}

test_first_sync_backup_and_reset_when_local_main_ahead() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    echo "local only" > "$ZEROMD_TEST_VAULT/local.md"
    git -C "$ZEROMD_TEST_VAULT" add local.md
    git -C "$ZEROMD_TEST_VAULT" commit -m "local only" --quiet --no-gpg-sign

    local local_head_before remote_head rc backup_branch backup_head head_after
    local_head_before=$(git -C "$ZEROMD_TEST_VAULT" rev-parse HEAD)
    remote_head=$(git -C "$ZEROMD_TEST_VAULT" rev-parse origin/main)

    rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "0" "$rc" "first sync should recover by backing up and resetting"

    backup_branch="$(_find_backup_branch)"
    if [ -z "$backup_branch" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    backup branch should be created when local main is ahead of origin/main\n"
    else
        backup_head=$(git -C "$ZEROMD_TEST_VAULT" rev-parse "$backup_branch")
        assert_eq "$local_head_before" "$backup_head" "backup branch should preserve pre-reset local HEAD"
    fi

    head_after=$(git -C "$ZEROMD_TEST_VAULT" rev-parse HEAD)
    assert_eq "$remote_head" "$head_after" "main should be reset to origin/main"

    rm -rf "$bare_remote"
}

test_first_sync_backup_preserves_dirty_worktree_before_reset() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"
    _push_commit_to_remote "$bare_remote" "remote.md" "from remote"

    echo "draft" > "$ZEROMD_TEST_VAULT/draft.md"

    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "0" "$rc" "first sync should recover from dirty stale worktree"

    local backup_branch
    backup_branch="$(_find_backup_branch)"
    if [ -z "$backup_branch" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    backup branch should be created before resetting dirty worktree\n"
    else
        local backup_files
        backup_files=$(git -C "$ZEROMD_TEST_VAULT" ls-tree -r --name-only "$backup_branch")
        assert_contains "$backup_files" "draft.md" "backup branch should preserve dirty worktree changes"
    fi

    local head_after remote_head
    head_after=$(git -C "$ZEROMD_TEST_VAULT" rev-parse HEAD)
    remote_head=$(git -C "$ZEROMD_TEST_VAULT" rev-parse origin/main)
    assert_eq "$remote_head" "$head_after" "main should be reset to remote HEAD after backup"

    if [ -f "$ZEROMD_TEST_VAULT/draft.md" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    draft.md should not remain in main worktree after reset\n"
    fi

    rm -rf "$bare_remote"
}

# ---------- rebase 检测 ----------

test_rebase_detected() {
    mkdir -p "$ZEROMD_TEST_VAULT/.git/rebase-merge"

    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?

    assert_exit_code "1" "$rc" "should exit 1 on rebase"

    local err
    err=$(cat "$ZEROMD_STATE_DIR/last-error")
    assert_contains "$err" "REBASE" "error should mention REBASE"
}

# ---------- consecutive failures ----------

test_consecutive_failures() {
    mkdir -p "$ZEROMD_TEST_VAULT/.git/rebase-merge"

    bash "$SYNC_CMD" >/dev/null 2>&1 || true
    local count1
    count1=$(cat "$ZEROMD_STATE_DIR/consecutive-failures")
    assert_eq "1" "$count1" "first failure should be 1"

    bash "$SYNC_CMD" >/dev/null 2>&1 || true
    local count2
    count2=$(cat "$ZEROMD_STATE_DIR/consecutive-failures")
    assert_eq "2" "$count2" "second failure should be 2"
}

# ---------- record_success 机制 ----------

test_success_clears_error() {
    # 预先写入错误状态
    echo "old error" > "$ZEROMD_STATE_DIR/last-error"
    echo "3" > "$ZEROMD_STATE_DIR/consecutive-failures"

    # 设置 bare remote
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    # 制造变更
    echo "test content" > "$ZEROMD_TEST_VAULT/test.md"

    # 执行同步
    local rc=0
    bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?
    assert_exit_code "0" "$rc" "sync should succeed"

    # last-error 应被删除
    if [ -f "$ZEROMD_STATE_DIR/last-error" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    last-error file should have been deleted\n"
    fi

    # consecutive-failures 应归零
    local failures
    failures=$(cat "$ZEROMD_STATE_DIR/consecutive-failures")
    assert_eq "0" "$failures" "consecutive-failures should be 0"

    rm -rf "$bare_remote"
}

# ---------- git error classification ----------

test_classify_https_auth_error() {
    local rc=0 output
    output="$(
        (
            export ZEROMD_SYNC_SOURCE_ONLY=1
            source "$SYNC_CMD"
            classify_git_error "push" "remote: Invalid username or token. Password authentication is not supported for Git operations."
        )
    )" || rc=$?

    assert_exit_code "0" "$rc" "sync helpers should be sourceable"
    if [ "$rc" -eq 0 ]; then
        assert_contains "$output" "HTTPS authentication failed" "should identify HTTPS auth failure"
        assert_contains "$output" "account passwords" "should mention password auth is unsupported"
    fi
}

test_classify_ssh_auth_error() {
    local rc=0 output
    output="$(
        (
            export ZEROMD_SYNC_SOURCE_ONLY=1
            source "$SYNC_CMD"
            classify_git_error "push" "git@github.com: Permission denied (publickey)."
        )
    )" || rc=$?

    assert_exit_code "0" "$rc" "sync helpers should be sourceable"
    [ "$rc" -eq 0 ] && assert_contains "$output" "SSH authentication failed" "should identify SSH auth failure"
}

test_push_https_auth_failure_is_recorded_clearly() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    echo "test content" > "$ZEROMD_TEST_VAULT/test.md"

    local wrapper_dir
    wrapper_dir="$(mktemp -d)"
    _install_git_wrapper "$wrapper_dir" "push" "remote: Invalid username or token.
remote: Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/user/repo.git/'"

    local rc=0 old_path="$PATH"
    PATH="$wrapper_dir:$PATH" bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?
    PATH="$old_path"

    assert_exit_code "1" "$rc" "sync should fail when push authentication fails"

    local err
    err=$(cat "$ZEROMD_STATE_DIR/last-error")
    assert_contains "$err" "HTTPS authentication failed" "last-error should explain HTTPS auth failure"

    rm -rf "$wrapper_dir" "$bare_remote"
}

test_push_runs_in_noninteractive_mode() {
    local bare_remote
    bare_remote="$(_setup_bare_remote)"

    echo "test content" > "$ZEROMD_TEST_VAULT/test.md"

    local wrapper_dir env_dump
    wrapper_dir="$(mktemp -d)"
    env_dump="$(mktemp)"
    _install_git_wrapper_with_env_check "$wrapper_dir" "push" "$env_dump" "git@github.com: Permission denied (publickey)."

    local rc=0 old_path="$PATH"
    PATH="$wrapper_dir:$PATH" bash "$SYNC_CMD" >/dev/null 2>&1 || rc=$?
    PATH="$old_path"

    assert_exit_code "1" "$rc" "sync should fail cleanly when noninteractive push auth fails"

    if [ ! -f "$env_dump" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    wrapper should capture git env for push\n"
    else
        local env_output
        env_output="$(cat "$env_dump")"
        assert_contains "$env_output" "GIT_TERMINAL_PROMPT=0" "push should disable terminal prompts"
        assert_contains "$env_output" "BatchMode=yes" "push should force SSH batch mode"
    fi

    rm -rf "$wrapper_dir" "$bare_remote"
    rm -f "$env_dump"
}
