---
name: terminal-setup
description: 用户个人的终端环境配置：zsh（别名 ls→eza、cat→bat、ll、tmux 别名，函数 f/fv/rgi/cproj，fzf/zoxide/starship/自动补全/语法高亮，清华 Homebrew 镜像）、vim（vim-plug + NERDTree 等）、tmux（C-a 前缀、vi 复制、鼠标右键菜单含 pane/window 互转、顶部状态栏可点击切 session、resurrect+continuum、zsh 自动进入 main 会话）和 iTerm2（Moshi Dark 动态 profile、JetBrains Mono + Noto CJK、Minimal 主题与 tmux 集成选项）。当用户要在新机器上配置/恢复终端环境（zsh、别名、vim、tmux、iTerm2）、修改或排查这些配置、询问自己的别名/函数/快捷键、或想同步当前配置回本 skill 时使用。
---

# 终端环境：zsh + vim + tmux + iTerm2

配置的权威副本在本 skill 的 `files/` 下，部署脚本是 `scripts/install.sh`。

| skill 内文件 | 部署到 |
|---|---|
| `files/shell/zshrc` | `~/.zshrc`（整份，含 tmux 块） |
| `files/shell/zprofile` | `~/.zprofile` |
| `files/shell/profile` | `~/.profile` |
| `files/vim/vimrc` | `~/.vimrc` |
| `files/tmux.conf` | `~/.tmux.conf` |
| `files/mouse-menus.conf` | `~/.config/tmux/mouse-menus.conf`（由 tmux.conf `source-file`） |
| `files/claude/tmux-cc.sh` | `~/.claude/hooks/tmux-cc.sh`（并挂进 `~/.claude/settings.json` hooks） |
| `files/iterm2/moshi-dark.json` | `~/Library/Application Support/iTerm2/DynamicProfiles/moshi-dark.json` |
| iTerm2 全局项 | `defaults write com.googlecode.iterm2 …`（见 install.sh） |
## 部署到新机器

```bash
I=~/.claude/skills/terminal-setup/scripts/install.sh
bash $I shell   # zprofile/profile/zshrc + brew 装 CLI 工具 + uv
bash $I vim     # vimrc + vim-plug + PlugInstall
bash $I tmux    # tmux.conf + 右键菜单 + TPM 插件
bash $I claude  # Claude Code hook → tmux 状态栏提醒（依赖 jq）
bash $I iterm   # 必须在 iTerm2 未运行时执行（用 Terminal.app）bash $I all     # 以上全部，按此顺序
```

- `shell` 会**整份覆盖** `~/.zshrc`；目标机器上已有别的 zshrc 内容时，先 diff 给用户看，必要时手动合并而非直接覆盖。

- 脚本会把被覆盖的文件备份为 `*.bak-<时间戳>`。部署前先告诉用户会覆盖哪些文件。
- iTerm2 在运行中退出时会把内存里的偏好写回 plist，覆盖 `defaults write`，所以 iterm 部分必须在 iTerm2 退出状态下跑；脚本检测到 iTerm2 在运行会拒绝执行。
- 需要 tmux ≥ 3.8（右键菜单里用了 3.8 的 floating pane 格式变量，如 `pane_floating_flag`、`move-pane -P`）。低版本先 `brew upgrade tmux`，否则 source 时会报错。
- 本机的 shell 里 `ls`→eza、`cat`→bat 是 alias，Bash 工具里读文件用 `/bin/cat` 或 `command cat`。

## zsh 要点

**启动链**：`~/.zprofile` 设清华 Homebrew 镜像（`HOMEBREW_API_DOMAIN` / `HOMEBREW_BOTTLE_DOMAIN` / `HOMEBREW_PIP_INDEX_URL`，行尾 `#ckbrew` 标记）并 `eval $(brew shellenv)`；`~/.profile` 与 `~/.zshrc` 首行都 source `~/.local/bin/env`（uv 安装器生成，把 `~/.local/bin` 加进 PATH）。没有框架（无 oh-my-zsh）。

**插件 / 集成**（全部 Homebrew 安装，存在才加载）：zsh-autosuggestions、`fzf --zsh`（Ctrl-T / Ctrl-R / Alt-C）、`zoxide init zsh`（`z` / `zi`）、`starship init zsh`（默认主题，无 starship.toml）、zsh-syntax-highlighting（必须最后加载）。

**别名**

| 别名 | 实际 |
|---|---|
| `ls` | `eza` |
| `ll` | `eza -lah --git` |
| `cat` | `bat` |
| `ta <name>` | `tmux attach -t` |
| `tn <name>` | `tmux new -A -s`（有则 attach 无则新建） |
| `tls` / `tl` | `tmux ls` |

要用原版命令：`command ls` / `command cat`（Claude 的 Bash 工具里也有这些 alias，读文件用 `/bin/cat`）。

**函数**（`>>> shell-dev-functions >>>` 块，依赖 fd / rg / fzf / bat / eza / zoxide，后三个还要 VS Code 的 `code` 命令）

| 函数 | 作用 |
|---|---|
| `f` | fd 列文件 → fzf（bat 预览）→ 用 `$EDITOR`（默认 vim）打开 |
| `fv` | 同上，用 VS Code 打开 |
| `rgi [词]` | rg 全文搜索 → fzf 预览命中行 → `code --goto file:line` |
| `cproj` | 从 zoxide 记过的目录里选一个（eza 树预览）→ VS Code 打开 |

**tmux 自动进入**：交互 shell 自动 `tmux new -A -s main`（见下方 tmux 部分）。

## vim 要点

vim-plug 管理：vim-sensible、NERDTree、commentary、surround、repeat、fugitive、lightline（wombat 配色）、polyglot。行号 + 相对行号、`mouse=a`、smartcase 搜索、2 空格缩进、新分屏在下/右。Leader 为空格：`<leader>n` NERDTree、`<leader>w` 保存、`<leader>q` 退出、`Esc Esc` 清搜索高亮。

## tmux 要点

**前缀 `C-a`**（`C-a C-a` 发送原始 C-a）。`prefix r` 重载配置。

| 按键 | 作用 |
|---|---|
| `prefix \|` / `prefix -` | 左右 / 上下分屏（继承当前路径） |
| `prefix c` | 新 window（继承当前路径） |
| `prefix h/j/k/l` | 切 pane；`H/J/K/L` 按住可重复，调大小 5 格 |
| `prefix @` / `prefix #` | 选一个 window 并入当前 window（左右 / 上下） |
| `prefix !` | 反向：把当前 pane 拆成独立 window（tmux 默认） |
| 复制模式 | vi 键位，`v` 开始选择，`y` 复制到 macOS 剪贴板（pbcopy）；滚轮每格 5 行 |
| `prefix I` | TPM 安装插件 |

**鼠标**（`mouse on`）：
- pane 上右键（或 iTerm2 里 Cmd+右键，tmux 收到的是 `M-MouseDown3Pane`）：tmux 3.8 默认菜单 + **Break to Window**。绑在 root 表上**总是弹 tmux 菜单**，即使程序（如 Claude Code）接管了鼠标。
- 状态栏 window 标签右键：**Join Here (Side/Below)** 把该 window 并入当前 window、Rename、Kill、New After/At End。实现上用 `run-shell -C` 先展开 window id，再以当前 window 为目标弹菜单（3.8 下以非当前 window 的 pane 为目标时菜单不显示）。
- 状态栏 session 名右键：Switch To（非当前）、Clear Claude Mark（有 `@cc_s` 时）、Rename、Kill（当前 session 置灰）、New Session。session 和 window 标签右键都触发 `MouseDown3Status`，靠 `if -F "#{==:#{mouse_status_range},session}"` 分流；菜单项的条件写成 `##{?...}`，让 run-shell -C 只展开内层值、由 display-menu 判断显隐（否则展开成空串会被当成分隔线导致参数错位）。
- 状态栏**左侧**列出所有 session（status-left），点击即切换（`range=session|…`），当前 session 绿底高亮；window 列表 `status-justify right` 靠右，紧挨日期时间（status-right）。

**其他**：状态栏在顶部、深灰底；`base-index 1`、`renumber-windows on`；`default-terminal tmux-256color` + RGB；`default-command "${SHELL}"`（非 login shell，避免 macOS `path_helper` 打乱 PATH）；history 50000；插件 tpm / tmux-sensible / tmux-resurrect / tmux-continuum（`@continuum-restore on`，开机自动恢复会话）；最后 `aggressive-resize off` 以兼容 iTerm2 `tmux -CC`。

**Claude Code 状态提醒**：`~/.claude/hooks/tmux-cc.sh`（副本 `files/claude/tmux-cc.sh`；`install.sh claude` 部署：复制脚本并用 jq 幂等地挂到 `~/.claude/settings.json` 的 UserPromptSubmit / PreToolUse / PostToolUse / PermissionRequest / Notification / Stop / StopFailure / SessionEnd，与 iTerm2 的 cc-status 并列）。
- 状态按 **pane** 记录（pane 选项 `@cc_p` = run/ask/done，`@cc_t` 时间戳），按 ask > done > run 汇总到 window 选项 `@cc_w`、session 选项 `@cc_s`，同一 window 多个 Claude 互不覆盖。状态栏据此在名字前加彩色徽标、非当前项名字染同色（格式抽成 `@cc_badge_s/w`、`@cc_name_s/w` 用 `#{E:}` 引用）：红底 `!`=等你确认，黄底 `✓`=跑完等你查看，蓝底 `◐◓◑◒` 转圈=正在跑（`@cc_spin` 按秒数取帧，`status-interval 1`）。当前 session/window 保持绿底，徽标贴在前面。
- tmux 钩子：`client-session-changed` / `session-window-changed` / `after-select-pane` → `tmux-cc.sh focus #{pane_id}`（清该 pane 的 done）；`pane-exited` / `after-kill-pane` / `session-closed` → `tmux-cc.sh gc`（pane 里已无 `claude` 进程的残留状态清掉，再重新汇总）。钩子里的路径用 `$HOME`，单引号里的 `~` 不会展开。
- `prefix g`：fzf popup 列出所有 Claude（等确认 > 跑完 > 在跑，同状态按时间先后），预览 pane 输出，回车跳过去；`prefix G`：直接跳到最早等你的（没有则最早跑完的）。`prefix a` 被 tmux-sensible 占为 last-window，所以没用。
- 等确认时 `display-message` 提示，正盯着那个 pane 时不提示；正盯着的 pane 跑完不标 done。调试：`tmux-cc.sh list`。
- 额度 / 用量：`~/.claude/hooks/cc-statusline.sh`（副本 `files/claude/cc-statusline.sh`）是 Claude Code 的 statusLine，输出 `模型 · ctx N%`，同时把 statusLine 输入里的 `rate_limits.five_hour/seven_day` 写进 tmux 全局选项 `@cc_5h/@cc_7d`（%）、`@cc_*_ts`（重置 epoch）、`@cc_*_at`（可读时间）；不在 tmux 里时额度直接显示在 Claude 底部。tmux 状态栏右侧 `#{E:@cc_lim}` 按 <50 绿 / <80 黄 / ≥80 红显示，≥80 带 `↻重置时间`，过了重置时间（`#{e|<:%s,ts}`）自动隐藏。注意嵌套格式每层都会做一次 strftime，条件分支里的百分号要写 `%%%%`。tmux 启动时 `tmux-cc.sh usage-cache` 从 `~/.claude.json` 的 `cachedUsageUtilization` 兜底。`prefix u` 弹窗 = `tmux-cc.sh usage`：额度进度条 + `bunx ccusage@20.0.41 daily --last 7 --offline`，用 less 翻页。install.sh 只在没有 statusLine 时设置，已有则提示。
- 提示文字语言由 tmux 选项 `@cc_lang`（zh 默认 / en）决定，tmux.conf 里显式设为 zh；脚本里 `load_lang` 只在要输出文字时才读。
- README：英文 `README.md`（主）+ 中文 `README.zh-CN.md`；展示图由 `docs/src/scene.html?lang=en|zh` 仿真渲染，`bash docs/src/render.sh` 生成 `docs/img/en/`、`docs/img/zh/` 两套，中文翻译表在 scene.html 末尾的 `EN` 对象里。

**zsh 集成**（`~/.zshrc` 的 `>>> tmux >>>` 块）：交互 shell 自动 `tmux new -A -s main`（本机与 ssh 登录都生效），跳过条件：已在 tmux 内、非交互（scp/rsync）、`TERM_PROGRAM=vscode`（VS Code / code-server 终端）、`NO_TMUX=1`。

## iTerm2 要点

- 默认 profile：**Moshi Dark**（Dynamic Profile，GUID `moshi-dark-0001`）。
  - 字体 `JetBrainsMono-Regular 14`，非 ASCII 用 `NotoSansMonoCJKsc-Regular 14`；行距 1.15。
  - 配色：背景 `#1f1f1f`、前景 `#d4d4d4`、光标 `#4fc28c`（闪烁竖线），选区 `#3a3d41`；ANSI 偏 One Dark。
  - 边距 左右 14 / 上下 8；无限回滚；开启 Mouse Reporting（tmux 鼠标需要）；Terminal Type `xterm-256color`。
- 全局：主题 Minimal（`TabStyleWithAutomaticOption=5`）、单 tab 隐藏 tab bar、隐藏滚动条、允许剪贴板访问（OSC 52）、关闭按住弹重音。
- 指针动作（plist `PointerActions`，均为 iTerm2 默认，未纳入脚本）：右键=上下文菜单、中键=粘贴、三指左右切 tab、上下切窗口。
- tmux -CC：tmux window 以 tab 打开、不自动隐藏 client session、不用专用 profile、不同步剪贴板、不暂停警告、不用 iTerm 状态栏。

## 修改配置的工作流

1. 改本机实际文件（`~/.zshrc`、`~/.tmux.conf` 等）并验证：zsh 用 `zsh -n ~/.zshrc` 查语法再 `exec zsh`；tmux 用 `tmux source-file ~/.tmux.conf`，无报错再试按键/菜单。新增别名/函数沿用现有风格：放进对应的 `# >>> 名称 >>>` 块，依赖的命令用 `command -v` 判断存在再定义。
2. 改之前先备份（用户习惯：`.bak`、`.bak2` 递增）。
3. 满意后把改动**同步回本 skill**，保证 skill 是最新权威版本：

```bash
S=~/.claude/skills/terminal-setup/files
cp ~/.zshrc $S/shell/zshrc; cp ~/.zprofile $S/shell/zprofile; cp ~/.profile $S/shell/profile
cp ~/.vimrc $S/vim/vimrc
cp ~/.tmux.conf $S/tmux.conf
cp ~/.config/tmux/mouse-menus.conf $S/mouse-menus.conf```

本目录是 git 仓库，远程为 GitHub 公开仓库 `lihengchaocn-png/tmux-claude-iterm2-setup`（提交身份已在仓库本地设为 GitHub noreply 邮箱，全局 git 邮箱是公司邮箱，不要用）。同步完 `git commit` 并 `git push`；提交前确认没有带入个人/公司信息（绝对路径用 `$HOME`）。

别名/函数/插件有增删时，同步更新上面 zsh 要点里的表格；新依赖的 brew 包加进 `install.sh` 的 `install_shell`。

iTerm2 profile 在 GUI 改过后，从 `~/Library/Preferences/com.googlecode.iterm2.plist` 的 `New Bookmarks` 里取 GUID 为 `moshi-dark-0001` 的条目重新导出成 `files/iterm2/moshi-dark.json`（去掉 `(Dark)`/`(Light)` 颜色变体、`Dynamic Profile Filename`、`Is Dynamic Profile`、`Rewritable`、`Columns`/`Rows`、`Working Directory`，外层包 `{"Profiles": [...]}`）。全局项有变化时同步更新 `install.sh` 里的 `defaults write` 列表；可与 plist 备份 diff 找出改了哪些键。
