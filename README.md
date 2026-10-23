# tmux-claude-iterm2-setup

**English** | [中文](README.zh-CN.md)

A macOS terminal setup — zsh + vim + tmux + iTerm2 — plus **Claude Code status badges in the tmux status bar**.

![See at a glance which Claude is waiting for you](docs/img/en/hero.gif)

## Claude Code status in tmux

Claude Code hooks write each pane's Claude state into tmux, and the status bar shows it as colored badges:

![Three states, three colors](docs/img/en/states.png)

| Badge | Meaning |
|---|---|
| red `!` | Waiting for you (permission request / question); a one-line banner also pops up on the status line |
| yellow `✓` | Finished and you haven't looked yet; cleared when you focus that pane |
| blue `◐◓◑◒` | Working (spinner advances once per second) |

- State is tracked per pane, then rolled up to the window and session with priority waiting > done > working, so several Claudes in one window never overwrite each other.
- Stale badges are cleaned up when a pane exits or is killed (it checks whether a `claude` process is still running in the pane).
- `prefix g`: an fzf popup listing every Claude, with a live preview of its output; Enter jumps to it. `prefix G`: jump straight to the one that has been waiting longest.

  ![prefix g: every Claude at a glance](docs/img/en/picker.png)

- The left side of the status bar is a clickable session list; right-click a session name for Switch / Clear Claude Mark / Rename / Kill / New.

  ![Clickable session list](docs/img/en/menu.png)

- Coexists with iTerm2's built-in Claude Code integration hooks.

> In-terminal text (picker labels, the banner) is Chinese by default. Switch it to English in `~/.tmux.conf`:
>
> ```tmux
> set -g @cc_lang en
> ```

## Also included

- **tmux**: `C-a` prefix, vi copy mode, right-click menus with pane ↔ window conversion, resurrect + continuum session restore, zsh auto-attaches to a `main` session. Requires tmux ≥ 3.8.
- **zsh**: no framework; eza / bat / fzf / zoxide / starship / autosuggestions / syntax-highlighting; small fzf helpers `f`, `fv`, `rgi`, `cproj`.
- **vim**: vim-plug with NERDTree, fugitive, lightline, and more.
- **iTerm2**: "Moshi Dark" dynamic profile (JetBrains Mono + Noto Sans Mono CJK), Minimal theme.

## Install

```bash
git clone https://github.com/lihengchaocn-png/tmux-claude-iterm2-setup.git
cd tmux-claude-iterm2-setup
bash scripts/install.sh shell    # zsh + Homebrew CLI tools + uv (overwrites ~/.zshrc)
bash scripts/install.sh vim
bash scripts/install.sh tmux
bash scripts/install.sh claude   # Claude Code hook (needs jq), merged idempotently into ~/.claude/settings.json
bash scripts/install.sh iterm    # run from Terminal.app while iTerm2 is not running
bash scripts/install.sh all      # everything above
```

Overwritten files are backed up as `*.bak-<timestamp>`. `zprofile` points Homebrew at the Tsinghua (TUNA) mirror in China; delete those lines if you don't need it.

The showcase images are rendered from `docs/src/scene.html` with demo data (English and Chinese sets under `docs/img/`); regenerate them with `bash docs/src/render.sh` after changing colors.

`SKILL.md` is a Claude Code skill (put this directory at `~/.claude/skills/terminal-setup/` and Claude will pick it up); it documents the implementation in more detail.

## License

[MIT](LICENSE)
