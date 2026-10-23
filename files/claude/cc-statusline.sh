#!/bin/bash
# Claude Code statusLine：
#   1. 输出 Claude 底部那一行：模型 · 上下文占用（属于这个会话的信息）
#   2. 把账号级的 5 小时 / 7 天额度写进 tmux 全局选项，供 ~/.tmux.conf 状态栏右侧显示
#      @cc_5h / @cc_7d = 已用百分比（整数），@cc_5h_ts / @cc_7d_ts = 重置时间（epoch），@cc_5h_at / @cc_7d_at = 重置时间（可读）
#   不在 tmux 里时，额度直接显示在 Claude 底部这一行。
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
US=$'\x1f'

IFS="$US" read -r model ctx p5 r5 p7 r7 < <(jq -r '[
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

if [ -n "$p5$p7" ]; then
  if [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
    args=()
    [ -n "$p5" ] && args+=(set -gq @cc_5h "$(int "$p5")" ';' set -gq @cc_5h_ts "$r5" ';' set -gq @cc_5h_at "$(date -r "$r5" +%H:%M)" ';')
    [ -n "$p7" ] && args+=(set -gq @cc_7d "$(int "$p7")" ';' set -gq @cc_7d_ts "$r7" ';' set -gq @cc_7d_at "$(date -r "$r7" +%m/%d)" ';')
    tmux "${args[@]}" 2>/dev/null
  else
    [ -n "$p5" ] && { p=$(int "$p5"); line+=$(printf ' · 5h %s%s%%\033[0m' "$(color "$p")" "$p"); }
    [ -n "$p7" ] && { p=$(int "$p7"); line+=$(printf ' · 7d %s%s%%\033[0m' "$(color "$p")" "$p"); }
  fi
fi
printf '%s\n' "$line"
