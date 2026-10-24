#!/bin/bash
# Claude Code ↔ tmux 状态提醒
#   状态按 pane 记录（pane 选项 @cc_p = run|ask|done|bg，@cc_t = 进入该状态的时间戳），
#   bg = 这一轮已结束但还有后台 shell 在跑（run_in_background / Monitor），跑完 Claude 会自己继续；
#   再按优先级 ask > done > run > bg 汇总到 window 选项 @cc_w、session 选项 @cc_s，供 ~/.tmux.conf 状态栏上色。
# 用法：
#   tmux-cc.sh                  Claude Code hook（从 stdin 读事件 JSON）
#   tmux-cc.sh focus <pane>     tmux 切换焦点后调用：清掉该 pane 的 done，并清理残留
#   tmux-cc.sh gc               清理 Claude 已不在的 pane 上的残留状态，并重新汇总
#   tmux-cc.sh jump [client]    fzf 列出所有 Claude pane（等确认 > 跑完 > 在跑 > 后台），回车跳过去
#   tmux-cc.sh next [client]    直接跳到最早开始等你的那个（没有则最早跑完的）
#   tmux-cc.sh list             调试：输出排序后的列表
# 提示文字语言由 tmux 选项 @cc_lang 决定（zh 默认 / en）
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
TAB=$'\t'
US=$'\x1f'

# 提示语言：tmux 全局选项 @cc_lang = zh（默认）| en；只在要输出文字时加载
load_lang() {
  if [ "$(tmux show -gqv @cc_lang 2>/dev/null)" = en ]; then
    L_ASK='! waiting' L_DONE='✓ done   ' L_RUN='◐ working' L_BG='◌ bg     '
    M_NONE='No Claude sessions' M_IDLE='No Claude is waiting for you'
  else
    L_ASK='! 等确认' L_DONE='✓ 跑完  ' L_RUN='◐ 在跑  ' L_BG='◌ 后台  '
    M_NONE='没有 Claude 会话' M_IDLE='没有等你处理的 Claude'
  fi
}

# 汇总一个 session：各 window 取其 pane 的最高优先级状态，session 取全部 pane 的
sync_session() {
  local out id v args=()
  out=$(tmux list-panes -s -t "$1" -F '#{window_id} #{@cc_p}' 2>/dev/null | awk '
    function r(s) { return s == "ask" ? 4 : s == "done" ? 3 : s == "run" ? 2 : s == "bg" ? 1 : 0 }
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

# tty 上的 claude 进程还挂着后台 shell 吗？Claude Code 的 Bash 工具都是 claude 下的 `zsh -c source …/shell-snapshots/…`，
# Stop 时前台命令已结束，剩下的就是后台任务
has_bg() {
  local pid
  pid=$(ps -t "${1#/dev/}" -o pid=,comm= 2>/dev/null | awk '$2 == "claude" { print $1; exit }')
  [ -n "$pid" ] && pgrep -P "$pid" -f 'shell-snapshots/snapshot-' >/dev/null
}

# 有状态但 pane 里已经没有 claude 进程（被 kill、崩溃、SessionEnd 没触发）→ 清掉；
# 标着 bg 但后台 shell 已经没了（被杀掉、Claude 没被唤醒）→ 改成 done
gc() {
  local p tty st
  while IFS="$TAB" read -r p tty st; do
    [ -n "$st" ] || continue
    if ! ps -t "${tty#/dev/}" -o comm= 2>/dev/null | grep -qx claude; then
      tmux set -pqu -t "$p" @cc_p
    elif [ "$st" = bg ] && ! has_bg "$tty"; then
      tmux set -pq -t "$p" @cc_p done \; set -pq -t "$p" @cc_t "$(date +%s)"
    fi
  done < <(tmux list-panes -a -F "#{pane_id}${TAB}#{pane_tty}${TAB}#{@cc_p}" 2>/dev/null)
  sync_all
}

# 按 等确认 > 跑完 > 在跑 > 后台、同状态按时间早晚 排序，输出 "pane_id<TAB>状态<TAB>显示文本"
list_agents() {
  load_lang
  tmux list-panes -a -F "#{@cc_p}${TAB}#{@cc_t}${TAB}#{pane_id}${TAB}#{session_name}:#{window_index}.#{pane_index}${TAB}#{pane_current_path}" |
    awk -F'\t' -v OFS='\t' -v ask="$L_ASK" -v done="$L_DONE" -v run="$L_RUN" -v bg="$L_BG" '$1 != "" {
      r = $1 == "ask" ? 1 : $1 == "done" ? 2 : $1 == "run" ? 3 : 4
      label = $1 == "ask" ? ask : $1 == "done" ? done : $1 == "run" ? run : bg
      sub(ENVIRON["HOME"], "~", $5)
      print r, ($2 == "" ? 0 : $2), $3, $1, label "  " $4 "  " $5
    }' | sort -t"$TAB" -k1,1n -k2,2n | cut -f3-
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
  jump)
    list=$(list_agents)
    if [ -z "$list" ]; then tmux display-message "$M_NONE"; exit 0; fi
    sel=$(printf '%s\n' "$list" | fzf --delimiter="$TAB" --with-nth=3 --reverse --no-sort \
      --prompt 'Claude> ' --preview 'tmux capture-pane -ep -t {1} | tail -n 60' --preview-window 'down,70%') || exit 0
    goto_pane "${sel%%"$TAB"*}" "$2"; exit 0 ;;
  next)
    first=$(list_agents | awk -F'\t' '$2 == "ask" || $2 == "done" { print $1; exit }')
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

IFS="$TAB" read -r sid attached wactive pactive where tty < <(tmux display -p -t "$TMUX_PANE" \
  "#{session_id}${TAB}#{session_attached}${TAB}#{window_active}${TAB}#{pane_active}${TAB}#{session_name}:#{window_index}${TAB}#{pane_tty}") || exit 0
viewing=0
[ "$attached" -gt 0 ] && [ "$wactive" = 1 ] && [ "$pactive" = 1 ] && viewing=1

# 这一轮结束但后台还有任务 → bg（不用你管，跑完 Claude 会自己继续）
[ "$ev" = Stop ] && has_bg "$tty" && st=bg
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

exit 0
