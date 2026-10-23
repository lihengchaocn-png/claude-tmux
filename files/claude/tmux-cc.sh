#!/bin/bash
# Claude Code ↔ tmux 状态提醒
#   状态按 pane 记录（pane 选项 @cc_p = run|ask|done，@cc_t = 进入 ask/done 的时间戳），
#   再按优先级 ask > done > run 汇总到 window 选项 @cc_w、session 选项 @cc_s，供 ~/.tmux.conf 状态栏上色。
# 用法：
#   tmux-cc.sh                  Claude Code hook（从 stdin 读事件 JSON）
#   tmux-cc.sh focus <pane>     tmux 切换焦点后调用：清掉该 pane 的 done，并清理残留
#   tmux-cc.sh gc               清理 Claude 已不在的 pane 上的残留状态，并重新汇总
#   tmux-cc.sh jump [client]    fzf 列出所有 Claude pane（等确认 > 跑完 > 在跑），回车跳过去
#   tmux-cc.sh next [client]    直接跳到最早开始等你的那个（没有则最早跑完的）
#   tmux-cc.sh list             调试：输出排序后的列表
#   tmux-cc.sh usage-cache      没有实时额度时，用 ~/.claude.json 里 Claude 缓存的额度兜底（tmux 启动时调用）
#   tmux-cc.sh usage            prefix u 弹窗：额度详情 + 最近 7 天每日用量（ccusage）
# 提示文字语言由 tmux 选项 @cc_lang 决定（zh 默认 / en）
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
TAB=$'\t'
US=$'\x1f'
CCUSAGE=ccusage@20.0.41

# 提示语言：tmux 全局选项 @cc_lang = zh（默认）| en；只在要输出文字时加载
load_lang() {
  if [ "$(tmux show -gqv @cc_lang 2>/dev/null)" = en ]; then
    L_ASK='! waiting' L_DONE='✓ done   ' L_RUN='◐ working'
    M_NONE='No Claude sessions' M_IDLE='No Claude is waiting for you'
    M_ASK='Claude in %s is waiting for you (prefix G to jump)'
    M_LIM='Claude limits (shared by the whole account)' M_5H='5 hours' M_7D='7 days ' M_RESET='resets'
    M_DAILY='Daily usage, last 7 days (ccusage; cost is an estimate at API list price, not your bill)'
    M_NOCC='bunx / npx not found, cannot run ccusage' M_NOLIM='No limit data yet (shown after Claude'"'"'s first reply)'
    M_QUIT='q to close'
  else
    L_ASK='! 等确认' L_DONE='✓ 跑完  ' L_RUN='◐ 在跑  '
    M_NONE='没有 Claude 会话' M_IDLE='没有等你处理的 Claude'
    M_ASK='Claude 在 %s 等你确认（prefix G 跳过去）'
    M_LIM='Claude 额度（整个账号共享）' M_5H='5 小时' M_7D='7 天  ' M_RESET='重置'
    M_DAILY='最近 7 天每日用量（ccusage；费用按 API 标价估算，不是实际账单）'
    M_NOCC='没有 bunx / npx，无法运行 ccusage' M_NOLIM='还没有额度数据（Claude 回复过一次后才有）'
    M_QUIT='按 q 关闭'
  fi
}

# 汇总一个 session：各 window 取其 pane 的最高优先级状态，session 取全部 pane 的
sync_session() {
  local out id v args=()
  out=$(tmux list-panes -s -t "$1" -F '#{window_id} #{@cc_p}' 2>/dev/null | awk '
    function r(s) { return s == "ask" ? 3 : s == "done" ? 2 : s == "run" ? 1 : 0 }
    { if (!($1 in w)) w[$1] = ""; if (r($2) > r(w[$1])) w[$1] = $2; if (r($2) > r(S)) S = $2 }
    END { for (k in w) print k, w[k]; print "S", S }') || return 0
  while read -r id v; do
    if [ "$id" = S ]; then
      if [ -n "$v" ]; then args+=(set -q -t "$1" @cc_s "$v"); else args+=(set -qu -t "$1" @cc_s); fi
    elif [ -n "$v" ]; then
      args+=(set -wq -t "$id" @cc_w "$v" ';')
    else
      args+=(set -wqu -t "$id" @cc_w ';')
    fi
  done <<< "$out"
  tmux "${args[@]}"
}

sync_all() {
  local s
  for s in $(tmux list-sessions -F '#{session_id}' 2>/dev/null); do sync_session "$s"; done
}

# 有状态但 pane 里已经没有 claude 进程（被 kill、崩溃、SessionEnd 没触发）→ 清掉
gc() {
  local p tty st
  while IFS="$TAB" read -r p tty st; do
    [ -n "$st" ] || continue
    ps -t "${tty#/dev/}" -o comm= 2>/dev/null | grep -qx claude || tmux set -pqu -t "$p" @cc_p
  done < <(tmux list-panes -a -F "#{pane_id}${TAB}#{pane_tty}${TAB}#{@cc_p}" 2>/dev/null)
  sync_all
}

# 按 等确认 > 跑完 > 在跑、同状态按时间早晚 排序，输出 "pane_id<TAB>状态<TAB>显示文本"
list_agents() {
  load_lang
  tmux list-panes -a -F "#{@cc_p}${TAB}#{@cc_t}${TAB}#{pane_id}${TAB}#{session_name}:#{window_index}.#{pane_index}${TAB}#{pane_current_path}" |
    awk -F'\t' -v OFS='\t' -v ask="$L_ASK" -v done="$L_DONE" -v run="$L_RUN" '$1 != "" {
      r = $1 == "ask" ? 1 : $1 == "done" ? 2 : 3
      label = $1 == "ask" ? ask : $1 == "done" ? done : run
      sub(ENVIRON["HOME"], "~", $5)
      print r, ($2 == "" ? 0 : $2), $3, $1, label "  " $4 "  " $5
    }' | sort -t"$TAB" -k1,1n -k2,2n | cut -f3-
}

# 没有实时额度时用 ~/.claude.json 的缓存兜底；tmux 里已有未过期的值就不动
usage_cache() {
  local now ts p5 r5 p7 r7 args=()
  now=$(date +%s); ts=$(tmux show -gqv @cc_5h_ts)
  [ -n "$ts" ] && [ "$ts" -gt "$now" ] && return 0
  [ -f ~/.claude.json ] || return 0
  IFS="$US" read -r p5 r5 p7 r7 < <(jq -r '
    def ep: if . then sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601 | tostring else "" end;
    (.cachedUsageUtilization.utilization // {}) as $u
    | [($u.five_hour.utilization // "" | tostring), ($u.five_hour.resets_at | ep),
       ($u.seven_day.utilization // "" | tostring), ($u.seven_day.resets_at | ep)] | join("\u001f")' ~/.claude.json 2>/dev/null)
  [ -n "$p5" ] && [ -n "$r5" ] && [ "$r5" -gt "$now" ] &&
    args+=(set -gq @cc_5h "${p5%.*}" ';' set -gq @cc_5h_ts "$r5" ';' set -gq @cc_5h_at "$(date -r "$r5" +%H:%M)" ';')
  [ -n "$p7" ] && [ -n "$r7" ] && [ "$r7" -gt "$now" ] &&
    args+=(set -gq @cc_7d "${p7%.*}" ';' set -gq @cc_7d_ts "$r7" ';' set -gq @cc_7d_at "$(date -r "$r7" +%m/%d)" ';')
  [ ${#args[@]} -gt 0 ] && tmux "${args[@]}"
  return 0
}

# prefix u 弹窗内容：额度进度条 + ccusage 每日表格，用 less 翻页
usage_report() {
  load_lang
  usage_cache
  local now name p ts at n bar rest c
  now=$(date +%s)
  printf '\033[1m%s\033[0m\n\n' "$M_LIM"
  local shown=0
  for w in 5h 7d; do
    p=$(tmux show -gqv "@cc_$w"); ts=$(tmux show -gqv "@cc_${w}_ts")
    [ -n "$p" ] && [ -n "$ts" ] && [ "$ts" -gt "$now" ] || continue
    shown=1
    [ $w = 5h ] && name=$M_5H || name=$M_7D
    [ $w = 5h ] && at=$(date -r "$ts" +%H:%M) || at=$(date -r "$ts" '+%m/%d %H:%M')
    n=$(( (p + 2) / 5 )); [ $n -gt 20 ] && n=20
    bar=$(printf '%*s' "$n" ''); rest=$(printf '%*s' $((20 - n)) ''); bar="${bar// /█}${rest// /░}"
    if [ "$p" -ge 80 ]; then c=31; elif [ "$p" -ge 50 ]; then c=33; else c=32; fi
    printf '  %s  \033[%sm%s %3s%%\033[0m   %s %s\n' "$name" "$c" "$bar" "$p" "$at" "$M_RESET"
  done
  [ $shown = 0 ] && printf '  %s\n' "$M_NOLIM"
  printf '\n\033[1m%s\033[0m\n' "$M_DAILY"
  if command -v bunx >/dev/null 2>&1; then
    FORCE_COLOR=1 bunx "$CCUSAGE" daily --last 7 --offline 2>/dev/null
  elif command -v npx >/dev/null 2>&1; then
    FORCE_COLOR=1 npx -y "$CCUSAGE" daily --last 7 --offline 2>/dev/null
  else
    printf '  %s\n' "$M_NOCC"
  fi
  printf '\n\033[2m%s\033[0m\n' "$M_QUIT"
}

goto_pane() {  # $1 pane  $2 client（可空）
  local c=()
  case "$2" in ''|*'#{'*) ;; *) c=(-c "$2") ;; esac
  tmux switch-client "${c[@]}" -t "$1" \; select-window -t "$1" \; select-pane -t "$1"
}

case "$1" in
  focus)
    [ "$(tmux show -pqv -t "$2" @cc_p)" = done ] && tmux set -pqu -t "$2" @cc_p
    gc; exit 0 ;;
  gc) gc; exit 0 ;;
  list) list_agents; exit 0 ;;
  usage-cache) usage_cache; exit 0 ;;
  usage) usage_report | less -RXS; exit 0 ;;
  jump)
    list=$(list_agents)
    if [ -z "$list" ]; then tmux display-message "$M_NONE"; exit 0; fi
    sel=$(printf '%s\n' "$list" | fzf --delimiter="$TAB" --with-nth=3 --reverse --no-sort \
      --prompt 'Claude> ' --preview 'tmux capture-pane -ep -t {1} | tail -n 60' --preview-window 'down,70%') || exit 0
    goto_pane "${sel%%"$TAB"*}" "$2"; exit 0 ;;
  next)
    first=$(list_agents | awk -F'\t' '$2 != "run" { print $1; exit }')
    if [ -z "$first" ]; then tmux display-message "$M_IDLE"; exit 0; fi
    goto_pane "$first" "$2"; exit 0 ;;
esac

# ---------- Claude Code hook ----------
[ -n "$TMUX_PANE" ] || exit 0
input=$(cat)
ev=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
nt=$(printf '%s' "$input" | jq -r '.notification_type // empty')

case "$ev" in
  UserPromptSubmit|PreToolUse|PostToolUse) st=run ;;
  PermissionRequest) st=ask ;;
  Notification)
    case "$nt" in
      idle_prompt) st=done ;;
      auth_success) exit 0 ;;
      *) st=ask ;;
    esac ;;
  Stop|StopFailure) st=done ;;
  SessionEnd) st= ;;
  *) exit 0 ;;
esac

IFS="$TAB" read -r sid attached wactive pactive where < <(tmux display -p -t "$TMUX_PANE" \
  "#{session_id}${TAB}#{session_attached}${TAB}#{window_active}${TAB}#{pane_active}${TAB}#{session_name}:#{window_index}") || exit 0
viewing=0
[ "$attached" -gt 0 ] && [ "$wactive" = 1 ] && [ "$pactive" = 1 ] && viewing=1

# 正盯着的 pane 跑完了不用标 done
[ "$st" = done ] && [ $viewing = 1 ] && st=

old=$(tmux show -pqv -t "$TMUX_PANE" @cc_p)
[ "$st" = "$old" ] && exit 0
if [ -n "$st" ]; then
  tmux set -pq -t "$TMUX_PANE" @cc_p "$st" \; set -pq -t "$TMUX_PANE" @cc_t "$(date +%s)"
else
  tmux set -pqu -t "$TMUX_PANE" @cc_p \; set -pqu -t "$TMUX_PANE" @cc_t
fi
sync_session "$sid"

# 等确认时提示一下（正盯着这个 pane 就不提示）
if [ "$st" = ask ] && [ $viewing = 0 ]; then
  load_lang
  # shellcheck disable=SC2059
  tmux display-message -d 4000 "$(printf "$M_ASK" "$where")"
fi
exit 0
