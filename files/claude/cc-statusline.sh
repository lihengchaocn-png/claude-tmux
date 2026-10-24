#!/bin/bash
# Claude Code statusLine：输出 Claude 底部那一行
#   模型 · 上下文占用 · 5 小时 / 7 天额度（额度是整个账号共享的）
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
US=$'\x1f'

IFS="$US" read -r model ctx p5 _ p7 _ < <(jq -r '[
    .model.display_name // "",
    (.context_window.used_percentage // "" | tostring),
    (.rate_limits.five_hour.used_percentage // "" | tostring),
    (.rate_limits.five_hour.resets_at // "" | tostring),
    (.rate_limits.seven_day.used_percentage // "" | tostring),
    (.rate_limits.seven_day.resets_at // "" | tostring)
  ] | join("\u001f")')

# 已用百分比 → 颜色：<50 绿，<80 黄，≥80 红
color() { if [ "$1" -ge 80 ]; then printf '\033[31m'; elif [ "$1" -ge 50 ]; then printf '\033[33m'; else printf '\033[32m'; fi; }
int() { printf '%.0f' "$1"; }

line="$model"
if [ -n "$ctx" ]; then
  c=$(int "$ctx"); line+=$(printf ' · ctx %s%s%%\033[0m' "$(color "$c")" "$c")
fi

[ -n "$p5" ] && { p=$(int "$p5"); line+=$(printf ' · 5h %s%s%%\033[0m' "$(color "$p")" "$p"); }
[ -n "$p7" ] && { p=$(int "$p7"); line+=$(printf ' · 7d %s%s%%\033[0m' "$(color "$p")" "$p"); }
printf '%s\n' "$line"
