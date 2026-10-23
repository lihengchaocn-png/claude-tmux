# tmux-claude-iterm2-setup

[English](README.md) | **中文**

macOS 终端环境配置（zsh + vim + tmux + iTerm2），围绕两个想法：

1. **[Session · Window · Pane 三层分工](#1-session--window--pane-三层分工)**：层次清楚，鼠标和键盘都一样顺手。
2. **[和多个 AI agent 一起干活](#2-和多个-claude-一起干活)**：一个 agent 一个 session，Claude Code 的状态直接显示在 tmux 状态栏上。

![一眼看出哪个 Claude 在等你](docs/img/zh/hero.gif)

## 1. Session · Window · Pane 三层分工

![Session · Window · Pane](docs/img/zh/layout.png)

| 层 | 放什么 | 在哪 |
|---|---|---|
| **Session** | 一个项目或一个 agent，切 session 就是切任务 | 状态栏最左边，最显眼，颜色就是 agent 状态 |
| **Window** | 同一项目里的不同视图：Claude、dev server、日志 | 状态栏右侧，挨着时钟 |
| **Pane** | 需要同时看的东西：Claude + 测试、Claude + diff | 内容区 |

背后的几条原则：

- **越常用越靠左、越显眼。** 切 session 最频繁，所以放在最左边，一直可见。
- **三层的操作方式一样**：左键选中，右键出菜单，键盘上是 `C-a` 前缀后跟一个键。鼠标和键盘能做的事一样多。
- **布局跟着任务走。** pane 随时能拆成 window，window 也能随时并回来当 pane，不用一开始就把布局想好。

### 键鼠操作

![键鼠都顺手](docs/img/zh/keys.png)

前缀是 `C-a`。移动焦点用 vim 的 `h j k l`。分屏会继承当前目录。

### pane ⇄ window 互转

![右键菜单](docs/img/zh/menus.png)

- 右键 **window 标签** → *Join Here (Side / Below)*，把那个 window 作为 pane 并到当前 window。键盘上是 `prefix @` / `prefix #`，会弹出选择器。
- 右键 **pane** → *Break to Window*，把它拆回独立 window。键盘上是 `prefix !`。
- pane 菜单是 tmux 3.8 的默认菜单（分屏、浮动、交换、缩放……）加上 *Break to Window*。即使 pane 里的程序（比如 Claude Code）接管了鼠标，菜单也照样弹出。iTerm2 里 Cmd+右键也可以。

## 2. 和多个 Claude 一起干活

![和多个 Claude 一起干活](docs/img/zh/agents.png)

1. **一个 agent 一个 session。** 在每个项目目录里用 `tn api-server` 进入或新建 session，然后在里面跑 `claude`。状态栏左边就成了你的 agent 队列。
2. **后台跑，不用盯。** 蓝色转圈表示还在干活。你待在自己的 session 里，不用挨个切过去看。
3. **需要你时冒红。** 红底 `!`，状态栏同时弹一行提示。`prefix G` 直接跳到最早开始等你的那个；`prefix g` 列出所有 Claude，可以先预览它在问什么；也可以直接点 session 名。
4. **批准，再回来。** 批准后标记变回蓝色。跑完的显示黄色 `✓`，你看过之后自动消失。

在 session 内部，可以和第一部分配合着用。window 1 放 Claude，window 2 放 server 或日志。需要一边看日志一边批准时，用 `prefix @` 把日志 window 并到 Claude 旁边，看完再用 `prefix !` 拆回去。同一个 window 里两个 pane 各跑一个 Claude，状态也会分开记录。

### 徽标是怎么工作的

Claude Code 的 hook 把每个 pane 的状态写进 tmux 选项，状态栏据此显示：

![三种状态，三种颜色](docs/img/zh/states.png)

| 徽标 | 含义 |
|---|---|
| 红底 `!` | 等你确认（权限请求 / 提问）。状态栏同时弹一行提示，你正看着那个 pane 时不弹 |
| 黄底 `✓` | 跑完了，你还没看。切到那个 pane 后自动消失 |
| 蓝底 `◐◓◑◒` | 正在跑，每秒转一帧 |

- 状态按 pane 记录，再按 等确认 > 跑完 > 在跑 的优先级汇总到 window 和 session，不会互相覆盖。
- pane 退出或被 kill 时会清理残留的标记。判断方法是看 pane 里还有没有 `claude` 进程。
- `prefix g` 列出所有 Claude，等确认的排最前，带实时预览，回车跳过去：

  ![prefix g 所有 Claude 一览](docs/img/zh/picker.png)

- 右键 session 名有 *Switch / Clear Claude Mark / Rename / Kill / New* 菜单：

  ![可点击的 session 列表](docs/img/zh/menu.png)

- 与 iTerm2 自带的 Claude Code 集成 hook 共存。
- 终端里的提示文字（跳转列表、提示条）默认是中文。在 `~/.tmux.conf` 里加 `set -g @cc_lang en` 可以切成英文。

## 其他

- **tmux**：vi 复制模式（复制到 macOS 剪贴板）；用 resurrect + continuum 自动恢复会话；zsh 启动时自动进入 `main` 会话。需要 tmux ≥ 3.8。
- **zsh**：不用框架；装了 eza / bat / fzf / zoxide / starship / autosuggestions / syntax-highlighting，另有 `f` `fv` `rgi` `cproj` 几个 fzf 小工具。
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

展示图是用 `docs/src/scene.html` 仿真渲染的，内容是演示数据，`docs/img/` 下中英文各一套。改了配色后可以用 `bash docs/src/render.sh` 重新生成。

`SKILL.md` 是给 Claude Code 用的 skill 说明：把本目录放在 `~/.claude/skills/terminal-setup/` 下，Claude 就能识别。里面有更详细的实现细节。

## License

[MIT](LICENSE)
