#!/bin/bash
# cc-md CLI 子命令测试

CC_MD_CMD="$PROJECT_DIR/scripts/cc-md"

# ---------- status 子命令 ----------

test_status_normal() {
    local now
    now=$(date +%s)
    echo "$now" > "$CC_MD_STATE_DIR/last-heartbeat"
    echo "$((now - 180))" > "$CC_MD_STATE_DIR/last-sync"

    local output
    output=$(bash "$CC_MD_CMD" status 2>&1)

    assert_contains "$output" "✓" "should contain checkmark"
    assert_contains "$output" "synced" "should contain synced"
}

test_status_error() {
    local now
    now=$(date +%s)
    echo "$now" > "$CC_MD_STATE_DIR/last-heartbeat"
    echo "push failed" > "$CC_MD_STATE_DIR/last-error"

    local output
    output=$(bash "$CC_MD_CMD" status 2>&1)

    assert_contains "$output" "✗" "should contain error mark"
    assert_contains "$output" "push failed" "should show error message"
}

test_status_daemon_dead() {
    local now
    now=$(date +%s)
    echo "$((now - 900))" > "$CC_MD_STATE_DIR/last-heartbeat"

    local output
    output=$(bash "$CC_MD_CMD" status 2>&1)

    assert_contains "$output" "⚠" "should contain warning"
    assert_contains "$output" "daemon not running" "should say daemon not running"
}

test_status_no_heartbeat() {
    # setup_test_env 已写入 vault-path，但不写 heartbeat

    local output
    output=$(bash "$CC_MD_CMD" status 2>&1)

    assert_contains "$output" "⚠" "should contain warning"
}

# ---------- log 子命令 ----------

test_log_default() {
    local log_file="$CC_MD_STATE_DIR/sync.log"
    for i in $(seq 1 25); do
        echo "log line $i" >> "$log_file"
    done

    local output
    output=$(bash "$CC_MD_CMD" log 2>&1)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    assert_eq "20" "$line_count" "should show 20 lines by default"
}

test_log_custom_n() {
    local log_file="$CC_MD_STATE_DIR/sync.log"
    for i in $(seq 1 25); do
        echo "log line $i" >> "$log_file"
    done

    local output
    output=$(bash "$CC_MD_CMD" log 5 2>&1)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    assert_eq "5" "$line_count" "should show 5 lines"
}

# ---------- help 子命令 ----------

test_help() {
    local output
    output=$(bash "$CC_MD_CMD" help 2>&1)

    assert_contains "$output" "md" "should contain md"
    assert_contains "$output" "status" "should contain status"
    assert_contains "$output" "doctor" "should contain doctor"
}

# ---------- 未知命令 ----------

test_unknown_cmd() {
    local rc=0
    local output
    output=$(bash "$CC_MD_CMD" badcmd 2>&1) || rc=$?

    assert_exit_code "1" "$rc" "should exit 1 for unknown command"
    assert_contains "$output" "未知命令" "should say unknown command"
}

# ---------- doctor 子命令 ----------

test_doctor_healthy() {
    local now
    now=$(date +%s)
    echo "$now" > "$CC_MD_STATE_DIR/last-heartbeat"

    # 添加 remote
    local bare_remote
    bare_remote="$(mktemp -d)"
    git init --bare --quiet "$bare_remote"
    git -C "$CC_MD_TEST_VAULT" remote add origin "$bare_remote"

    local output
    output=$(bash "$CC_MD_CMD" doctor 2>&1)

    assert_contains "$output" "✓ vault 路径存在" "vault check"
    assert_contains "$output" "✓ Git 仓库正常" "git repo check"
    assert_contains "$output" "✓ Git remote 已配置" "remote check"
    assert_contains "$output" "✓ 上次心跳" "heartbeat check"

    rm -rf "$bare_remote"
}

test_doctor_no_vault() {
    rm -f "$CC_MD_STATE_DIR/vault-path"

    local output
    output=$(bash "$CC_MD_CMD" doctor 2>&1)

    assert_contains "$output" "✗ vault 路径不存在或未配置" "no vault check"
}
