#!/bin/bash
# PostToolUse hook: scripts/ 下文件被修改时提醒运行测试
input=$(cat)

if echo "$input" | grep -q '"scripts/'; then
    echo "scripts/ 下的文件已修改，建议运行 /test 验证"
fi
