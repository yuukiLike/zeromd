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
