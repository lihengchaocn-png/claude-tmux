#!/usr/bin/env bash
# 把 skill 里保存的 zsh / vim / tmux / Claude hook / iTerm2 配置部署到本机。
# 用法: install.sh [shell|vim|tmux|claude|iterm|all]   (默认 all)
# 已存在的目标文件会先备份为 <file>.bak-<时间戳>。
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FILES="$SKILL_DIR/files"
TS="$(date +%Y%m%d%H%M%S)"
WHAT="${1:-all}"

backup() { [[ -e "$1" ]] && cp -p "$1" "$1.bak-$TS" && echo "  备份 $1 -> $1.bak-$TS"; return 0; }

install_tmux() {
  echo "== tmux =="
  command -v tmux >/dev/null 2>&1 || { command -v brew >/dev/null && brew install tmux; }
  mkdir -p ~/.config/tmux
  backup ~/.tmux.conf;                     cp "$FILES/tmux.conf" ~/.tmux.conf
  backup ~/.config/tmux/mouse-menus.conf;  cp "$FILES/mouse-menus.conf" ~/.config/tmux/mouse-menus.conf
  # prefix v（改动 + diff）、prefix e（yazi 侧栏）、编辑器弹窗用到的脚本，以及 yazi 配置
  mkdir -p ~/.config/tmux/bin ~/.config/yazi
  cp "$FILES"/tmux-bin/* ~/.config/tmux/bin/ && chmod +x ~/.config/tmux/bin/*
  backup ~/.config/yazi/yazi.toml;         cp "$FILES/yazi/yazi.toml" ~/.config/yazi/yazi.toml
  backup ~/.config/yazi/theme.toml;        cp "$FILES/yazi/theme.toml" ~/.config/yazi/theme.toml

  if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi
  # 非交互安装插件（需要有 tmux server 时才会加载配置；这里直接调 tpm 脚本）
  ~/.tmux/plugins/tpm/bin/install_plugins || echo "  插件安装失败，可进 tmux 后按 prefix(C-a) + I 重试"

  if [[ -n "${TMUX:-}" ]]; then tmux source-file ~/.tmux.conf && echo "  已在当前 tmux 中重载"; fi
}

install_shell() {
  echo "== zsh / CLI 工具 =="
  # zprofile 先装：里面配了清华 Homebrew 镜像和 brew shellenv
  backup ~/.zprofile; cp "$FILES/shell/zprofile" ~/.zprofile
  backup ~/.profile;  cp "$FILES/shell/profile"  ~/.profile
  if command -v brew >/dev/null 2>&1; then
    brew install eza bat fd ripgrep fzf zoxide starship zsh-autosuggestions zsh-syntax-highlighting tmux yazi git-delta
  else
    echo "  !! 未找到 brew，请先安装 Homebrew 后重跑: $0 shell"
  fi
  # zshrc 第一行 source ~/.local/bin/env，该文件由 uv 官方安装脚本生成
  if [[ ! -f ~/.local/bin/env ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  backup ~/.zshrc; cp "$FILES/shell/zshrc" ~/.zshrc
  echo "  完成；新开终端生效"
}

install_vim() {
  echo "== vim =="
  backup ~/.vimrc; cp "$FILES/vim/vimrc" ~/.vimrc
  if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
  vim -E -s -u ~/.vimrc +PlugInstall +qall || true
}

install_iterm() {
  echo "== iTerm2 =="
  if pgrep -xq iTerm2; then
    echo "  !! iTerm2 正在运行：退出时会覆盖 defaults 写入的全局设置。"
    echo "     请在 Terminal.app 中运行本脚本（或先退出 iTerm2），然后重试: $0 iterm"
    return 1
  fi

  # 字体（profile 用 JetBrains Mono 14 + Noto Sans Mono CJK SC 14）
  if command -v brew >/dev/null 2>&1; then
    brew list --cask font-jetbrains-mono >/dev/null 2>&1 || brew install --cask font-jetbrains-mono || true
    brew list --cask font-noto-sans-mono-cjk-sc >/dev/null 2>&1 || brew install --cask font-noto-sans-mono-cjk-sc || true
  fi

  # Dynamic Profile: Moshi Dark（完整配色/字体/边距）
  local dp=~/Library/Application\ Support/iTerm2/DynamicProfiles
  mkdir -p "$dp"
  backup "$dp/moshi-dark.json"
  cp "$FILES/iterm2/moshi-dark.json" "$dp/moshi-dark.json"

  local D="defaults write com.googlecode.iterm2"
  $D "Default Bookmark Guid" -string moshi-dark-0001   # 默认 profile = Moshi Dark
  $D TabStyleWithAutomaticOption -int 5                # 主题 Minimal
  $D HideTab -bool true                                # 只有一个 tab 时隐藏 tab bar
  $D HideScrollbar -bool true
  $D TerminalMargin -int 14                            # 左右边距
  $D TerminalVMargin -int 8                            # 上下边距
  $D WindowPlacement -int 2
  $D AllowClipboardAccess -bool true                   # 允许终端程序访问剪贴板（OSC 52，配合 tmux set-clipboard on）
  $D ApplePressAndHoldEnabled -bool false              # 长按连续输入而非弹重音菜单
  $D NoSyncTipsDisabled -bool true
  # tmux -CC 集成相关（平时用普通 tmux，以下保证 -CC 也顺手）
  $D OpenTmuxWindowsIn -int 1                          # tmux window 以 tab 打开
  $D AutoHideTmuxClientSession -bool false
  $D TmuxUsesDedicatedProfile -bool false
  $D TmuxSyncClipboard -bool false
  $D TmuxWarnBeforePausing -bool false
  $D UseTmuxStatusBar -bool false
  echo "  已写入 iTerm2 全局设置；启动 iTerm2 生效"
}

install_claude() {
  echo "== Claude Code → tmux 状态提醒 =="
  command -v jq >/dev/null 2>&1 || { command -v brew >/dev/null && brew install jq; }
  mkdir -p ~/.claude/hooks
  backup ~/.claude/hooks/tmux-cc.sh; cp "$FILES/claude/tmux-cc.sh" ~/.claude/hooks/tmux-cc.sh
  backup ~/.claude/hooks/cc-statusline.sh; cp "$FILES/claude/cc-statusline.sh" ~/.claude/hooks/cc-statusline.sh
  chmod +x ~/.claude/hooks/tmux-cc.sh ~/.claude/hooks/cc-statusline.sh

  # 把 hook 并入 settings.json（幂等：已挂过的事件跳过；保留原有 hook，如 iTerm2 的 cc-status）
  local st=~/.claude/settings.json cmd="$HOME/.claude/hooks/tmux-cc.sh"
  [[ -f "$st" ]] || echo '{}' > "$st"
  backup "$st"
  jq --arg cmd "$cmd" '
    reduce ("UserPromptSubmit","PreToolUse","PostToolUse","PermissionRequest","Notification","Stop","StopFailure","SessionEnd") as $ev (.;
      if ([.hooks[$ev][]?.hooks[]?.command] | index($cmd)) then .
      elif (.hooks[$ev] | length) > 0 then .hooks[$ev][0].hooks += [{"type":"command","command":$cmd}]
      else .hooks[$ev] = [{"hooks":[{"type":"command","command":$cmd}]}] end)
  ' "$st" > "$st.tmp" && mv "$st.tmp" "$st"
  # statusLine：没有就设成 cc-statusline.sh（模型、上下文、额度）；已有别的就不覆盖
  local sl="$HOME/.claude/hooks/cc-statusline.sh" cur
  cur=$(jq -r '.statusLine.command // empty' "$st")
  if [[ -z "$cur" ]]; then
    jq --arg c "$sl" '.statusLine = {"type":"command","command":$c,"padding":0}' "$st" > "$st.tmp" && mv "$st.tmp" "$st"
  elif [[ "$cur" != "$sl" ]]; then
    echo "  !! settings.json 已有 statusLine（${cur}），未覆盖；想在 Claude 底部看到额度可以在自己的脚本里调用 ${sl}"
  fi
  echo "  已挂到 ${st}；新开的 Claude Code 会话生效（状态栏配色在 tmux.conf 里，需同时部署 tmux）"
}

case "$WHAT" in
  shell) install_shell ;;
  vim)   install_vim ;;
  tmux)  install_tmux ;;
  iterm) install_iterm ;;
  claude) install_claude ;;
  all)   install_shell; install_vim; install_tmux; install_claude; install_iterm ;;
  *) echo "用法: $0 [shell|vim|tmux|claude|iterm|all]"; exit 2 ;;
esac
