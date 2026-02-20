#!/bin/bash
# cc-md test runner — 纯 bash 实现，零依赖
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0
_CURRENT_TEST_FAILED=0
_ASSERT_MSGS=""

# ---------- 断言函数 ----------

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-assert_eq}"
    if [ "$expected" != "$actual" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    ${RED}✗ $msg${NC}\n      expected: '$expected'\n      actual:   '$actual'\n"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-assert_contains}"
    if ! echo "$haystack" | grep -qF "$needle"; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    ${RED}✗ $msg${NC}\n      needle: '$needle' not found in output\n"
    fi
}

assert_exit_code() {
    local expected="$1" actual="$2" msg="${3:-assert_exit_code}"
    if [ "$expected" != "$actual" ]; then
        _CURRENT_TEST_FAILED=1
        _ASSERT_MSGS+="    ${RED}✗ $msg${NC}\n      expected exit code: $expected, got: $actual\n"
    fi
}

# ---------- 测试环境 ----------

setup_test_env() {
    CC_MD_STATE_DIR="$(mktemp -d)"
    CC_MD_TEST_VAULT="$(mktemp -d)"
    export CC_MD_STATE_DIR CC_MD_TEST_VAULT
    mkdir -p "$CC_MD_STATE_DIR"

    # 创建 mock vault（有初始提交的 git repo）
    git -C "$CC_MD_TEST_VAULT" init -b main --quiet
    git -C "$CC_MD_TEST_VAULT" config user.email "test@test.com"
    git -C "$CC_MD_TEST_VAULT" config user.name "Test"
    touch "$CC_MD_TEST_VAULT/.gitkeep"
    git -C "$CC_MD_TEST_VAULT" add .gitkeep
    git -C "$CC_MD_TEST_VAULT" commit -m "init" --quiet --no-gpg-sign

    # 写入 vault 配置
    echo "$CC_MD_TEST_VAULT" > "$CC_MD_STATE_DIR/vault-path"
    export CC_MD_VAULT_DIR="$CC_MD_TEST_VAULT"
    export CC_MD_LOG_FILE="$CC_MD_STATE_DIR/sync.log"
}

teardown_test_env() {
    [ -n "${CC_MD_STATE_DIR:-}" ] && rm -rf "$CC_MD_STATE_DIR"
    [ -n "${CC_MD_TEST_VAULT:-}" ] && rm -rf "$CC_MD_TEST_VAULT"
    unset CC_MD_STATE_DIR CC_MD_TEST_VAULT CC_MD_VAULT_DIR CC_MD_LOG_FILE 2>/dev/null || true
}

# ---------- 运行测试 ----------

run_test_file() {
    local file="$1"
    local filename
    filename="$(basename "$file")"
    echo -e "\n${BOLD}=== $filename ===${NC}"

    # source 测试文件（定义 test_* 函数）
    source "$file"

    # 发现并运行所有 test_* 函数
    local funcs
    funcs=$(declare -F | awk '{print $3}' | grep '^test_' | sort)

    for func in $funcs; do
        setup_test_env
        _CURRENT_TEST_FAILED=0
        _ASSERT_MSGS=""

        # 在当前 shell 中运行测试函数
        "$func"

        TOTAL=$((TOTAL + 1))
        if [ $_CURRENT_TEST_FAILED -eq 0 ]; then
            PASSED=$((PASSED + 1))
            echo -e "  ${GREEN}✓${NC} $func"
        else
            FAILED=$((FAILED + 1))
            echo -e "  ${RED}✗${NC} $func"
            echo -e "$_ASSERT_MSGS"
        fi

        teardown_test_env
        unset -f "$func" 2>/dev/null || true
    done
}

# ---------- Main ----------

echo -e "${BOLD}cc-md test suite${NC}"

for test_file in "$TESTS_DIR"/test_*.sh; do
    [ -f "$test_file" ] || continue
    run_test_file "$test_file"
done

echo ""
echo "=========================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All $TOTAL tests passed${NC}"
else
    echo -e "${RED}$FAILED failed${NC}, $PASSED passed, $TOTAL total"
fi
echo "=========================="

[ $FAILED -gt 0 ] && exit 1
exit 0
