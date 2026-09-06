# AGENTS.md

Opencode-facing instructions for this repository. Read this before
making any change. The user-facing readme is `README.md` — this file
is the contract the agent must follow.

This rice is authored from a Windows box (file paths in commit messages
/ `git status` may show `D:\linux rice`) and pushed via `gh CLI`. It
targets **Arch Linux** (single-monitor, GPU-agnostic NVIDIA/Intel/AMD).
Scripts run on Arch; do not assume Windows tools exist on the target.

---

## Package policy (inviolable)

1. **Official repos first.** If a package is in `pacman -S` (any repo:
   core, extra, multilib), it comes from there. No building from source
   when an official package exists.
2. **No `curl | bash` installers**, ever — including upstream one-liner
   install scripts (`curl -f https://zed.dev/install.sh | sh` is
   forbidden; use the AUR pkg instead). AUR helpers (`paru`, `yay`) are
   permitted per user direction, but the reviewed manual pipeline in
   rule 3 stays the default in scripts: the review step is the point,
   and a helper skips it.
3. **AUR-only packages** go through `scripts/10-aur.sh`:
   - `git clone https://aur.archlinux.org/<pkg>.git`
   - print the full PKGBUILD with line numbers for human review
   - scan for `curl|bash` / suspicious source URLs (`pastebin|ipfs|ngrok`)
   - wait for explicit `[y/N]` confirmation before building
   - `makepkg -Cso` (clean + sync deps + build, **NO `-i`** — build only)
   - `repo-add` the produced `*.pkg.tar.zst` into the local repo at
     `/var/cache/pacman/localrepo` (registered into `/etc/pacman.conf`
     as `[localrepo]` with `SigLevel = Optional TrustAll`)
   - install via `sudo pacman -S <pkg>` from that local repo
4. **Static-asset / no-build repos** (like `sddm-astronaut-theme`) use a
   bare `git clone` straight from upstream into the documented install
   path (e.g. `/usr/share/sddm/themes/...`). Don't manufacture a PKGBUILD
   wrapper when there's nothing to compile. `scripts/20-sddm.sh` is the
   sole current example.
5. **Up-front AUR-only audit.** Before any change that adds or removes
   a package, scan the full package list and list every AUR-only
   dependency in the PR description (or commit message, if pushing
   direct) — so the review/build step is visible, never silent mid-task.

### AUR-only packages currently in this build

`scripts/10-aur.sh` is the source of truth. As of last audit:

| Package                | Notes                                                              |
|------------------------|--------------------------------------------------------------------|
| `eww`                  | Rust build. Many crates from crates.io.                            |
| `python-pywal16`       | Active fork. Official `python-pywal` is the dead one — don't swap.|
| `bibata-cursor-theme`  | Cursor theme. Has install hooks; review before approving.          |
| `wlogout`              | Wayland logout menu, GTK3.                                         |
| `zed`                  | Large Rust project. **Review PKGBUILD carefully** — may fetch      |
|                        | release assets at build time.                                      |
| `helium-browser-bin`   | Precompiled Helium (imputnet) repackaged from the signed release   |
|                        | tarball (PGP via validpgpkeys) + sha256-pinned patches. No build,  |
|                        | no hooks, no curl\|bash.                                            |
| `mpvpaper`             | Animated wallpaper daemon. Pinned GitHub release tarball + b2sum,  |
|                        | meson build, deps libmpv/wayland (mpv auto-pulled). No red flags.  |
| `vscode-langservers-extracted` | HTML/CSS/JSON/ESLint language servers for Zed + Emacs      |
|                        | eglot. npm registry tarball + sha256sum, `npm i -g` into `$pkgdir` |
|                        | with the cache confined to `$srcdir`. No build(), no hooks. The    |
|                        | rest of the LSP stack is official-repo (`00-base.sh` step 4).      |

When a package leaves AUR for official repos (the trend), **remove it
from `10-aur.sh` and add it to `00-base.sh`'s `pacman -S` list**. Don't
keep building it from AUR "to be safe" — that violates rule #1.

### Packages often mistaken for AUR-only (now in official repos)

Do not add to `10-aur.sh` — they are already in `00-base.sh`:
`rofi-wayland`, `ghostty`, `swww`, `swaync`, `cliphist`, `nwg-look`,
`kvantum`, `kvantum-qt5`, `gamemode`, `gamescope`, `mangohud`,
`lib32-mangohud`, `python-pywal` (old fork — we use `pywal16` by choice).

---

## Build speed settings (already applied by `00-base.sh`)

- `/etc/makepkg.conf`: `MAKEFLAGS="-j$(nproc)"`
- `/etc/makepkg.conf`: `CFLAGS`/`CXXFLAGS` retargeted to `-march=native`
  and `RUSTFLAGS="-C target-cpu=native"` — the AUR set (10-aur.sh) is
  everything this rice ever compiles from source, so that's where
  "prefer compiled-and-native" is realized. pacman-installed binaries
  are upstream-prebuilt generic x86-64 and stay that way (don't start
  rebuilding official packages; that's a full source-distro, not a
  rice).
- `/etc/makepkg.conf`: `BUILDENV=(!distcc !color !ccache check !sign)` —
  `ccache` installed from pacman and wired into BUILDENV
- Local repo at `/var/cache/pacman/localrepo`, name `localrepo`,
  registered into `/etc/pacman.conf` once by `10-aur.sh`'s
  `setup_local_repo()` function

Do not invent a new build pipeline. Don't build ad-hoc in `/tmp`.
Every AUR-only build goes through `scripts/10-aur.sh`'s `build_one()`.

---

## Repository layout

```
.
├── AGENTS.md                    THIS file — read before editing
├── README.md                    user-facing readme
├── .gitignore
├── .gitattributes               forces LF on all text files (target is Linux)
├── scripts/
│   ├── 00-base.sh             official-repo install + makepkg.conf + GPU driver pick
│   │                          (+ xdg-user-dirs-update, bluetooth.service, ufw baseline,
│   │                          clamav-freshclam; apparmor installed but inert — README TODO #4)
│   ├── 10-aur.sh              reviewed-PKGBUILD makepkg + repo-add pipeline
│   ├── 20-sddm.sh             sddm-astronaut-theme bare clone + rollback snapshot
│   ├── 30-dotfiles.sh         installs config/ into ~/.config with backup
│   ├── 40-gaming.sh           verifies gamemoded + prints Steam launch recipes
│   ├── 45-snapshots.sh        root-fs pick: snapper on btrfs, timeshift--rsync otherwise
│   └── 50-verify.sh           read-only post-deploy health check (never auto-fixes)
└── config/
    ├── hypr/
    │   ├── hyprland.conf       compositor config (monitor= is a STOPGAP TODO — see notes)
    │   ├── hyprpaper.conf      static wallpaper FALLBACK config (mpvpaper is the default)
    │   ├── hypridle.conf       idle / lock / suspend listeners
    │   ├── switch-theme.sh     preset palette switcher (SUPER+SHIFT+T cycles)
    │   ├── themes/{mocha,gruvbox,tokyonight,osaka-jade}/   pre-generated pywal-format palettes
    │   │                        (each carries ALL 5 formats: waybar.css, rofi.rasi,
    │   │                         wal.vim, colors.el, colors.sh)
    │   └── gpu-env.sh          NVIDIA/Intel/AMD auto-detect env shim (source from shell rc)
    ├── nvim/
    │   ├── init.lua            single-file nvim IDE config; lazy.nvim plugin
    │   │                       specs inline (lspconfig/treesitter/cmp/telescope/
    │   │                       nvim-tree), pywal-driven colors, FATS/SUPER kept
    │   └── lazy-lock.json      pinned plugin commits (lazy.nvim-generated,
    │                           committed; see editor plugin rule)
    ├── emacs/
    │   └── init.el             OPT-IN single-file Emacs config; pywal-driven,
    │                           no package manager, LSP via built-in eglot
    ├── waybar/{config,style.css}
    ├── swaync/{config.json,style.css}
    ├── rofi/config.rasi
    ├── eww/{eww.yuck,eww.scss}
    ├── wlogout/{layout,style.css}
    ├── ghostty/
    │   ├── config               primary terminal; baked Mocha = pre-wal fallback
    │   └── ghostty-theme.sh     wal colors.sh -> colors.conf include generator
    ├── MangoHud/MangoHud.conf
    ├── zed/settings.json      theme "Pywal" (wal-generated colors-zed.json,
    │                          symlinked by 30-dotfiles.sh into
    │                          ~/.config/zed/themes/pywal.json) + Nerd font
    ├── vlc/vlc-open                 resolve-then-play URL wrapper (yt-dlp / streamlink -> VLC; SUPER+SHIFT+M)
    ├── vlc/vlcrc                    minimal; decoding + snapshot dir left on VLC's defaults
    ├── wal/templates/colors-rofi.rasi   custom pywal user template -> ~/.cache/wal/colors-rofi.rasi
    ├── wal/templates/colors.el          custom pywal user template -> ~/.cache/wal/colors.el (emacs)
    ├── wal/templates/colors-zed.json    custom pywal user template -> ~/.cache/wal/colors-zed.json (zed)
    ├── wal/templates/colors-hyprland.conf   wal template -> ~/.cache/wal/colors-hyprland.conf (compositor borders)
    └── applications/
        └── zed-handler.desktop  registered via xdg-mime default in hyprland.conf
```

When adding a new component, mirror this structure: a top-level dir
under `config/<component>/` for the dotfiles, an `exec-once` line in
`hyprland.conf` to start it, and — *if* and only if there's no
official-repo equivalent — an entry in `scripts/10-aur.sh`'s
`PACKAGES=(...)` array.

Qt apps run native Wayland via `env = QT_QPA_PLATFORM, wayland;xcb` in
`hyprland.conf` (the `;xcb` fallback is required — some Qt apps fail to
start without it). `QT_QPA_PLATFORMTHEME, qt6ct` picks the theme; the
two vars are independent, keep both.

---

## Skip-git-appendix

The agent should never invoke the following on its own without an
explicit user request:

- `git push`
- `git commit` (touching any file the user said "keep going" about is
  fine; the commit is what's gated)
- `gh pr create` / `gh pr merge` / `gh pr close`
- force-push (`git push --force`) — only when the target branch is an
  empty-repo `main` you're initializing, never otherwise

`gh` is installed at `C:\Program Files\GitHub CLI\gh.exe` on this
machine. Use `& "C:\Program Files\GitHub CLI\gh.exe" <args>` from
PowerShell (the call operator is required — bare quoted paths won't
parse as commands in PS).

Auth: `gh auth status` confirms you're logged in. If a `gh` command
errors with auth, **stop and ask the user to run `gh auth login`**
interactively — do not store tokens or accept PASTED tokens in chat.

---

## Lint / verify / test

There is no test suite. What verifying exists (also enforced on push/PR
by `.github/workflows/lint.yml`):

1. **Bash syntax check** on every script edit (mirrors lint.yml's list,
   including the non-scripts .sh files it names explicitly):
   ```
   bash -n scripts/*.sh config/hypr/gpu-env.sh config/hypr/switch-theme.sh \
       config/vlc/vlc-open config/ghostty/ghostty-theme.sh
   ```
2. **JSON validity** on swaync + wlogout configs (with `jq`):
   ```
   jq . config/swaync/config.json        # has a // comment line — strip first if jq is strict
   jq . config/wlogout/layout           # same
   ```
3. **Conf file sanity** (the conv comment header on swaync's
   `config.json` and wlogout's `layout` is **deliberate** — keeps the
   `write` tool's JSON auto-detect from misparsing the file content as
   an object literal at session-time. Don't remove it without testing).

If you add a new script, structure, or behavior, run the relevant
syntax checks before committing, and add it to the lint workflow's
coverage if it isn't already (CI catches it otherwise).

---

## Components map — what changes where

| You want to...                                | File to edit                                                 |
|-----------------------------------------------|--------------------------------------------------------------|
| Change keybinds                               | `config/hypr/hyprland.conf`                                  |
| Add/remove a pywal-driven tool                | `config/hypr/hyprland.conf` (exec-once) + `config/<tool>/`    |
| Change cursor theme or size                   | `config/hypr/hyprland.conf` (`env = XCURSOR_*`, `HYPRCURSOR_*`) |
| Switch from ghostty to kitty / alacritty      | `config/hypr/hyprland.conf` (`$terminal = ...`)              |
| Change the code editor                        | `config/hypr/hyprland.conf` (`$editor`, `bind = $mod, E`) + `config/applications/zed-handler.desktop` (or replace with new one) |
| Add a new AUR-only package                    | `scripts/10-aur.sh` (`PACKAGES=(...)` array) **after** confirming via `archlinux.org/packages/?q=<name>` that it's not in official repos |
| Move a package from AUR to official           | remove from `scripts/10-aur.sh` `PACKAGES=()`, add to `scripts/00-base.sh`'s `pacman -S` block |
| Add/remove a language server                  | `scripts/00-base.sh` (step 4 block) if official-repo, else `scripts/10-aur.sh` |
| Change the Emacs config                       | `config/emacs/init.el` (opt-in; install prompt is `00-base.sh` step 8) |
| Add/change an nvim plugin                     | `config/nvim/init.lua` lazy.nvim spec block (constraints in its header + the editor plugin rule) |
| Edit gaming HUD defaults                      | `config/MangoHud/MangoHud.conf`                              |
| Change notification behavior                  | `config/swaync/config.json` + `config/swaync/style.css`      |
| Change status bar layout                      | `config/waybar/config` + `config/waybar/style.css`           |
| Change the wallpaper (user-side, post-install) | static: drop image at `~/.config/hypr/wallpaper.jpg`, run `wal -i`; animated: drop video at `~/.config/hypr/wallpaper.mp4` (mpvpaper) — NOT repo edits |
| Change the color theme (no wallpaper)          | SUPER+SHIFT+T or `~/.config/hypr/switch-theme.sh <mocha\|gruvbox\|tokyonight\|osaka-jade>`; presets live in `config/hypr/themes/` |

---

## Color palette contract

Color theming is **pywal16-driven, single source of truth**. The flow:

1. `hyprland.conf` runs `wal -i ~/.config/hypr/wallpaper.jpg` at session
   start when the wallpaper exists; otherwise it applies the selected
   preset theme via `switch-theme.sh` (see step 7)
2. pywal16 writes `~/.cache/wal/colors-waybar.css` (stock pywal16 template,
   GTK `@define-color` syntax), `~/.cache/wal/colors-rofi.rasi` (from the
   **custom** user template this repo ships), and
   `~/.cache/wal/colors-wal.vim`
3. The GTK-CSS components (`waybar/style.css`, `swaync/style.css`,
   `eww/eww.scss`, `wlogout/style.css`) all
   `@import "../../.cache/wal/colors-waybar.css";` at the top. Do **not**
   point them at `colors.css` — that file is web-CSS (`:root { --var }`)
   which GTK CSS's `@name` references cannot resolve.
4. `rofi/config.rasi` imports `~/.cache/wal/colors-rofi.rasi`, generated
   from the custom template at `config/wal/templates/colors-rofi.rasi`
   (raw `@colorN` scheme matching this rice's design). The stock
   `colors-rofi-dark.rasi` was deliberately NOT used — its semantic names
   don't match. `config/wal/templates/` MUST stay covered by
   `30-dotfiles.sh`'s blanket `config/` install step so the templates
   reach `~/.config/wal/templates/` where `wal` reads them — this covers
   `colors-zed.json` (item 7's Zed theme) the same way.
5. Neovim sources `~/.cache/wal/colors-wal.vim` at editor open (falls back
   to a baked Catppuccin Mocha palette if pywal hasn't run yet) and its
   plugin UIs (cmp/telescope/nvim-tree) link into those same highlight
   groups — no colorscheme plugins, per the editor plugin rule below.
   Emacs
   (opt-in) does the same with `~/.cache/wal/colors.el`, generated from
   the custom template at `config/wal/templates/colors.el` — same
   fallback, same `config/wal/templates/` install requirement as item 4.
6. Ghostty doesn't `@import` CSS, so the palette reaches it through a
   generated include: `config/ghostty/ghostty-theme.sh` turns
   `~/.cache/wal/colors.sh` into `~/.config/ghostty/colors.conf`
   (background/foreground/palette 0..15, hex without `#`) and runs
   `ghostty +reload-config` when an instance is up (skipped quietly
   otherwise). It's called from `hyprland.conf`'s exec-once right after
   `wal -i`, and from `switch-theme.sh` right after a preset copy.
   Ghostty loads `config-file` includes AFTER the primary config, so
   colors.conf overrides the Catppuccin Mocha palette baked into
   `config/ghostty/config` — keep those baked lines, they're the
   fallback until wal's first run. colors.conf must only set keys the
   main config already carries for palette purposes; don't add keys
   like `background-opacity` to it.
7. Zed reads a generated theme: wal renders the user template
   `config/wal/templates/colors-zed.json` into `~/.cache/wal/colors-zed.json`;
   `30-dotfiles.sh` symlinks that path to `~/.config/zed/themes/pywal.json`
   and `config/zed/settings.json` selects theme "Pywal". Zed hot-reloads
   theme files on change, so no reload hook is needed. The catppuccin
   extension stays auto-installed as the cold-boot fallback for before
   wal's first run.
8. Hyprland's own borders: `hyprland.conf` ends with
   `source = ~/.cache/wal/colors-hyprland.conf` (wal renders it from the
   `config/wal/templates/colors-hyprland.conf` template; presets carry a
   rendered copy). Later assignment wins over the baked `rgb()` values in
   `general {}`, and Hyprland auto-reloads sourced files, so any palette
   change repaints borders live. `30-dotfiles.sh` pre-seeds the file via
   the mocha preset so the source line always resolves on first boot.
9. Preset themes (used when no wallpaper is set): `config/hypr/themes/`
   ships `mocha` / `gruvbox` / `tokyonight` / `osaka-jade` (values ported
   from omarchy upstream) as pre-generated copies of
   pywal's own output files; `config/hypr/switch-theme.sh` (SUPER+SHIFT+T
   cycles) copies them into `~/.cache/wal/` and records the choice in
   `~/.cache/wal/current-theme`. Rules: presets are applied ONLY via the
   switcher; `wal -i` still wins whenever `wallpaper.jpg` exists; never
   hand-edit files inside `~/.cache/wal/` (they're regenerated); when
   adding a preset, keep all seven file formats (colors-waybar.css,
   colors-rofi.rasi, colors-wal.vim, colors.el, colors.sh,
   colors-zed.json, colors-hyprland.conf) in sync AND
   listed in `switch-theme.sh`'s `cp -f` — a format missing from either
   place leaves that consumer on a stale palette after a switch; VLC
   stays unthemed by design — every other in-session component follows
   the palette (ghostty item 6, zed item 7, hyprland borders item 8).

When adding a new themed component, follow the CSS `@import` pattern.
Don't hardcode hex colors that should match the dynamic palette.

---

## Editor plugin rule (replaces the old "no plugins" stance)

The previous blanket "no plugins anywhere" is lifted for nvim only:

- **nvim** — plugins are allowed via **lazy.nvim**, specs inline in the
  single `config/nvim/init.lua` (do not split into a lua/ tree). Hard
  constraints, enforced by code review: **no colorscheme plugins**
  (pywal owns color — plugin UIs link into the wal-driven highlight
  groups), **no mason** (LSP servers are system packages from
  `00-base.sh` / `10-aur.sh`, language servers are compiled/packaged,
  not mason's generic prebuilt binaries), and FATS/SUPER mode (F2) +
  the hand-rolled statusline stay. Versions are pinned, not floating:
  the bootstrap clones lazy.nvim and checks out a hardcoded commit SHA
  (no `--branch=stable`), and `config/nvim/lazy-lock.json` is committed
  — `30-dotfiles.sh`'s blanket config/ copy lands it at
  `~/.config/nvim/lazy-lock.json`, lazy.nvim's default lockfile path.
  Bumping a plugin version means reviewing the upstream diff between
  old and new pinned commit before updating lazy-lock.json — same
  review obligation as an AUR PKGBUILD bump, just without the
  10-aur.sh script wrapping it.
- **Emacs** — unchanged: no package manager, eglot from core.
- **Zed** — extensions only as cold-boot theme fallback (catppuccin);
  the real palette is the wal-generated "Pywal" theme (palette contract
  item 7). Don't start an extension stack.

---

## Monitor + wallpaper contract (must NOT regress)

- `config/hypr/hyprland.conf` ships with `monitor=,preferred,auto,1`
  — this is a **documented stopgap**, not the committed config. **Do
  not** commit a "real" value; the user is expected to run
  `hyprctl monitors` after first boot and replace it. The README's
  "Mandatory first-boot TODOs" section is the contract.
- `config/hypr/hyprpaper.conf` ships with `wallpaper = eDP-1, ...`
  where `eDP-1` is a placeholder. Same deal — user replaces with the
  real monitor name. **Don't** run `hyprctl monitors` from a script to
  auto-fill the line; the stopgap is intentional.
- The wallpaper path `~/.config/hypr/wallpaper.jpg` is a TODO the user
  fills in after `30-dotfiles.sh` runs. **Don't** vendor a wallpaper
  binary into this repo.
- Animated wallpaper: `hyprland.conf` starts **mpvpaper** (AUR) pointed
  at `~/.config/hypr/wallpaper.mp4` — also a user-side TODO, same rules:
  `eDP-1` in the mpvpaper line is a placeholder for the real monitor
  name, **don't** auto-fill it, **don't** vendor a video binary.
  `hyprpaper` stays installed and wired as the commented fallback line;
  `hyprpaper.conf` is the static-fallback config. Keep both paths
  working — swapping between them must stay a one-line comment toggle.

---

## GPU-agnostic contract (must NOT regress)

The rice works on either NVIDIA proprietary or Intel/AMD Mesa without
the user re-editing configs. Mechanism (see README "GPU compatibility"
section for the user-facing version):

1. `scripts/00-base.sh` detects vendor via `lspci` and installs the
   right driver stack with a confirmation prompt.
2. `config/hypr/hyprland.conf` has a commented `# NVIDIA:` env block
   at the bottom of the `# ---- Environment` section. Default
   (uncommented) = Intel/AMD mode. NVIDIA users uncomment that block.
   Don't replace this with an auto-detect at runtime — Hyprland's
   `env =` lines are parsed at config-load, not at exec-once time, so
   conditional envs cannot work.
3. `config/hypr/gpu-env.sh` is the runtime shim for app-level env vars
   (`__GL_*`, `LIBVA_DRIVER_NAME`, `VDPAU_DRIVER`, `Mesa_*`). User
   sources it from `.zshrc` or `.bashrc`. Auto-detects at shell start.
4. README documents NVIDIA kernel cmdline requirements:
   `nvidia_drm.modeset=1 nvidia_drm.fbdev=1`.

When changing GPU-related env vars, update **all three** layers in
lockstep, or the rice regresses on one of the two vendors without an
obvious failure mode.

---

## Display manager rollback contract (must NOT regress)

`scripts/20-sddm.sh` does the following before touching SDDM config:

- Snapshots `/etc/sddm.conf.d` and `/usr/share/sddm/themes` to
  `/root/sddm-snap.<TS>/`
- Records the previously-working `Current=` value in
  `/root/sddm-snap.<TS>/PREVIOUS_Current.txt`
- Does NOT remove plasma/kde session entries (so Plasma is always a
  fallback login in SDDM's session picker)

The README's "Rolling back if SDDM crashes" section documents the
TTY-based recovery procedure. Don't break this pattern — keep the KDE
fallback entry intact, keep the snapshot-before-change ethos, keep the
rollback procedure in the README in sync with the actual script.

---

## Sudoedit / $EDITOR gotcha (don't regress)

`$EDITOR` and `$VISUAL` are set to `zed --wait` in `hyprland.conf`.
This works for `git commit`, `crontab -e`, and most terminal tools. It
**does not** work cleanly for `sudoedit`/`visudo` because Zed is a
Wayland GUI app launched from a root process — it can't connect to
the user's wayland socket. The README documents the fallback
(`sudoedit -e nano` — `nano` is installed by `00-base.sh` specifically
for this).

Don't change `$EDITOR` to a TUI editor "to fix sudoedit" without
asking — the current setup is the user's explicit choice ("zed for
python c c++ lua java rust json"), and `nano` is the documented escape
hatch for the corner cases.

---

## Commit / PR style

- Commit message body wrapped at ~70 chars, paragraphs separated by
  blank lines, no `git commit -m` for non-trivial commits — write
  a real multi-line message.
- Don't squash context: scripts changed, dotfiles changed, and
  README changes can all be one commit if they're coherent (e.g.
  "add new component" — installs it, configs it, documents it). If
  the user added a feature and you also need to update the AUR audit
  table, those belong in the same commit.
- Always update the README's "AUR-only packages" audit table when
  the AUR set changes. The table is the rule-5 contract.
- **No emojis** in commit messages or file contents unless the user
  asks for them.
- Don't add comments to existing code unless asked, and the comments
  that *are* in the configs/scripts are intentional documentation
  (rollback procedures, gotchas, the gpu-env.sh vendor detection, the
  sudoedit explanation in `hyprland.conf`, the `// swaync config.`
  comment header that protects the JSON file from the write tool's
  autodetection). Don't strip them as "cleanup".

---

## "Keep going" semantics

When the user says "keep going" without further specification, interpret
it as "continue from where you left off and finish the in-flight task."
That means:

- finish the file you were writing
- finish the commit you were staging
- finish the PR description you were drafting
- run the syntax checks (`bash -n`, `jq .`) on anything changed
- push to the same branch / open the PR / merge per the existing flow

It does **not** mean "start a new feature" or "invent the next task."
If the in-flight task is already done and the user says "keep going,"
**ask** what they want next rather than guessing.
