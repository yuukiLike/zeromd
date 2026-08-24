#!/bin/bash
# zeromd CLI 子命令测试

ZEROMD_CMD="$PROJECT_DIR/scripts/zeromd"

prepare_fake_osascript() {
    ZEROMD_FAKE_BIN="$ZEROMD_STATE_DIR/fake-bin"
    mkdir -p "$ZEROMD_FAKE_BIN"
    cat > "$ZEROMD_FAKE_BIN/osascript" <<'EOF'
#!/bin/bash
if [ "${ZEROMD_TEST_OSASCRIPT_FAIL:-0}" = "1" ]; then
    exit 1
fi
printf '%s' "${ZEROMD_TEST_OSASCRIPT_OUTPUT:-}"
EOF
    chmod +x "$ZEROMD_FAKE_BIN/osascript"
}

# ---------- status 子命令 ----------

test_status_normal() {
    local now
    now=$(date +%s)
    echo "$now" > "$ZEROMD_STATE_DIR/last-heartbeat"
    echo "$((now - 180))" > "$ZEROMD_STATE_DIR/last-sync"

    local output
    output=$(bash "$ZEROMD_CMD" status 2>&1)

    assert_contains "$output" "✓" "should contain checkmark"
    assert_contains "$output" "synced" "should contain synced"
}

test_status_error() {
    local now
    now=$(date +%s)
    echo "$now" > "$ZEROMD_STATE_DIR/last-heartbeat"
    echo "push failed" > "$ZEROMD_STATE_DIR/last-error"

    local output
    output=$(bash "$ZEROMD_CMD" status 2>&1)

    assert_contains "$output" "✗" "should contain error mark"
    assert_contains "$output" "push failed" "should show error message"
}

test_status_daemon_dead() {
    local now
    now=$(date +%s)
    echo "$((now - 900))" > "$ZEROMD_STATE_DIR/last-heartbeat"

    local output
    output=$(bash "$ZEROMD_CMD" status 2>&1)

    assert_contains "$output" "⚠" "should contain warning"
    assert_contains "$output" "daemon not running" "should say daemon not running"
}

test_status_no_heartbeat() {
    # setup_test_env 已写入 vault-path，但不写 heartbeat

    local output
    output=$(bash "$ZEROMD_CMD" status 2>&1)

    assert_contains "$output" "⚠" "should contain warning"
}

# ---------- sync 子命令 ----------

test_sync_success_reports_status() {
    local rc=0 output
    output=$(bash "$ZEROMD_CMD" sync 2>&1) || rc=$?

    assert_exit_code "0" "$rc" "successful sync should return zero"
    assert_contains "$output" "daemon running" "successful sync should show current status"
}

test_sync_failure_reports_error_and_preserves_exit_code() {
    mkdir -p "$ZEROMD_TEST_VAULT/.git/rebase-merge"

    local rc=0 output
    output=$(bash "$ZEROMD_CMD" sync 2>&1) || rc=$?

    assert_exit_code "1" "$rc" "failed sync should preserve the sync exit code"
    assert_contains "$output" "sync failed (exit code: 1)" "failed sync should show a clear summary"
    assert_contains "$output" "REBASE_CONFLICT" "failed sync should show the recorded error"
    assert_contains "$output" "gmd log" "failed sync should point to detailed logs"
    assert_contains "$output" "gmd doctor" "failed sync should point to diagnostics"
}

# ---------- log 子命令 ----------

test_log_default() {
    local log_file="$ZEROMD_STATE_DIR/sync.log"
    for i in $(seq 1 25); do
        echo "log line $i" >> "$log_file"
    done

    local output
    output=$(bash "$ZEROMD_CMD" log 2>&1)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    assert_eq "20" "$line_count" "should show 20 lines by default"
}

test_log_custom_n() {
    local log_file="$ZEROMD_STATE_DIR/sync.log"
    for i in $(seq 1 25); do
        echo "log line $i" >> "$log_file"
    done

    local output
    output=$(bash "$ZEROMD_CMD" log 5 2>&1)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    assert_eq "5" "$line_count" "should show 5 lines"
}

# ---------- help 子命令 ----------

test_help_chinese() {
    local output
    output=$(bash "$ZEROMD_CMD" help zh 2>&1)

    assert_contains "$output" "用法: gmd <command>" "should show Chinese usage"
    assert_contains "$output" "命令:" "should show Chinese command heading"
    assert_contains "$output" "健康检查" "should describe doctor in Chinese"
    assert_contains "$output" "doctor [LANG]" "should keep language syntax compact"
    assert_contains "$output" "zh / cn / en / ja" "should list supported language inputs"
    assert_not_contains "$output" "Usage:" "Chinese help should not mix English"

    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    assert_eq "15" "$line_count" "Chinese help should stay compact"
}

test_help_english() {
    local output
    output=$(bash "$ZEROMD_CMD" help en 2>&1)

    assert_contains "$output" "Usage: gmd <command>" "should show English usage"
    assert_contains "$output" "Commands:" "should show English command heading"
    assert_contains "$output" "Health check" "should describe doctor in English"
    assert_contains "$output" "doctor [LANG]" "should keep language syntax compact"
    assert_contains "$output" "zh / cn / en / ja" "should list supported language inputs"
    assert_not_contains "$output" "用法:" "English help should not mix Chinese"

    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    assert_eq "15" "$line_count" "English help should stay compact"
}

test_help_japanese() {
    local output
    output=$(bash "$ZEROMD_CMD" help ja 2>&1)

    assert_contains "$output" "使い方: gmd <command>" "should show Japanese usage"
    assert_contains "$output" "コマンド:" "should show Japanese command heading"
    assert_contains "$output" "ヘルスチェック" "should describe doctor in Japanese"
    assert_contains "$output" "doctor [LANG]" "should keep language syntax compact"
    assert_contains "$output" "zh / cn / en / ja" "should list supported language inputs"
    assert_not_contains "$output" "Usage:" "Japanese help should not mix English headings"
    assert_not_contains "$output" "用法:" "Japanese help should not mix Chinese headings"

    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    assert_eq "15" "$line_count" "Japanese help should stay compact"
}

test_help_cn_is_chinese_alias() {
    local zh_output cn_output uppercase_output
    zh_output=$(bash "$ZEROMD_CMD" help zh 2>&1)
    cn_output=$(bash "$ZEROMD_CMD" help cn 2>&1)
    uppercase_output=$(bash "$ZEROMD_CMD" help CN 2>&1)

    assert_eq "$zh_output" "$cn_output" "cn should be an exact alias for zh"
    assert_eq "$zh_output" "$uppercase_output" "language aliases should be case-insensitive"
}

test_help_locale_variants() {
    local output
    output=$(bash "$ZEROMD_CMD" help ja_JP.UTF-8 2>&1)
    assert_contains "$output" "使い方:" "Japanese locale variant should select Japanese"

    output=$(bash "$ZEROMD_CMD" help en_CN 2>&1)
    assert_contains "$output" "Usage:" "en_CN should remain English"
    assert_not_contains "$output" "用法:" "en_CN must not be treated as cn alias"
}

test_help_follows_macos_preferred_language() {
    prepare_fake_osascript

    local output
    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" \
        ZEROMD_TEST_OSASCRIPT_OUTPUT='zh-Hans-CN' \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=C \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "用法:" "macOS Chinese preference should select Chinese"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" \
        ZEROMD_TEST_OSASCRIPT_OUTPUT=$'fr-FR\nja-JP' \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=C \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "使い方:" "first supported macOS preference should be selected"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" \
        ZEROMD_TEST_OSASCRIPT_OUTPUT=$'fr-FR\nde-DE' \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=zh \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "用法:" "unsupported macOS preferences should fall back to locale"
}

test_help_falls_back_to_locale() {
    prepare_fake_osascript

    local output
    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" ZEROMD_TEST_OSASCRIPT_FAIL=1 \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=zh \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "用法:" "zh locale should select Chinese when macOS lookup fails"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" ZEROMD_TEST_OSASCRIPT_FAIL=1 \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=ja_JP.UTF-8 \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "使い方:" "ja locale should select Japanese when macOS lookup fails"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" ZEROMD_TEST_OSASCRIPT_FAIL=1 \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES= LANG=fr_FR \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "Usage:" "unsupported locale should fall back to English"
}

test_help_explicit_language_overrides_environment_and_system() {
    prepare_fake_osascript

    local output
    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" \
        ZEROMD_TEST_OSASCRIPT_OUTPUT='ja-JP' ZEROMD_LANG=zh \
        bash "$ZEROMD_CMD" help en 2>&1)

    assert_contains "$output" "Usage:" "explicit language should override environment and system"
}

test_help_language_precedence() {
    prepare_fake_osascript

    local output

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" \
        ZEROMD_TEST_OSASCRIPT_OUTPUT='ja-JP' \
        ZEROMD_LANG=zh LC_ALL=en LC_MESSAGES=en LANG=en \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "用法:" "ZEROMD_LANG should override system and locale"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" ZEROMD_TEST_OSASCRIPT_FAIL=1 \
        ZEROMD_LANG= LC_ALL=en LC_MESSAGES=zh LANG=zh \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "Usage:" "LC_ALL should override lower-priority locale"

    output=$(PATH="$ZEROMD_FAKE_BIN:$PATH" ZEROMD_TEST_OSASCRIPT_FAIL=1 \
        ZEROMD_LANG= LC_ALL= LC_MESSAGES=zh LANG=en \
        bash "$ZEROMD_CMD" help 2>&1)
    assert_contains "$output" "用法:" "LC_MESSAGES should override LANG"
}

test_help_flags_accept_language() {
    local output

    output=$(bash "$ZEROMD_CMD" --help en 2>&1)
    assert_contains "$output" "Usage:" "--help should accept language"

    output=$(bash "$ZEROMD_CMD" -h zh 2>&1)
    assert_contains "$output" "用法:" "-h should accept language"

    output=$(bash "$ZEROMD_CMD" --help ja 2>&1)
    assert_contains "$output" "使い方:" "--help should accept Japanese"
}

test_help_rejects_invalid_language() {
    local rc=0
    local output
    output=$(ZEROMD_LANG=en bash "$ZEROMD_CMD" help fr 2>&1) || rc=$?

    assert_exit_code "2" "$rc" "invalid help language should exit 2"
    assert_contains "$output" "zh / cn / en / ja" "should explain valid languages"

    rc=0
    output=$(ZEROMD_LANG=en bash "$ZEROMD_CMD" help jp 2>&1) || rc=$?
    assert_exit_code "2" "$rc" "jp should not be accepted as the Japanese language code"
}

# ---------- 未知命令 ----------

test_unknown_cmd_chinese() {
    local rc=0
    local output
    output=$(ZEROMD_LANG=zh bash "$ZEROMD_CMD" badcmd 2>&1) || rc=$?

    assert_exit_code "1" "$rc" "should exit 1 for unknown command"
    assert_contains "$output" "未知命令" "should say unknown command"
    assert_not_contains "$output" "Unknown command" "Chinese error should not mix English"
}

test_unknown_cmd_english() {
    local rc=0
    local output
    output=$(ZEROMD_LANG=en bash "$ZEROMD_CMD" badcmd 2>&1) || rc=$?

    assert_exit_code "1" "$rc" "should exit 1 for unknown command"
    assert_contains "$output" "Unknown command" "should say unknown command"
    assert_not_contains "$output" "未知命令" "English error should not mix Chinese"
}

test_unknown_cmd_japanese() {
    local rc=0
    local output
    output=$(ZEROMD_LANG=ja bash "$ZEROMD_CMD" badcmd 2>&1) || rc=$?

    assert_exit_code "1" "$rc" "should exit 1 for unknown command"
    assert_contains "$output" "不明なコマンド" "should say unknown command in Japanese"
    assert_not_contains "$output" "Unknown command" "Japanese error should not mix English"
    assert_not_contains "$output" "未知命令" "Japanese error should not mix Chinese"
}

# ---------- doctor 子命令 ----------

prepare_doctor_healthy() {
    local now
    now=$(date +%s)
    echo "$now" > "$ZEROMD_STATE_DIR/last-heartbeat"

    local bare_remote
    bare_remote="$ZEROMD_STATE_DIR/bare-remote.git"
    git init --bare --quiet "$bare_remote"
    git -C "$ZEROMD_TEST_VAULT" remote add origin "$bare_remote"
}

test_doctor_healthy_english() {
    prepare_doctor_healthy

    local output
    output=$(ZEROMD_LANG=zh bash "$ZEROMD_CMD" doctor en 2>&1)

    assert_contains "$output" "✓ Vault path exists" "vault check"
    assert_contains "$output" "✓ Git repo OK" "git repo check"
    assert_contains "$output" "✓ Git remote configured" "remote check"
    assert_contains "$output" "✓ Last heartbeat" "heartbeat check"
    assert_not_contains "$output" "Vault 路径存在" "English doctor should not mix Chinese labels"
}

test_doctor_healthy_chinese() {
    prepare_doctor_healthy

    local output
    output=$(bash "$ZEROMD_CMD" doctor zh 2>&1)

    assert_contains "$output" "✓ Vault 路径存在" "vault check"
    assert_contains "$output" "✓ Git 仓库正常" "git repo check"
    assert_contains "$output" "✓ Git remote 已配置" "remote check"
    assert_contains "$output" "✓ 上次心跳" "heartbeat check"
    assert_contains "$output" "前" "heartbeat time should be Chinese"
    assert_not_contains "$output" "Vault path exists" "Chinese doctor should not mix English labels"
}

test_doctor_healthy_japanese() {
    prepare_doctor_healthy

    local output
    output=$(bash "$ZEROMD_CMD" doctor ja 2>&1)

    assert_contains "$output" "✓ Vault パスが存在します" "vault check"
    assert_contains "$output" "✓ Git リポジトリは正常です" "git repo check"
    assert_contains "$output" "✓ Git リモートを設定済み" "remote check"
    assert_contains "$output" "✓ 前回のハートビート" "heartbeat check"
    assert_contains "$output" "前" "heartbeat time should be Japanese"
    assert_not_contains "$output" "Vault path exists" "Japanese doctor should not mix English labels"
    assert_not_contains "$output" "Vault 路径存在" "Japanese doctor should not mix Chinese labels"
}

test_doctor_no_vault_english() {
    rm -f "$ZEROMD_STATE_DIR/vault-path"

    local rc=0
    local output
    output=$(bash "$ZEROMD_CMD" doctor en 2>&1) || rc=$?

    assert_exit_code "0" "$rc" "diagnostic failures should preserve exit 0"
    assert_contains "$output" "✗ Vault path missing or not configured" "no vault check"
}

test_doctor_no_vault_chinese() {
    rm -f "$ZEROMD_STATE_DIR/vault-path"

    local output
    output=$(bash "$ZEROMD_CMD" doctor zh 2>&1)

    assert_contains "$output" "✗ Vault 路径不存在或未配置" "no vault check"
}

test_doctor_stale_heartbeat_chinese() {
    local now
    now=$(date +%s)
    echo "$((now - 900))" > "$ZEROMD_STATE_DIR/last-heartbeat"

    local output
    output=$(bash "$ZEROMD_CMD" doctor zh 2>&1)

    assert_contains "$output" "⚠ 上次心跳" "stale heartbeat check"
    assert_contains "$output" "超过 10 分钟" "stale heartbeat should be Chinese"
}

test_doctor_stale_heartbeat_japanese() {
    local now
    now=$(date +%s)
    echo "$((now - 900))" > "$ZEROMD_STATE_DIR/last-heartbeat"

    local output
    output=$(bash "$ZEROMD_CMD" doctor ja 2>&1)

    assert_contains "$output" "⚠ 前回のハートビート" "stale heartbeat check"
    assert_contains "$output" "15分前" "heartbeat time should be Japanese"
    assert_contains "$output" "10分超" "stale heartbeat warning should be Japanese"
}

test_doctor_japanese_preserves_raw_error() {
    echo "remote rejected: non-fast-forward" > "$ZEROMD_STATE_DIR/last-error"

    local output
    output=$(bash "$ZEROMD_CMD" doctor ja 2>&1)

    assert_contains "$output" "前回の同期に失敗" "error label should be Japanese"
    assert_contains "$output" "remote rejected: non-fast-forward" "raw Git error should be preserved"
}

test_doctor_rejects_invalid_language() {
    local rc=0
    local output
    output=$(ZEROMD_LANG=en bash "$ZEROMD_CMD" doctor fr 2>&1) || rc=$?

    assert_exit_code "2" "$rc" "invalid doctor language should exit 2"
    assert_contains "$output" "zh / cn / en / ja" "should explain valid languages"
}
