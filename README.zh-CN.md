# tmux-claude-iterm2-setup

[English](README.md) | **中文**

macOS 终端环境配置：zsh + vim + tmux + iTerm2，外加 **Claude Code ↔ tmux 状态提醒**。

![一眼看出哪个 Claude 在等你](docs/img/zh/hero.gif)

## Claude Code 状态提醒

通过 Claude Code hooks 把每个 pane 里 Claude 的状态写进 tmux，状态栏用彩色徽标显示：

![三种状态，三种颜色](docs/img/zh/states.png)

| 徽标 | 含义 |
|---|---|
| 红底 `!` | 等你确认（权限请求 / 提问），同时状态栏弹一行提示 |
| 黄底 `✓` | 跑完了，你还没看；切到那个 pane 自动消失 |
| 蓝底 `◐◓◑◒` | 正在跑（每秒转一帧） |

- 状态按 pane 记录，再按 等确认 > 跑完 > 在跑 汇总到 window 和 session，同一窗口多个 Claude 互不覆盖。
- pane 退出、被 kill 时自动清理残留标记（检查 pane 里是否还有 `claude` 进程）。
- `prefix g`：fzf 弹窗列出所有 Claude，带输出预览，回车跳过去；`prefix G`：直接跳到最早等你的那个。

  ![prefix g 所有 Claude 一览](docs/img/zh/picker.png)

- 状态栏左侧是可点击的 session 列表，右键 session 名有 Switch / Clear Claude Mark / Rename / Kill / New 菜单。

  ![可点击的 session 列表](docs/img/zh/menu.png)

- 与 iTerm2 自带的 Claude Code 集成 hook 共存。
- 终端里的提示文字（跳转列表、提示条）默认中文，在 `~/.tmux.conf` 里 `set -g @cc_lang en` 可切成英文。

## 其他

- **tmux**：前缀 `C-a`，vi 复制模式，右键菜单支持 pane ↔ window 互转，resurrect + continuum 自动恢复会话，zsh 启动自动进入 `main` 会话。需要 tmux ≥ 3.8。
- **zsh**：无框架；eza / bat / fzf / zoxide / starship / autosuggestions / syntax-highlighting；`f` `fv` `rgi` `cproj` 等 fzf 小工具。
- **vim**：vim-plug + NERDTree、fugitive、lightline 等。
- **iTerm2**：Moshi Dark 动态 profile（JetBrains Mono + Noto Sans Mono CJK），Minimal 主题。

## 安装

```bash
git clone https://github.com/lihengchaocn-png/tmux-claude-iterm2-setup.git
cd tmux-claude-iterm2-setup
bash scripts/install.sh shell    # zsh + Homebrew CLI 工具 + uv（会覆盖 ~/.zshrc）
bash scripts/install.sh vim
bash scripts/install.sh tmux
bash scripts/install.sh claude   # Claude Code hook（依赖 jq），幂等合并进 ~/.claude/settings.json
bash scripts/install.sh iterm    # 需在 iTerm2 退出状态下、从 Terminal.app 运行
bash scripts/install.sh all      # 以上全部
```

被覆盖的文件会先备份为 `*.bak-<时间戳>`。`zprofile` 里配置的是清华 Homebrew 镜像，海外用户可以删掉那几行。

展示图是用 `docs/src/scene.html` 仿真渲染的（演示数据，`docs/img/` 下中英文各一套），改了配色后可以用 `bash docs/src/render.sh` 重新生成。

`SKILL.md` 是给 Claude Code 用的 skill 说明（放在 `~/.claude/skills/terminal-setup/` 下即可被 Claude 识别），里面有更详细的实现细节。

## License

[MIT](LICENSE)
