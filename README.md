<div align="center">

# linux-rice

**A reviewable Hyprland dotfiles + installer set for Arch Linux.**
Multi-monitor · GPU-agnostic (NVIDIA / Intel / AMD) · btrfs **or** ext4 root
No `curl | bash` installers · performance-first builds · source compilation
only when it is expected to help

[Components](#whats-in-this-rice) —
[Source-built packages](#source-built-package-inventory) —
[Install](#installation-steps) —
[First-boot TODOs](#mandatory-first-boot-todos) —
[Tree](#tree)

</div>

---

## Contents

- [What's in this rice](#whats-in-this-rice)
- [Source-built package inventory](#source-built-package-inventory)
- [Themes (wallpaper mode + 4 presets)](#themes-wallpaper-mode--4-presets)
- [GPU compatibility](#gpu-compatibility-nvidia--intel--amd-same-config)
- [Step 0: installing Arch itself](#step-0-installing-arch-itself-archinstall-from-the-iso)
- [Installation steps](#installation-steps)
- [Mandatory first-boot TODOs](#mandatory-first-boot-todos)
- [Rolling back if SDDM crashes](#rolling-back-if-sddm-crashes)
- [Snapshots (btrfs / ext4)](#snapshots-btrfs---snapper-anything-else---timeshift-rsync)
- [Code editor setup (Zed, Neovim, Ghostty)](#code-editor-setup-zed-neovim-ghostty)
- [Gaming launch-option recipes](#steam--wine--proton-launch-option-recipes-gaming-set)
- [Performance compilation policy](#performance-compilation-policy)
- [Notable bug-fix audit](#notable-bug-fix-audit-reviewer-pass)
  - [Pass 1: governance docs + package provenance](#review-pass-1--governance-docs-and-package-provenance-audit)
  - [Review pass 1: package provenance & security](#review-pass-1--package-provenance--security-audit)
  - [Pass 2: install/update/rollback scripts](#review-pass-2--installupdaterollback-script-logic)
- [Tree](#tree)
- [License](#license)

---

A personal Hyprland rice for AMD/Intel/NVIDIA Arch Linux desktops,
including laptops, docks, and multi-monitor setups.
Install is staged into reviewable scripts with no `curl | bash`
installers. Packages are compiled from source only when a measurable
performance benefit is expected; otherwise the simplest reliable package
source is used. The packages this rice does compile use CPU-native flags
(`-march=native`).

## What's in this rice

| Component        | Tool                 | Source                  | Notes |
|------------------|----------------------|-------------------------|-------|
| Compositor       | Hyprland             | pacman (extra)          |       |
| Status bar       | waybar               | pacman (extra)          |       |
| Notifications    | swaync               | pacman (extra)          | control-center + popup |
| Launcher         | rofi                | pacman (extra)          | was AUR-only (as rofi-wayland), absorbed upstream into rofi 2.0 |
| Wallpaper        | awww                 | pacman (extra)          | was AUR-only (as swww), renamed upstream to awww |
| Animated wallpaper | mpvpaper           | **AUR — makepkg'd**     | default; hyprpaper kept as static fallback |
| Wall daemon      | hyprpaper            | pacman (extra)          | static fallback config |
| Clipboard        | cliphist + wl-clipboard | pacman (extra)       |       |
| Idle / lock      | hypridle + hyprlock  | pacman (extra)          |       |
| Color theming    | python-pywal16       | **AUR — makepkg'd**     |       |
| Widgets          | eww                  | **AUR — makepkg'd**     | tiny demo widget alongside waybar |
| Cursor theme     | bibata-cursor-theme  | **AUR — makepkg'd**     | Modern variant, 24px |
| Logout menu      | wlogout              | **AUR — makepkg'd**     |       |
| Terminal         | ghostty              | pacman (extra)          | primary; shell = fish (pacman) |
| Terminal multiplexer | tmux             | pacman (extra)          |       |
| Git TUI          | lazygit              | pacman (extra)          |       |
| Code editor      | zed                  | pacman (extra)          | primary $EDITOR + $CODE for python/c/c++/lua/java/rust/json; theme "Pywal" generated from wal (catppuccin ext kept as cold-boot fallback). Was AUR-only, moved upstream — used `scripts/10-aur.sh` before; standalone: `scripts/install-zed.sh` |
| GUI code editor   | lapce                | pacman (extra)          | optional Rust editor with built-in LSP, terminal, remote development, and Vim mode |
| Terminal editor   | croft                | upstream cargo install  | optional VS Code-style TUI; no Arch/AUR package, launcher prints the reviewed, version-pinned install command (croft-software 0.1.942) and holds the terminal open so you can read it |
| Quick editor     | neovim              | pacman (extra)          | terminal IDE: lazy.nvim plugins (lspconfig / treesitter / cmp / telescope / nvim-tree), pywal-driven colors, FATS/SUPER mode (F2) |
| Neovim GUI       | neovide              | pacman (extra)          | GPU-accelerated Neovim client; inherits the pywal-driven Neovim palette |
| Terminal editor  | ox                  | **AUR — makepkg'd**     | lightweight TUI editor; Ox config is generated from the active pywal16 palette; `ox-bin` verified on AUR 2026-09-25 (PKGBUILD review still applies at approve time) |
| GPU Emacs fork   | neomacs              | **AUR — makepkg'd**     | experimental Rust/wgpu Emacs fork; reuses the existing pywal-driven Emacs config |
| Alt editor       | emacs-wayland        | pacman (extra)          | **opt-in** (00-base.sh prompts); PGTK/native-Wayland build; pywal-driven, no package manager, LSP via built-in eglot |
| Language servers | pyright rust-analyzer clang lua-language-server bash-language-server gopls typescript-language-server | pacman (extra) | plain `$PATH` binaries; used by Zed + Emacs/eglot |
| Email / calendar | neomutt + khal + vdirsyncer | pacman (extra) | Neomutt mail, ikhal calendar, Google Calendar sync |
| AI coding tools | Claude Code + DeepSeek Harness + Kilo Code | user-installed CLIs | Terminal launch bindings; credentials stay in each tool's own config |
| HTML/CSS/JSON LSP | vscode-langservers-extracted | **AUR — makepkg'd** | the only LSP not in official repos |
| Browser          | helium-browser       | **AUR — helium-browser-bin** | default; xdg-mime default for http(s)/ftp/html |
| Media player     | vlc                  | pacman (extra)          | default for video/audio MIME types; ships `config/vlc/vlcrc` (deliberately minimal — decoding and snapshot dir left on VLC's defaults, see file comments) |
| Screen recorder  | obs-studio            | pacman (extra)          | open-source Wayland-capable recording and streaming; SUPER+SHIFT+O |
| Audio recorder   | audacity              | pacman (extra)          | GPL audio waveform recorder/editor; SUPER+SHIFT+U |
| URL resolver     | yt-dlp               | pacman (extra)          | YouTube et al. -> direct stream URL for vlc-open (SUPER+SHIFT+M); vlc's own youtube.lua is NOT trusted (breaks on every YT player change) |
| Live resolver    | streamlink           | pacman (extra)          | Twitch/live streams; drives VLC itself via `--player vlc` |
| TUI file mgr     | yazi                 | pacman (extra)          | SUPER+SHIFT+E |
| GUI file mgr     | thunar               | pacman (extra)          | SUPER+SHIFT+F; +gvfs +tumbler +thunar-archive-plugin |
| Display manager  | sddm                 | pacman (extra)          |       |
| SDDM theme       | sddm-astronaut-theme | **bare git clone**      | static-asset policy: no build step, cloned straight into /usr/share/sddm/themes |
| GTK theming GUI  | nwg-look             | pacman (extra)          |       |
| Qt theming       | kvantum / kvantum-qt5 | pacman (extra)         |       |
| Gaming           | gamemode mangohud lib32-mangohud steam | pacman (extra/multilib) | steam installed by 00-base.sh (multilib) |
| Themes           | presets + switcher   | shipped files           | wallpaper (pywal) default; mocha/gruvbox/tokyonight/osaka-jade presets, SUPER+SHIFT+T cycles |
| Password manager | bitwarden            | pacman (extra)          | SUPER+V; org.freedesktop.secrets covered by gnome-keyring (already installed) |
| Bluetooth        | bluez bluez-utils blueman | pacman (extra)     | bluetooth.service enabled by 00-base.sh; blueman-applet autostarts into waybar's tray |
| Firewall         | ufw                  | pacman (extra)          | default deny incoming / allow outgoing, enabled by 00-base.sh |
| Antivirus        | clamav + chkrootkit  | pacman (extra) + AUR   | daily on-demand `clamscan`; `chkrootkit` is run manually; freshclam keeps signatures current |
| MAC / shields    | apparmor             | pacman (extra)          | LSM mandatory access control; inert until the kernel cmdline opt-in — first-boot TODO #4 |
| Per-app sandbox  | firejail             | pacman (extra)          | wrap a single app: `firejail <cmd>`; profiles in /etc/firejail |
| Snapshots        | snapper / timeshift + cronie | pacman (extra)   | picked by root fs — btrfs gets snapper, anything else gets Timeshift RSYNC (`45-snapshots.sh`) |
---

### Antivirus and rootkit checks

`00-base.sh` installs official-repository ClamAV and `libnotify`, enables
`clamav-freshclam.service`, and `30-dotfiles.sh` enables a daily user timer
that scans `~/Downloads`, the existing `~/Mail/gmail` and `~/Mail/other`
Maildirs, and discovered mounted Windows `Users` directories. Results are
reported through SwayNC via `notify-send`; detections and scan errors use
critical urgency. Logs remain in `~/.cache/clamav-scan.log`.

`chkrootkit` is AUR-only and is handled by the reviewed `10-aur.sh` pipeline.
Run `sudo chkrootkit` manually when a rootkit check is needed. The optional
`clamonacc` fanotify layer is intentionally not enabled because it scans file
events continuously; this rice does not enable on-access scanning by default.

Ox uses its upstream Lua `.oxrc` format (not RON). The rice renders
`~/.config/ox/.oxrc` from `~/.cache/wal/colors.sh`; `SUPER+R` launches it
through `config/ox/ox-launch.sh`. Neovide inherits the existing Neovim
configuration and palette without defining a second GUI color scheme.
Neomacs reuses `~/.config/emacs/init.el`, so its palette remains owned by
the existing `colors.el` pywal template.

## Source-built package inventory

These are the packages currently handled by the reviewed source-build
workflow. Other packages use the normal distribution install path unless
there is a documented performance reason to add them here.

| Package                | AUR URL                                  | Build notes                                                      |
|------------------------|------------------------------------------|------------------------------------------------------------------|
| `eww`                  | `<https://aur.archlinux.org/eww.git>`    | Rust build, fetches crates from crates.io                         |
| `python-pywal16`       | `<https://aur.archlinux.org/python-pywal16.git>` | Python package, active fork of pywal              |
| `bibata-cursor-theme`  | `<https://aur.archlinux.org/bibata-cursor-theme.git>` | Cursor theme, has install hooks (systemctl-like) |
| `wlogout`              | `<https://aur.archlinux.org/wlogout.git>` | Wayland logout menu, GTK3                                         |
| `ox-bin`               | `<https://aur.archlinux.org/ox-bin.git>` | Prebuilt Ox editor binary. Verified on AUR 2026-09-25 (0.7.7-1, maintained by Ox's upstream author). `ox-git` is the source-build alternative; still review source URLs/checksums at approve time. |
| `neomacs-bin`          | `<https://aur.archlinux.org/neomacs-bin.git>` | Prebuilt experimental GPU Emacs fork. Verified on AUR 2026-09-25 (0.0.19-1, sources eval-exec/neomacs). Still review release URLs, checksums, and install paths before approval. |
| `helium-browser-bin`   | `<https://aur.archlinux.org/helium-browser-bin.git>` | Precompiled Helium (imputnet chromium fork), repackaged from the upstream release tarball — verified WITH its `.asc` via `validpgpkeys` (Helium signing key), plus two sha256-pinned local patches. No build(), no hooks, no curl\|bash. |
| `mpvpaper`             | `<https://aur.archlinux.org/mpvpaper.git>` | Video wallpaper daemon (v1.9). Pinned GitHub release tarball with b2sum, meson/ninja build, deps libmpv + libwayland (mpv auto-pulled by makepkg -s), optdep socat. No install hooks, no curl\|bash, no red flags. |
| `vscode-langservers-extracted` | `<https://aur.archlinux.org/vscode-langservers-extracted.git>` | HTML/CSS/JSON/ESLint language servers (v4.10.0), used by Zed and Emacs' eglot. Source is the upstream npm registry tarball pinned with a sha256sum; `package()` is `npm i -g` into `$pkgdir` with the npm cache confined to `$srcdir`, plus chown + license install. No `build()`, no install hooks, no curl\|bash. It vendors node_modules — inherent to the npm tarball, not added by the PKGBUILD. |

**Packages you originally listed as AUR-only that are now in official
repos** — these are installed by `scripts/00-base.sh`, **not** built:

- `rofi` — in `extra` (2.0.0-1; provides/replaces the former AUR name `rofi-wayland`)
- `ghostty` — in `extra`
- `awww` — in `extra` (0.12.1-1; provides/replaces the former AUR name `swww`)
- `swaync` — in `extra`
- `cliphist` — in `extra`
- `nwg-look` — in `extra`
- `kvantum` and `kvantum-qt5` — in `extra`
- `zed` — in `extra` (1.21.0-1, moved upstream in 2026; was previously built via `10-aur.sh`)

### Mail and calendar setup

`30-dotfiles.sh` copies the account examples into
`~/.config/neomutt/accounts/` (and the msmtp/isync examples into their
real config names) only when no real file exists yet — local
personalization is never overwritten. Replace the placeholders after
install; the real files are gitignored. The Gmail account uses OAuth2
through Neomutt's packaged `mutt_oauth2.py`: locate it with
`pacman -Ql neomutt | grep oauth2`, copy it to
`~/.config/neomutt/oauth/mutt_oauth2.py` (the path the example configs
reference), and authorize the token alongside it.

The public `~/.config/msmtp/config.example` and
`~/.config/isync/mbsyncrc.example` follow the same copy-if-absent rule
and are installed mode 600. Neomutt signing is
disabled until `YOUR_GPG_KEY_ID_HERE` is replaced with a real key and
`crypt_autosign` is explicitly enabled.
Folder-hooks re-source the matching account file when a mailbox is
opened, so `from`/`sendmail` always follow the mailbox you're in and
outgoing mail uses the reviewed local msmtp configuration.

Copy `~/.config/vdirsyncer/config.example` to
`~/.config/vdirsyncer/config`, add the separate Google Calendar OAuth
client credentials, then run `vdirsyncer discover google_calendar`.
`30-dotfiles.sh` offers to enable the ClamAV timer and enables the calendar
timer only once this real config exists.

### AI coding tools

The Hyprland config provides terminal launch bindings for locally
installed AI coding tools:

- `SUPER+SHIFT+A` — Claude Code (`claude`)
- `SUPER+SHIFT+D` — DeepSeek Harness (`deepseek-harness`)
- `SUPER+SHIFT+I` — Kilo Code (`kilo`)

These tools are intentionally not installed by the rice. Set the
`$claude_command`, `$deepseek_command`, or `$kilo_command` variables in
`~/.config/hypr/keybinds-extra.conf` if a local installation uses a different
command name. API keys and authentication remain in each tool's own
credential store and are not committed here.

### Keybind customization

All user-editable launch keys and command names are grouped at the top
of `config/hypr/keybinds-extra.conf`, which is copied to
`~/.config/hypr/keybinds-extra.conf`. Change a `$key_*` value to move a
shortcut or a `$_command` value to match a locally installed executable.
Reload with `hyprctl reload` or `SUPER+SHIFT+C`. The main
`hyprland.conf` keeps the complete categorized reference list.
`SUPER+SHIFT+/` lists every parsed keybind in a rofi menu (with `$var`s
resolved) and opens the selected one at its file:line in `$editor`. The
edit target is the **repo checkout's** config file, not the deployed
`~/.config` copy — 30-dotfiles.sh bakes the checkout path into the
binary at build time, so edits are git-visible and survive the next
deploy instead of being overwritten by it.
- `gamemode`, `gamescope`, `mangohud`, `lib32-mangohud` — in `extra` + `multilib`

> The policy is "use AUR for whatever has no official-repo equivalent"
> (AUR helpers are tolerated but the scripts keep the reviewed pipeline),
> and whatever we do build from AUR is compiled CPU-native.
> When the AUR-only list you used to need folds into upstream Arch repos,
> we stop building that thing from AUR and start using `pacman -S`.

---

## Themes (wallpaper mode + 4 presets)

The default look is **wallpaper mode**: `wal -i` generates the palette
from `~/.config/hypr/wallpaper.jpg` (see first-boot TODOs). Without a
wallpaper the rice uses one of four shipped static presets —
**Catppuccin Mocha** (default), **Gruvbox Dark**, **Tokyo Night**,
**Osaka Jade** (values ported from omarchy's upstream
`themes/osaka-jade/colors.toml`) — all pre-generated in pywal's own
file formats under `config/hypr/themes/`, so every themed component —
waybar, swaync, rofi, eww, wlogout, nvim, emacs, ghostty, zed, and
Hyprland's own window borders — picks them up unchanged. Each preset
dir carries all eight formats the rice consumes: `colors-waybar.css`,
`colors-rofi.rasi`, `colors-wal.vim`, `colors.el`, `colors.sh`,
`colors-zed.json`, `colors-hyprland.conf`, `colors-neomutt.muttrc`.

Switching:

| How                                          | Effect                                        |
|----------------------------------------------|-----------------------------------------------|
| `SUPER + SHIFT + T`                          | cycle mocha -> gruvbox -> tokyonight -> osaka-jade |
| `~/.config/hypr/switch-theme.sh <name>`      | apply a specific preset                        |
| `wal -i ~/.config/hypr/wallpaper.jpg`        | back to wallpaper mode (always wins)           |

Notes:

- The selected preset is recorded in `~/.cache/wal/current-theme` and
  reapplied at session start; presets never overwrite wallpaper mode —
  the moment `wallpaper.jpg` exists, `wal -i` takes over again.
- Ghostty follows both modes: `ghostty-theme.sh` converts the same
  `colors.sh` into `~/.config/ghostty/colors.conf` and reloads running
  windows (its baked Mocha palette is only the pre-wal fallback). Ox
  follows too: `ox-theme.sh` renders the same `colors.sh` into
  `~/.config/ox/.oxrc`, called from the same two refresh points as
  Ghostty (the exec-once `wal -i` branch and `switch-theme.sh`).
  Zed follows too: every mode lands `colors-zed.json` in `~/.cache/wal/`,
  which is symlinked to `~/.config/zed/themes/pywal.json` and
  hot-reloaded as the "Pywal" theme. Window borders follow too —
  `hyprland.conf` ends with `source = ~/.cache/wal/colors-hyprland.conf`,
  so any palette change repaints them live. VLC isn't themed by
  presets (by design), and GTK/Qt apps use nwg-look / kvantum profiles
  which are manual picks, not wal-driven.
- Preset sync is enforced, not assumed: `scripts/lint-themes.sh` checks —
  for every preset — that all eight per-app formats are present, that
  every hex value in every format file comes from that preset's own
  `colors.sh`, and that `switch-theme.sh` copies exactly the files the
  presets ship (no orphans, no omissions). It runs in the lint CI
  workflow and in the `60-update.sh` lint gate, so a drifted theme
  blocks an update instead of silently shipping.

---

## GPU compatibility (NVIDIA + Intel + AMD, same config)

The rice ships **one** `hyprland.conf` that works on either vendor with
a single commented/uncommented block. Default (no edits) = Intel/AMD.

### Vendor detection

`scripts/00-base.sh` runs `lspci` to detect your GPU and installs the
right driver stack with a single confirmation prompt:

- **NVIDIA**: `nvidia`, `nvidia-utils`, `lib32-nvidia-utils` from `extra`/`multilib`
- **Intel/AMD**: `mesa`, `vulkan-radeon`, `vulkan-intel`, `intel-media-driver`,
  `libva-mesa-driver`, and the multilib (lib32-) siblings. No vendor-blob packages.

Either path keeps `mesa` itself installed (libGL/GLX/EGL remains sane).

### Vendor-specific env vars

Two layers:

1. **Hyprland-compositor env** in `config/hypr/hyprland.conf` — bottom of
   the `# ---- Environment` block. NVIDIA users uncomment every line
   marked `# NVIDIA:`. Intel/AMD users leave them commented. These are
   `env =` directives parsed by the compositor at config-load time, so
   they cannot be set conditionally at runtime — pick once.

2. **App-level env** in `config/hypr/gpu-env.sh`. Source from your `.zshrc`
   or `.bashrc` (fish users: it's a POSIX sh script — run it via `bass` or
   translate the exports to `set -gx` in `config.fish`):
   ```bash
   # ~/.zshrc or ~/.bashrc
   if [ -f ~/.config/hypr/gpu-env.sh ]; then
       . ~/.config/hypr/gpu-env.sh
   fi
   ```
   Auto-detects the GPU via `lspci` at shell start and exports the
   `__GL_THREADED_OPTIMIZATIONS`, `LIBVA_DRIVER_NAME`, `VDPAU_DRIVER`,
   `Mesa_*` overrides appropriate to that vendor. Games launched from
   Steam / Proton / CLI inherit these.

### NVIDIA-specific gotchas (read once if you're on NVIDIA)

1. **Kernel cmdline** — required for modeset-on-boot:
   ```
   nvidia_drm.modeset=1 nvidia_drm.fbdev=1
   ```
   For systemd-boot: edit `/etc/kernel/cmdline` (or `/boot/loader/entries/*.conf`)
   and reinstall `linux` (`sudo pacman -S linux`) so the cmdline is regenerated
   into the new EFI entry. For GRUB: edit `/etc/default/grub` -> `GRUB_CMDLINE_LINUX_DEFAULT`
   and run `grub-mkconfig -o /boot/grub/grub.cfg`.

2. **Hyprland config — uncomment the NVIDIA env block** in
   `~/.config/hypr/hyprland.conf`. The defaults shipped work on Intel/AMD;
   on NVIDIA the `WLR_NO_HARDWARE_CURSORS=1` line is the difference between
   a glitchy or invisible cursor (without) and a normal one (with).

3. **Don't install `nvidia-dkms` alongside `linux`** — pick one. `nvidia`
   works with stock `linux`. Use `nvidia-dkms` only if you're on `linux-zen`,
   `linux-lts`, or a custom kernel. `00-base.sh` installs the `nvidia`
   package by default; if you're on a non-stock kernel, install `nvidia-dkms`
   yourself.

4. **Wayland + NVIDIA NVK (Vulkan)** — recent `nvidia` packages ship NVK so
   `vulkan-nvidia` from the binary blob shouldn't be installed separately;
   `nvidia-utils` covers the userland GL stack. You don't need
   `vulkan-mesa-layers` either (Mesa's layers don't help on NVIDIA).

### Before any debugging "Hyprland is laggy on NVIDIA"

1. Did you set `nvidia_drm.modeset=1` on the cmdline? Verify with
   `cat /sys/module/nvidia_drm/parameters/modeset` — must print `Y`.
2. Did you uncomment the NVIDIA env block in `hyprland.conf`?
3. Is `nvidia-dkms` matching your kernel's package? `uname -r` vs `pacman -Q linux`.
4. Restart SDDM (`sudo systemctl restart sddm`), not just Hyprland.

---

## Step 0: installing Arch itself (archinstall, from the ISO)

The scripts in `scripts/` run on an ALREADY-INSTALLED Arch system. If
the box in front of you is still the live ISO, this is how you get from
there to here. Everything in this section runs on the ISO, as root.

1. Get online on the ISO. Ethernet just works; WiFi via `iwctl`
   (`station wlan0 connect "SSID"`).
2. Launch the guided installer: `archinstall`
3. The picks in archinstall that matter because this repo's scripts
   assume them downstream:
   - **Profile: minimal.** No desktop profile — Hyprland and everything
     else come from `scripts/00-base.sh`. Picking a desktop profile here
     means a whole DE left installed alongside the rice.
   - **Additional packages: leave empty.** `00-base.sh`'s pacman list
     covers everything; preinstalling here risks version conflict noise.
   - **Network: NetworkManager** (the same stack `00-base.sh` manages).
   - **Audio: pipewire** (`00-base.sh` installs pipewire + wireplumber).
   - **Bootloader: limine.** The AppArmor first-boot TODO and the NVIDIA
     cmdline notes are written against editing your Limine entry.
     systemd-boot/GRUB work too — translate those notes yourself if you
     pick them.
   - **Partitioning: btrfs or ext4, your call** — the rice is fine on
     either. The one place the answer matters is `45-snapshots.sh`,
     which picks snapshot tooling to match (btrfs -> snapper subvolume
     snapshots; ext4 and anything else -> Timeshift in RSYNC mode).
     See "Snapshots" further down.
   - **A regular user with sudo.** `00-base.sh` REFUSES to run as root.
   - Timezone/locale/keyboard: yours.
4. Reboot into the installed system and log in as that user.

The minimal profile doesn't seed `git`, and you need it to clone this
repo — first commands on the installed system:

```bash
sudo pacman -Syu
sudo pacman -S git
git clone https://github.com/Fatmanams/Hyprland-Fat-rice.git
cd Hyprland-Fat-rice
```

You are now at step 1 of "Installation steps" below.

---

## Installation steps

Run the staged scripts in order. **Read each one before running.** None
are silent; AUR builds explicitly pause and print the PKGBUILD for your
sign-off before building anything.

```bash
chmod +x scripts/*.sh

# 1. Official-repo install — also configures /etc/makepkg.conf with
#    MAKEFLAGS=-j$(nproc), ccache in BUILDENV, and CPU-native
#    CFLAGS/CXXFLAGS/RUSTFLAGS for everything the rice compiles; enables
#    [multilib], runs xdg-user-dirs-update (so ~/Pictures etc. exist —
#    VLC's default snapshot dir is the Pictures dir), enables
#    bluetooth.service, sets up the ufw firewall baseline
#    (deny incoming / allow outgoing), and enables ClamAV's freshclam
#    signature-updater (antivirus DB autoupdate). AppArmor is installed
#    but requires a hand-edited Limine cmdline — see first-boot TODOs.
#    Also installs the language-server stack (Zed finds them on $PATH,
#    nvim wires them via its lspconfig block, Emacs uses eglot).
#
#    Two interactive prompts near the end: the CPU `performance`
#    governor (cpupower — read the tradeoff comment in the script) and
#    the OPTIONAL emacs-wayland install. Both default to no.
./scripts/00-base.sh

# 2. AUR builds — reviewed PKGBUILD, plain makepkg (build only),
#    repo-add into your local repo at /var/cache/pacman/localrepo,
#    then pacman -S from there. Pause+review each source build.
./scripts/10-aur.sh

# 3. SDDM theme — bare git clone for the static asset. Snapshots the
#    old SDDM state first, then clones Keyitdev's sddm-astronaut-theme
#    into /usr/share/sddm/themes/sddm-astronaut-theme and addresses
#    Current= in a new conf.d/10-theme.conf.
./scripts/20-sddm.sh

# 4. Dotfiles — copies config/ tree into ~/.config, with a backup of
#    existing ~/.config first. Also installs zed-handler.desktop for
#    the MIME associations defined in hyprland.conf.
./scripts/30-dotfiles.sh

# 5. Gaming extras — verifies gamemoded, prints Steam/prismlauncher
#    launch-option templates.
./scripts/40-gaming.sh

# 6. Snapshots — picked by your root filesystem: btrfs gets snapper
#    (hourly timeline + cleanup timers, trimmed retention), anything
#    else gets Timeshift in RSYNC mode aimed at the root partition.
#    Both official-repo. No first snapshot is taken for you — the
#    starter command is printed at the end. Skippable.
./scripts/45-snapshots.sh

# 7. Post-deploy health check — read-only, reports PASS/FAIL never
#    auto-fixes: first-boot TODOs cleared, GPU driver matches the
#    hardware, ufw/clamav-freshclam/bluetooth live, SDDM enabled with
#    the theme's ConfigFile resolving inside the clone (rollback-
#    snapshot probe stays sudo-gated), every theme preset carrying all
#    eight pywal formats, and the snapshot tooling live (snapper timers
#    on btrfs, cronie otherwise — same branch 45-snapshots.sh took).
#    Best run after one Hyprland session has booted.
./scripts/50-verify.sh
```

You can run each script at most once. Reading them first is the point.

---

## Mandatory first-boot TODOs

Before the rice looks right:

1. **Monitor layout (optional for basic multi-monitor use).**
   `hyprland.conf` ships with:
   ```
   monitor=,preferred,auto,1
   ```
   The wildcard applies the preferred mode to every connected output and
   supports multiple monitors without hardcoded names. For custom modes,
   positions, scale, or rotation, run:
   ```
   hyprctl monitors
   ```
   and replace the wildcard with one explicit `monitor=` line per output.
   Example for a laptop plus a 1440p/144Hz DisplayPort display:
   ```
   monitor=eDP-1, 1920x1080@60, 0x0, 1
   monitor=DP-1, 2560x1440@144, 1920x0, 1
   ```

2. **Wallpaper.** Drop a JPG at `~/.config/hypr/wallpaper.jpg`. This is
   the path read by both `hyprpaper.conf`'s `path =` line AND the `wal -i`
   exec-once in `hyprland.conf` — keeping them in sync means changing
   the wallpaper is one command. Once dropped:
   ```
   wal -i ~/.config/hypr/wallpaper.jpg
   ```
   That regenerates `~/.cache/wal/colors-waybar.css` (imported by waybar /
   swaync / eww / wlogout) and `~/.cache/wal/colors-rofi.rasi` (imported by
   rofi) for their color palettes.

   **Animated wallpaper (mpvpaper, the default):** also drop a looping
   video at `~/.config/hypr/wallpaper.mp4`; the helper discovers every
   connected output and starts one wallpaper instance per monitor. If
   you'd rather have a static wallpaper,
   comment the mpvpaper line and uncomment the `exec-once = hyprpaper`
   line just below it.

3. **Static wallpaper (optional per-monitor override).**
   `hyprpaper.conf` covers every output with one `wallpaper { }` block
   whose `monitor = *` wildcard matches all outputs — current hyprpaper
   (Arch ships 0.8.4) has no `preload=` or flat
   `wallpaper = <monitor>, <path>` keywords, and it exits on a config it
   can't parse. Add one block per monitor (with the output's real name
   from `hyprctl monitors`) if displays need different images.

4. **AppArmor (only if you want the "shields" actually on).** The
   `apparmor` package is installed by `00-base.sh` but the LSM is INERT
   until the kernel loads it — Arch's stock `lsm=` list doesn't include
   it. Edit your Limine entry's kernel cmdline and append (order
   matters; this is the ArchWiki-recommended full list, with apparmor as
   the first "major" module):
   ```
   lsm=landlock,lockdown,yama,integrity,apparmor,bpf
   ```
   Then enable profile loading at boot and reboot:
   ```bash
   sudo systemctl enable apparmor.service
   ```
   Verify after reboot: `cat /sys/kernel/security/lsm` (apparmor in the
   list), `aa-enabled` → `Yes`, `aa-status` lists loaded profiles. The
   scripts deliberately do not edit Limine's config for you — same
   stopgap philosophy as the `monitor=` and `wallpaper.jpg` TODOs
   above: boot config is yours to edit by hand.

---

## Rolling back if SDDM crashes

SDDM is the riskiest single piece because a broken QML greeter can
land you at a black screen with no obvious way back into X or a tty.
This rice keeps:

- the KDE/Plasma session entry installed and selectable the whole
  time (so if Hyprland or the greeter itself breaks you can still log
  in to a Plasma session via SDDM's drop-down)
- a snapshot of the old `/etc/sddm.conf.d` + `/usr/share/sddm/themes`
  in `/root/sddm-snap.<TIMESTAMP>/` (created by `20-sddm.sh`)
- the previously working `Current=` value saved as
  `/root/sddm-snap.<TIMESTAMP>/PREVIOUS_Current.txt`

**If SDDM renders black** after running `20-sddm.sh`:

```bash
# 1. Switch to a TTY:
#    Ctrl + Alt + F3       (F1 or F2 is the greeter, may be black)

# 2. As root:
sudo systemctl stop sddm

# 3. Revert the conf.d drop-in that points Current= at the new theme:
sudo rm /etc/sddm.conf.d/10-theme.conf
#    Or, to fully roll back from the snapshot:
#    sudo cp -a /root/sddm-snap.<TS>/sddm.conf.d/. /etc/sddm.conf.d/
#    sudo cp -a /root/sddm-snap.<TS>/themes/.        /usr/share/sddm/themes/

# 4. Bring SDDM back:
sudo systemctl start sddm
```

If the issue persists, hold `Shift` while booting to get the SDDM
session picker, choose **Plasma** instead of Hyprland, and you have a
working GUI to investigate from.

---

## Snapshots (btrfs -> snapper, anything else -> Timeshift RSYNC)

`45-snapshots.sh` reads the filesystem of `/` with `findmnt` and sets
up the matching tool — one place the btrfs-vs-ext4 question is
answered:

- **btrfs** — `snapper` (official extra). Snapshots are native
  copy-on-write subvolume snapshots: instant, tiny, no separate backup
  partition. The script creates the `root` config, trims retention to
  **5 hourly + 7 daily** (weekly/monthly/yearly off), and enables
  `snapper-timeline.timer` + `snapper-cleanup.timer`. If archinstall's
  btrfs layout already mounted an empty `/.snapshots`, snapper refuses
  to create a config over it — the script detects exactly that case
  and offers the documented fix (unmount, delete the empty subvolume,
  recreate, remount) behind a `[y/N]` prompt. Manual snapshot:
  `sudo snapper -c root create -d "why"`.
- **ext4 (or anything else)** — `timeshift` (official extra) in
  **RSYNC mode**: file-level copies onto the root partition itself.
  Snapper is structurally impossible here — there is no subvolume to
  snapshot — and Timeshift's own BTRFS mode would be redundant on
  btrfs, hence the split. The script configures mode and target
  through Timeshift's own CLI (never a hand-written `default.json`),
  and enables `cronie` (Arch's timeshift schedules via `/etc/cron.d`).

Neither branch takes a first snapshot for you (nothing silent — a
fresh RSYNC baseline is a full-tree copy). After the script:

```bash
sudo snapper -c root create -d "baseline"          # btrfs
sudo timeshift --create --comments "baseline"      # ext4 / other
```

pacman-transaction hooks (`snap-pac` and friends) are AUR-only and
deliberately not wired in — they'd go through `10-aur.sh`'s review
pipeline if you ever want them.

---

## Updates and fail-safe rollback

The rice is a git checkout, and `30-dotfiles.sh` records every deploy
in `~/.local/state/hyprland-fat-rice/deployed.env` — the version string
is `git describe --tags --always --dirty` from the checkout (tag the
repo `vX.Y.Z` and it reads accordingly), and one line per run lands in
`update.log` next to it as the history. Everything else builds on that
record:

```bash
scripts/60-update.sh            # update from origin/main + redeploy
scripts/60-update.sh --dry-run  # show what would land, change nothing
scripts/61-rollback.sh          # by hand, after any failed update
```

`60-update.sh` is a phased pipeline with a hard rollback gate:

1. **Preflight** (refuses politely, exit 2): no root, must be a git
   checkout, clean worktree (`--stash` stashes for you), `deployed.env`
   must exist, another updater must not hold the lock.
2. **Fetch + report** — `git fetch --tags`, then `git log --oneline
   HEAD..origin/main` so you see what lands before it lands.
3. **Fail-safe snapshot** — snapper on btrfs, Timeshift otherwise (same
   detection as `45-snapshots.sh`). No tool, no update — take the escape
   hatch away and it refuses to run. Override with `--no-snapshot`.
4. **Advance** — `git merge --ff-only` only. Diverged history aborts;
   unconsumed.
5. **Lint gate** — the exact lint.yml checks against the new tree.
   Nothing is deployed before this passes.
6. **Apply** — re-runs `00-base.sh` → `45-snapshots.sh` in order,
   interactively where they always were.
7. **Gate** — `hyprctl reload` + `hyprctl configerrors` (skipped with a
   printed note outside a live session), then `scripts/50-verify.sh`.
8. **Report** — old → new version, gates, snapshot id, state file path.

Any phase-6/7 failure calls `scripts/61-rollback.sh` automatically:
check the repo out back where it was, restore `~/.config` from the
pre-update backup, re-run `30-dotfiles.sh` so binary artifacts
(keybind-menu's `-DRICE_REPO` build) match the restored source,
re-verify. Rollback never touches packages — if the failing phase was a
package/system one (00/10/20/40/45), the report prints the snapshot
restore command for your tool and leaves running it to you.

**Branch tracking.** `scripts/60-update.sh --branch <name>` tracks
`origin/<name>` through the same lint → deploy → gate → rollback
pipeline — that is how a feature branch gets a full-system test before
its PR. Switching back is just `--branch main`. Preflight refuses with
the real remote list when the branch doesn't exist.

**Verify drift check.** `50-verify.sh`'s last check compares
`deployed.env` against the checkout: if commits were pulled or the
branch moved without redeploying, it FAILs with both sides printed and
tells you to re-deploy.

**Update checker (notify-only, OFF by default).** A user timer reads
`deployed.env`, fetches, and puts a swaync notification when the tracked
branch has new commits. It never applies anything:

```bash
systemctl --user enable --now rice-update-check.timer
```

**When everything fails**: the snapshot printed by 60 stands, restore it
with the tool 45 set up (`sudo snapper undochange <N>..0` /
`sudo timeshift --restore --snapshot '<name>'`), and the KDE Plasma
session kept in SDDM is your last-resort graphical login.

---

## Code editor setup (Zed, Neovim, Ghostty)

Per your ask, **Zed** is the default editor for `python`, `c`, `c++`,
`lua`, `java`, `rust`, and `json` files. `hyprland.conf` runs
`xdg-mime default` at session start against the `zed-handler.desktop`
file copied by `30-dotfiles.sh` into `~/.local/share/applications/`.
The handler also covers adjacent types (C headers, JavaScript, TOML,
YAML, markdown, shell, plaintext).

Zed also ships a rice config at `config/zed/settings.json` (lands at
`~/.config/zed/` via the blanket copy): theme "Pywal" — a theme file
generated from wal's palette (template at
`config/wal/templates/colors-zed.json`, rendered to
`~/.cache/wal/colors-zed.json`, symlinked by `30-dotfiles.sh` to
`~/.config/zed/themes/pywal.json` and hot-reloaded by Zed) — plus
JetBrainsMono Nerd Font buffers, autosave on focus change, format on
save. The catppuccin extension stays auto-installed purely as the
cold-boot fallback for before wal first runs.

F2 gets the same modal-toggle contract nvim and Emacs have:
`config/zed/keymap.json` binds `f2` to `workspace::ToggleVimMode`,
Zed's native (no-extension) vim mode. `settings.json` leaves `vim_mode`
unset, so Zed opens in plain editing and F2 flips modal editing on —
F2 again turns it off. Same default-plain, F2-is-the-alternative
arrangement as nvim's FATS/SUPER and Emacs's supermode/fats-mode.

The Zed setup also enables signature help, code lenses, inlay hints,
relative line numbers, trailing-whitespace cleanup, final-newline
insertion, project-panel and terminal defaults, and exclusions for generated
trees such as `.git`, `node_modules`, `target`, and `.venv`. The existing
system language servers from `00-base.sh` remain the source of truth; no
Mason-like runtime installer or extension stack is introduced.

### Local dev databases (Postgres / MySQL / SQLite) for Zed

Accept the `[9/9]` prompts in `00-base.sh` and the rice installs+initializes
localhost databases for dev/learning:

- **PostgreSQL** — ArchWiki flow: `initdb` as the `postgres` service user
  into `/var/lib/postgres/data`, `postgresql.service` enabled+started, and
  your login gets a same-named superuser role and database (`psql`/`createdb`
  work with zero args). Loopback TCP is deliberately scoped: the step rewrites
  initdb's stock `host all all ... trust` rows to `sameuser` for your login
  role only and drops the replication rows — the `postgres` superuser is
  **not** reachable over TCP at all. That scoping is enforced fail-closed:
  before the service is enabled, the step re-reads `pg_hba.conf` on every
  run — first init or re-run against an existing cluster — and refuses to
  start the service if a wide-open `host all all` row survives or the
  file can't be read. Residual, documented: any local process
  can still claim *your* login role on loopback and reach *your* scratch DB;
  fine for a single-user dev box, revisit if that stops being true.
- **MariaDB (MySQL)** — Arch's drop-in MySQL (`mariadb` provides `mysql`):
  `mariadb-install-db` only if the datadir is empty, `mysqld.service`
  enabled+started, your login gets a same-named user (socket auth — no
  stored password) and a same-named database, so bare `mysql` works.
- **SQLite** — no service and nothing to initialize; `sqlite3 <file.db>`
  works as installed (the `sqlite` package rides the main install list).

Both servers listen on localhost by default; ufw (step 5) denies incoming
anyway. Declining a prompt leaves that package inert — `pacman -Rns` removes
it cleanly. Nothing here carries production credentials.

Zed auto-installs (`config/zed/settings.json`):

- `sql` — bundled tree-sitter SQL grammar (highlighting for all dialects;
  no server).
- `postgres-language-server` — the Supabase Postgres LSP (schema-aware
  completion, diagnostics, type checking; it connects to the running DB).
  Note it's **Postgres-only** — Zed has no MySQL/SQLite LSP extension yet;
  those get the `sql` grammar highlighting only.

The LSP reads `postgres-language-server.jsonc` from a project's root; this
repo ships one at the top level wired to `127.0.0.1:5432` with placeholder
credentials — set `username`/`database` to your login (what step [9/9]
created; it's also the only role TCP trust is scoped to). `password` stays
empty by design: trust auth ignores it and the file is tracked, so no real
secret belongs there. Copy it into any other project that needs it. If you skip answering the prompts,
nothing changes — the extension just sits without a live DB until you finish
setup by hand.

When this repository is opened as a Zed project, `.zed/tasks.json` provides
repo-local tasks for Bash syntax, JSON validation, the eight-format theme
contract, whitespace checking, and the combined lint pass. The keymap binds
`Ctrl+Alt+B` to task selection, `Ctrl+Alt+R` to rerun the last task,
`Ctrl+Alt+T` to focus the terminal, and `Ctrl+Alt+F` to format the current
buffer.

**Neovim** is the terminal IDE, configured at `~/.config/nvim/init.lua` —
still a single file, but plugin-powered since the plugin rule was
relaxed: **lazy.nvim** specs inline (nvim-lspconfig, treesitter pinned
to the stable `master` branch, nvim-cmp completion, telescope,
nvim-tree). First launch clones lazy.nvim pinned to a specific commit
(not the floating `stable` branch) and installs the specs — needs
network, once. Every plugin version is pinned: the committed
`config/nvim/lazy-lock.json` lands at `~/.config/nvim/lazy-lock.json`
(lazy.nvim's default lockfile path) via 30-dotfiles.sh's blanket
config copy, and bumping a pin means reviewing the upstream diff
between old and new commit first — the same review obligation as an
AUR PKGBUILD bump. Hard constraints documented in the file header:
no colorscheme plugins (pywal stays the one source of color and plugin
UIs link into the same highlight groups), no mason (LSP servers are
compiled/packaged system installs from `00-base.sh` and `10-aur.sh`),
and the rice's own UX stays:

F2 toggles two editing personalities in nvim: **fats mode** (the default —
nvim stays in Insert permanently; `Ctrl-O` is one-shot Normal, `Ctrl-S`
saves, `Ctrl-Z` undoes, and Ctrl-C/Ctrl-V work via the system clipboard)
and **supermode** (plain modal vim). The active mode shows in the
statusline as `FATS`/`SUPER`.

**Emacs** is **opt-in** — `00-base.sh`'s last step prompts for it and
defaults to no. If you accept, it installs `emacs-wayland` (the PGTK
build, which talks Wayland natively instead of going through XWayland;
same reasoning as `QT_QPA_PLATFORM=wayland` for Qt apps). The config at
`~/.config/emacs/init.el` mirrors the nvim philosophy: single file, no
package manager, no third-party packages, pywal-driven colors (from
`~/.cache/wal/colors.el`) with a Catppuccin Mocha fallback.

For LSP, the built-in **eglot** auto-starts — `init.el` hooks it onto
`prog-mode` via `eglot-ensure` (it's part of Emacs core since 29, so
nothing extra to install; `M-x eglot` still works manually). The core
tree-sitter major modes (`c-ts-mode`, `c++-ts-mode`, `java-ts-mode`,
`python-ts-mode`, `rust-ts-mode`, `json-ts-mode`) replace the plain
modes automatically whenever the language's grammar is installed —
guarded by `treesit-ready-p`, and grammars are never auto-downloaded
from inside Emacs (lua stays on plain `lua-mode`: there is no core
`lua-ts-mode`). Completion is eglot's own backend riding the built-in
`completion-at-point` — bound to `C-c C-i` (the `C-M-i` default also
still works). The servers themselves come from `00-base.sh` (pyright,
rust-analyzer, clangd, lua-language-server, bash-language-server, gopls,
typescript-language-server) plus `10-aur.sh` for the HTML/CSS/JSON/ESLint
set. Those same binaries are what Zed picks up off `$PATH`.

Emacs bindings use the `C-c` prefix (Emacs' reserved user-binding space,
so nothing built-in is clobbered — deliberately not a copy of nvim's
SPC-leader scheme, which would shadow self-insert here):
`C-c w` save, `C-c q` kill buffer, `C-c e` dired-jump, `C-c b` switch
buffer, `C-c n` toggle line numbers.

F2 mirrors nvim's modes with two hand-rolled minor modes (no packages,
same as the rest of this file): **fats-mode** (the startup default —
stock Emacs feel with `C-s` save, `C-z` undo, `C-a` select-all) and
**supermode** (a minimal vim-ish motion layer: `h/j/k/l`, `w`/`b` word
motion, `i` drops into a self-inserting phase, `<escape>`/`C-g` back to
motion). The mode line shows `SUPER` / `super/insert` / `FATS`.

If `~/.emacs.d` already exists on your box, Emacs ignores
`~/.config/emacs/` entirely (XDG precedence rules) — move the old dir
aside for this config to take effect.

**Ghostty** is the primary terminal. `~/.config/ghostty/config` bakes
Catppuccin Mocha as the fallback palette; once wal (or a preset) runs,
`ghostty-theme.sh`'s generated `colors.conf` include overrides it —
Ghostty applies `config-file` includes *after* the primary file — and
running windows pick the new palette up via `ghostty +reload-config`.

Bindings:

| Keybind           | Action                                       |
|-------------------|----------------------------------------------|
| `SUPER + E`        | Open Zed                                     |
| `SUPER + R`        | Open Ox in the terminal                     |
| `SUPER + Z`        | Open Neovide                                 |
| `SUPER + Y`        | Open Neomacs (GPU Emacs fork)               |
| `SUPER + G`        | Open Lapce                                    |
| `SUPER + C`        | Open croft in Ghostty (prints the pinned install hint and holds if missing) |
| `SUPER + SHIFT + E`| Open Thunar (was SUPER+E before Zed won it)  |
| `SUPER + SHIFT + T`| Cycle theme preset (mocha/gruvbox/tokyonight/osaka-jade) |
| `SUPER + V`        | Open Bitwarden                               |
| `SUPER + SHIFT + M`| Prompt for a URL in rofi, play it in VLC (YouTube etc. resolved by yt-dlp, Twitch by streamlink — see `config/vlc/vlc-open`) |
| `SUPER + SHIFT + /`| Browse every Hyprland keybind in rofi ($vars resolved); Enter opens the bind's file:line in `$editor` (repo checkout copy, so the change is tracked) |
| `F2` (in nvim/emacs) | Toggle fats mode <-> supermode (insert-forever readline style vs. modal/motion); statusbar/mode-line shows the active mode |


### Sudoedit / visudo gotcha

Zed is a Wayland GUI app, and `$EDITOR` is set to `zed --wait`. This works
for git commit messages (`git commit` blocks until you close the tab),
crontab (`crontab -e`), and most interactive `$EDITOR` invocations.

**It does not work cleanly from inside `sudoedit`/`visudo`** — those
run as root, and a Wayland GUI app launched from a root process won't be
able to connect to your user's wayland socket. For those specific cases,
pass an explicit editor:

```bash
sudoedit -e nano /path/to/file       # nano ships with /core
# or:
SUDO_EDITOR=nano sudoedit /path/to/file
```

`nano` is installed by `00-base.sh` specifically as this fallback. If
you'd rather have `$EDITOR` be `nano` globally and only use Zed when
explicitly invoked, edit `~/.config/hypr/hyprland.conf`'s `env = EDITOR...`
and `env = VISUAL...` lines. The `SUPER+E` bind for Zed is independent
and won't be affected.

---

## Steam / Wine / Proton launch-option recipes (gaming set)

Verify `gamemoded` is running:
```bash
systemctl --user status gamemoded
```

If not, start it once and enable for this user:
```bash
systemctl --user enable --now gamemoded.service
```

### Minecraft (PrismLauncher / MultiMC)

Best: skip the in-game profiler, use mangohud:
```
prismlauncher -- gamemoderun mangohud %command%
```

For no HUD (you'll read FPS via F3):
```
prismlauncher -- gamemoderun %command%
```

### Cities: Skylines (Steam/Proton)

```
gamemoderun mangohud %command%
```

For upscaled-Vulkan via gamescope at 1440p/144Hz:
```
gamescope -W 2560 -H 1440 -r 144 -f -- gamemoderun mangohud %command%
```

The MangoHud config at `~/.config/MangoHud/MangoHud.conf` covers FPS,
CPU/GPU stats, RAM, VRAM, swap, histogram, and is toggleable with
**Right Shift** during gameplay.

---

## Performance compilation policy

The only package policy is: **compile from source when the result is
expected to improve performance for this machine; otherwise use the
simplest reliable distribution method.**

The expected benefit must be concrete and workload-specific, such as
native CPU flags, parallel compilation, or a native Rust target. AUR
availability alone is not a reason to compile, and reliable prebuilt
packages should not be replaced without an expected performance gain.
The current scripts retain a reviewed AUR/local-repository workflow for
the packages this rice chooses to compile, but that workflow is an
implementation choice rather than an additional policy requirement.

### Build-speed tweaks (applied by `scripts/00-base.sh`)

- `/etc/makepkg.conf`:`MAKEFLAGS="-j$(nproc)"`
- `/etc/makepkg.conf`: `CFLAGS`/`CXXFLAGS` retargeted to
  `-march=native`, plus `RUSTFLAGS="-C target-cpu=native"` — everything
  the rice compiles (the AUR set) builds CPU-native. pacman's own
  binaries stay upstream-generic x86-64; source-rebuilding all of Arch
  would be a full source distro, which this rice is not.
- `/etc/makepkg.conf`:`BUILDENV=(... ccache ...)` — `ccache` from
  official repos; pays for itself against the AUR build queue
- Local repo at `/var/cache/pacman/localrepo` (`localrepo`,
  `SigLevel = Optional TrustAll`) — `10-aur.sh` registers it
  into `/etc/pacman.conf` once if not already present

### Gotchas handled proactively

- **xdg-desktop-portal-hyprland covers screen capture only.**
  File-picker dialogs in random GTK apps will hang or fail without
  `xdg-desktop-portal-gtk` alongside it as fallback. Both are
  installed by `00-base.sh`; `hyprland.conf` explicitly starts both
  user services at session start.
- **Multi-monitor defaults are intentionally wildcarded.** The shipped
  `monitor=,preferred,auto,1` applies the preferred mode to every connected
  output. Use `hyprctl monitors` and explicit per-output lines only when
  custom modes, positions, scale, or rotation are needed.

---

## Notable bug-fix audit (reviewer pass)

The repo went through a focused review pass that caught bugs where values
were written from memory rather than verified against upstream docs. The
patterns documented inline (in comments in `hypridle.conf`, `gpu-env.sh`,
`hyprland.conf`, `wlogout/layout`, `config/nvim/init.lua`) explain what
was wrong and what the correct spec says. Summary of what was caught:

- `scripts/10-aur.sh` — `makepkg -Cso` flag wrong (`-o` = "no build", per
  makepkg(8)); now `makepkg -Cs`. Header comment corrected to match.
- `config/wlogout/layout` — wrong JSON schema (had a `{layout: [...]}`
  wrapper); now one JSON object per button per wlogout(5), keys
  `label`/`action`/`text`/`keybind`.
- `config/hypr/hyprland.conf` — `source =` lines that fed hyprpaper.conf /
  hypridle.conf into the compositor's parser (these daemons read their
  own configs, sourcing them into Hyprland would error or clobber the
  `general{}` block); now sourced as standalone daemons. The
  `keybinds-extra.conf` line used shell redirection
  (`source = ... 2>/dev/null || true`) that `source` can't take; now a
  plain `source =` against an empty installed file.
- `config/hypr/gpu-env.sh` — mixed-case `Mesa_*` env vars (Mesa silently
  ignores); now `MESA_*` all-caps per `docs.mesa3d.org/envvars.html`. The
  bogus `VK_ICD_FILENAMES_ALL_KNOWN=1` (not a real Khronos Vulkan loader
  var) was removed entirely. `MESA_GLSL_CACHE_DIR` (also not real) is now
  `MESA_SHADER_CACHE_DIR`.
- `config/rofi/config.rasi` — referenced `Papirus-Dark` icon theme;
  `papirus-icon-theme` now added to `scripts/00-base.sh`.
- `config/ghostty/config` — `command = /usr/bin/zsh` but `zsh` was never
  installed; now added to `scripts/00-base.sh`.
- `config/nvim/init.lua` — called `colorscheme pywal` after sourcing
  `colors.vim`. Both wrong: pywal16's actual file is `colors-wal.vim`
  (NOT `colors.vim`), and the template doesn't register a colorscheme at
  all — it only defines `color0..15` vim variables. Now sources the
  correct file and uses those variables to drive `nvim_set_hl` directly.
- `config/hypr/hypridle.conf` — listener referenced `$lock_cmd` as if
  it were a shell var; `lock_cmd` is an internal config keyword under
  `general{}` (per hypridle upstream `assets/example.conf`), not expanded
  in listeners. Now uses `loginctl lock-session` (the upstream-default
  listener action), which triggers the configured `lock_cmd` via logind.
- `scripts/00-base.sh` — listed `kvantum-qt6` which doesn't exist in
  Arch repos (the `kvantum` package IS the qt6 build per its
  description); would have killed `00-base.sh` under `set -euo pipefail`.
  Line removed.
- Theming pipeline — all GTK/rasi consumers imported
  `~/.cache/wal/colors.css`, which is web-CSS (`:root { --var }`) that
  GTK CSS's `@name` references can't resolve, so every themed component
  silently fell back to unstyled. waybar / swaync / wlogout / eww now
  `@import` the stock pywal16 `colors-waybar.css` (`@define-color` GTK
  syntax, no custom template needed); rofi now imports
  `colors-rofi.rasi` generated from a small custom user template shipped
  at `config/wal/templates/colors-rofi.rasi` (raw `@colorN` scheme — the
  stock `colors-rofi-dark.rasi` uses semantic names that don't match this
  rice's design and was deliberately not used).
- `scripts/00-base.sh` — `steam` was documented (window rules, Proton
  recipes, launch options) but never installed; added. `dunst` (unwired
  second notification daemon), `sway`, `swayidle`, `swaybg`, `wob`
  (nothing in a Hyprland rice references them) removed. Bare `pacman -Sy`
  before the install transaction (partial-upgrade anti-pattern) replaced
  with `pacman -Syu`. `zsh` swapped for `fish` (the shell actually used;
  ghostty's `command =` updated in lockstep).
- `scripts/10-aur.sh` — same bare `pacman -Sy` partial-upgrade
  anti-pattern in two places (local-repo registration and post-build
  install); replaced with a single `pacman -Syu --noconfirm` before the
  build loop (once per run — upgrading per package would repeat a full
  system upgrade for every AUR build).
- `config/hypr/gpu-env.sh` — `DRI_PRIME=1` was exported unconditionally,
  which on single-GPU boxes can point apps at a render node that doesn't
  exist; now only exported when `lspci` reports more than one GPU
  controller. Also fixed the detection itself: the greps matched
  `lspci -nn` output, but `-nn` inserts the class code between name and
  colon (`VGA compatible controller [0300]:`), so vendor detection and
  the GPU count never matched; now parses plain `lspci` output, captured
  once per shell start.
- `config/ghostty/config` — `padding-x` / `padding-y` are not real
  Ghostty options (only `window-padding-x` / `window-padding-y` exist per
  the option reference); dead lines removed.
- `scripts/30-dotfiles.sh` — the blanket `cp -a config/. ~/.config/`
  landed a stray `~/.config/applications/zed-handler.desktop` that
  nothing reads (the real copy goes to `~/.local/share/applications/`);
  the stray dir is now removed after the copy.

## Review pass 1 — governance docs and package-provenance audit

Scope: every claim in `AGENTS.md`, plus the two README tables it owns by
contract ("Source-built package inventory" and the moved-to-official
list), checked against the tracked tree and against live upstream state
(archlinux.org package API + AUR RPC, queried 2026-09-26). Part of an
11-pass repo audit; each pass gets its own section here.

Verified correct (no action):

- All ten `scripts/10-aur.sh` `PACKAGES=()` entries are genuinely
  AUR-only (absent from archlinux.org, present in AUR RPC): `eww`
  0.6.0-1, `python-pywal16` 1:3.8.15-1, `bibata-cursor-theme` 2.0.7-1,
  `wlogout` 1.2.2-0, `helium-browser-bin` 0.18.1.1-1 (the header's
  "reviewed 0.16.4.1-1" note is a dated review record, not a version
  pin — fine as written), `mpvpaper` 1.9-1,
  `vscode-langservers-extracted` 4.10.0-1, `chkrootkit` 0.59-1,
  `ox-bin` 0.7.7-1, `neomacs-bin` 0.0.19-1.
- The rest of the moved-to-official list verifies: `ghostty` 1.3.1-2,
  `swaync` 0.12.6-1, `cliphist` 0.7.0-2, `nwg-look` 1.1.1-3, `kvantum`
  and `kvantum-qt5` 1.1.8-1, `gamemode` 1.8.2-3, `gamescope` 3.16.30-1,
  `mangohud` and `lib32-mangohud` 0.8.4-1, and `zed` 1.21.0-1 — an
  exact version match with the 10-aur.sh header note and README.
- Lint claims match CI exactly for the `bash -n` file list, the g++
  `-fsyntax-only` keybind-menu check, and `lint-themes.sh` — and
  `lint-themes.sh` is indeed also invoked in `60-update.sh`'s lint
  gate, as the components map claims.
- The build-speed section matches `00-base.sh` (MAKEFLAGS, ccache in
  BUILDENV, `-march=native` CFLAGS/CXXFLAGS, RUSTFLAGS) and
  `10-aur.sh` (`setup_local_repo`, `SigLevel = Optional TrustAll`);
  the header's `makepkg -Cs` (no `-o`) note matches makepkg(8).
- Every "Components map" row points at files that exist, and the
  "50-verify.sh, 9 checks" tree annotation matches the script's nine
  `[n/9]` steps.

What was wrong (and the correct spec):

- `rofi-wayland` — no longer exists in official repos. rofi 2.0.0
  absorbed the Wayland fork upstream; Arch ships `extra/rofi 2.0.0-1`
  with `provides`/`replaces: rofi-wayland`
  (archlinux.org/packages/extra/x86_64/rofi/). `pacman -S rofi-wayland`
  in `00-base.sh` still resolves today via Arch's provides metadata and
  pacman's single-provider default under `--noconfirm`, but the install
  list, the README component row and moved-upstream list, AGENTS.md's
  no-compile list, and the 10-aur.sh header all cite a dead package
  name. Correct spec: install `rofi`. Same latent-breakage class as the
  `kvantum-qt6` entry above — the day the provides shim is dropped, the
  install dies under `set -euo pipefail`.
- `swww` — renamed upstream to `awww`; Arch ships `extra/awww
  0.12.1-1` with `provides`/`replaces: swww`
  (archlinux.org/packages/extra/x86_64/awww/). No package named `swww`
  exists in official repos. Same five stale citations as rofi-wayland;
  correct spec: install `awww` (upstream's binaries are `awww` /
  `awww-daemon`). Noted for the config pass: nothing under `config/`
  references the daemon by either name, so the package may be vestigial
  since mpvpaper became the animated-wallpaper default.
- `python-pywal` — AGENTS.md's "remain in the normal distribution
  install set" list and 10-aur.sh's "(installed by 00-base.sh, NOT
  here)" header both frame it as available in official repos. It is not
  in any official repo: archlinux.org search returns zero matches
  (dropped from extra entirely; only the maintained `python-pywal16`
  fork survives, on AUR). Documentation-only severity — nothing
  installs it — but the stated reason it isn't built ("now in official
  repos") is false.
- README "Source-built package inventory" — missing `chkrootkit`,
  which `10-aur.sh` audits and builds. The commit/PR style rule says
  this table is the rule-5 contract and must track the AUR set: the
  script carries 10 packages, the table lists 9.
- README structure — the bullet "`gamemode`, `gamescope`, `mangohud`,
  `lib32-mangohud` — in `extra` + `multilib`" is detached from the
  moved-to-official list it belongs to and sits orphaned inside the
  "### Keybind customization" section.
- `sudoedit` fallback — documented as `sudoedit -e nano /path/to/file`
  (AGENTS.md, README; hyprland.conf's comment has the `sudoedit -f -e
  nano` variant). Not a valid invocation: sudo(8) 1.9.17 defines
  `-e, --edit` as "edit one or more files" (implied by sudoedit); its
  operands are files, and the editor comes from `SUDO_EDITOR`,
  `VISUAL`, `EDITOR` in that order. `sudoedit -e nano <file>` would
  create/edit a root-owned file literally named `nano`. The README's
  second form, `SUDO_EDITOR=nano sudoedit <file>`, is correct; AGENTS.md
  and the hyprland.conf comment should say that or `sudo nano <file>`.
- AGENTS.md layout tree — omits four tracked paths: root `LICENSE`,
  root `postgres-language-server.jsonc` (the components map does
  reference this one), `config/wal/templates/colors-neomutt.muttrc`,
  and `config/systemd/user/vdirsyncer-google.{service,timer}`.
- AGENTS.md lint/verify section — lags lint.yml: it documents 5
  checks, but CI runs 8 jobs. Undocumented here: shellcheck (error
  severity), jq coverage of `config/zed/settings.json` +
  `config/zed/keymap.json` + `postgres-language-server.jsonc` (only
  swaync + wlogout are listed), emacs byte-compile of init.el and the
  preset `colors.el` files, the luajit parse of `init.lua`, and the
  eight-format preset-presence matrix.

## Review pass 1 — package provenance & security audit

Scope: `scripts/00-base.sh`, `scripts/10-aur.sh`, and AGENTS.md's
source-build table. Checks: every AUR-only package in `10-aur.sh` has a
documented reason in the AGENTS.md table; every claim in that table
re-verified against live upstream state; no `curl | bash` pattern
anywhere in the tree; and every package name `00-base.sh` installs
re-checked for existence or renames against the official package API.
All upstream state was queried live on 2026-09-26 (archlinux.org
package API, AUR RPC, and shallow clones of the six AUR PKGBUILDs the
docs describe in depth). Part of an 11-pass repo audit; each pass gets
its own section here. Findings are documented without fixes.

Note on overlap: the governance pass directly above (merged as PR #23
on 2026-09-26) already logged `rofi-wayland` / `swww`
living on as provides-shims of `rofi` / `awww`, the `python-pywal`
framing error, README's missing `chkrootkit` row, and the orphaned
`gamemode` bullet under Keybind customization. Those were re-verified
here (still accurate as of today) and are cross-referenced, not
re-litigated.

Verified correct (no action):

- All ten `10-aur.sh` `PACKAGES=()` entries are present in AGENTS.md's
  source-build table with substantive provenance notes, and vice versa
  — 1:1, no undocumented builds, no orphan table rows.
- All ten are still AUR-only (none have entered official repos) and at
  documented versions: `eww` 0.6.0-1, `python-pywal16` 1:3.8.15-1,
  `bibata-cursor-theme` 2.0.7-1, `wlogout` 1.2.2-0, `helium-browser-bin`
  0.18.1.1-1, `mpvpaper` 1.9-1, `vscode-langservers-extracted`
  4.10.0-1, `chkrootkit` 0.59-1, `ox-bin` 0.7.7-1, `neomacs-bin`
  0.0.19-1. The "Verified on AUR 2026-09-25" stamps on ox-bin /
  neomacs-bin are still exact.
- The three in-depth PKGBUILD descriptions still match the live
  AUR clones: `helium-browser-bin` pins the imputnet release tarball
  with its `.asc` checked via `validpgpkeys` (Helium signing key
  `BE677C19...D6378E`), two sha256-pinned local patches, the
  ungoogled-chromium license, no `build()`, no hooks, /opt layout +
  `/usr/bin/helium-browser` wrapper symlink; `mpvpaper` pins the GhostNaN
  release tarball with a b2sum, meson/ninja, `libmpv.so` + wayland deps,
  socat optdep; `vscode-langservers-extracted` pulls the single
  sha256-pinned npm registry tarball with the cache confined to
  `$srcdir`, no `build()`, no hooks. `neomacs-bin` pins a sha256sum on
  the eval-exec/neomacs release tarball; `ox-bin` is maintained by
  `curlpipe` (the upstream Ox author) as documented.
- No `curl | bash` / `wget | sh` / process-substitution-into-shell
  / eval-of-download pattern is executed anywhere in the tracked tree
  (scripts, config, `.github/workflows/lint.yml` included). Every
  textual match of the pattern is policy prose or the detector regexes
  inside `10-aur.sh`'s own `scan_pkgbuild()`.
- The ~120 other package names across `00-base.sh`'s transactions (main
  list, LSP step, both GPU stacks, `cpupower`, `ccache`, `emacs-wayland`
  31.1-2), plus `20-sddm.sh`'s qt6 set, `40-gaming.sh`'s gaming set,
  `45-snapshots.sh`'s snapper/timeshift/cronie, and `install-zed.sh`'s
  `zed` 1.21.0-1, all resolve to current core/extra/multilib packages —
  including last-pass additions `tmux` 3.7_c-1 and `lazygit` 0.65.1-1.
  No further misses beyond the ones below.

What was wrong (and the correct spec):

- `mesa-vdpau` in `00-base.sh`'s Intel/AMD GPU stack (step [6/9]) —
  **installation aborts on a fresh Intel/AMD run**. No package by that
  name exists in any official repo and nothing provides it: `mesa`
  26.2.3-1's provides list is exactly `libva-driver`,
  `libva-mesa-driver=1:26.2.3-1`, `mesa-libgl`, `opengl-driver`, and a
  repo-wide `vdpau` search returns only `libvdpau`, `libvdpau-va-gl`,
  `vdpauinfo` (client-side bits). `pacman -S ... mesa-vdpau` errors
  with `target not found: mesa-vdpau` and the whole transaction dies
  under `set -euo pipefail` — on the *default* GPU path, present since
  the initial GPU-agnostic commit. Correct spec: drop the entry
  (upstream Mesa no longer ships a VDPAU frontend as an Arch package;
  Intel/AMD hardware acceleration comes from the VA-API driver inside
  `mesa` itself).
- `nvidia` in the same step's NVIDIA branch — **installation aborts on
  a fresh NVIDIA run**. Arch's proprietary kernel-module package is
  gone; the shipped family is `nvidia-open` 615.71.09-4 (and
  `nvidia-open-lts` for linux-lts), with `nvidia-utils` /
  `lib32-nvidia-utils` 615.71.09-1 still current. `nvidia-open`
  **conflicts** `nvidia` and provides only `NVIDIA-MODULE`, so there is
  no provider shim: `pacman -S nvidia` fails outright. Same class for
  `nvidia-dkms`, also gone — and README's NVIDIA gotchas still
  recommend it for non-stock kernels (`README.md` "GPU compatibility"
  lines naming `nvidia` / `nvidia-dkms` all need the same correction;
  the `nvidia_drm.modeset=1 fbdev=1` kernel-cmdline guidance itself is
  unaffected by the rename). Correct spec: `pacman -S nvidia-open
  nvidia-utils lib32-nvidia-utils` on the stock `linux` kernel.
- `NetworkManager` in step [3/9]'s main transaction — **installation
  aborts on every fresh run, both GPU branches**. The canonical package
  is `networkmanager` (extra/1.58.1-1). Arch package names are
  case-sensitive for target resolution (the archweb `name=` exact
  filter returns zero hits for `NetworkManager`, and libalpm resolves
  `-S` targets by exact-name lookup): `pacman -S NetworkManager` errors
  `target not found` and the primary install transaction dies under
  `set -euo pipefail`. Mis-cased since the first rice commit — the same
  memory-vs-verified trap as `kvantum-qt6` above. Correct spec:
  `networkmanager`.
- `libva-mesa-driver` in the Intel/AMD stack — latent shim, dead name.
  Absorbed into `mesa` at 1:24.2.7-1 (2024): `mesa` now provides
  `libva-mesa-driver=1:26.2.3-1`, so pacman's single-provider default
  still installs it today (redundantly — `mesa` is in the same
  transaction line). Same latent-breakage class as #23's
  `rofi-wayland`/`swww`: the day the versioned provide is dropped, this
  transaction dies. Correct spec: drop the entry; `mesa` covers it.
- `ox-bin` integrity framing — **provenance finding**. Its PKGBUILD
  carries `sha256sums=("SKIP")`: the prebuilt binary fetched straight
  from `github.com/curlpipe/ox/releases` is never integrity-pinned —
  HTTPS plus PKGBUILD review is the whole check. AGENTS.md's and
  `10-aur.sh`'s "review the source URLs and checksums" note is not
  actionable as written, because there is no checksum. Softening
  factors: the AUR maintainer is the upstream Ox author, and nothing
  else in the AUR set ships checksumless. Decision needed at fix time:
  accept and document the checksumless `-bin`, or switch to a
  source-built `ox`/`ox-git`. (`neomacs-bin`, the other prebuilt, does
  pin a sha256 — and it remains a 1-vote package last touched
  2026-09-20; keep the heightened review posture it already documents.)
- `bibata-cursor-theme` "Has install hooks; review before approving" —
  stale claim. The live 2.0.7-1 package has no `.install` scriptlet at
  all (PKGBUILD + `.SRCINFO` verified); it is now a `python-clickgen`
  source build with no post-install actions. Review-before-approving
  stays right regardless, but the documented reason is wrong.
- Stale version pins in `00-base.sh`'s LSP header comment (dated-record
  severity): `pyright` 1.1.411 → 1.1.412-1, `rust-analyzer` 20260608 →
  20260907-1, `typescript-language-server` 5.1.3 → 6.0.0-1 (a major
  bump), and the Emacs step's "same 30.2 source" now points at
  `emacs-wayland` 31.1-2. Minor drift: the step banners mix `[1/8]`,
  `[2/8]` with `[3/9]`..`[9/9]`, and step [8/9]'s prose still says
  "step [4/8]".

## Review pass 2 — install/update/rollback script logic

Scope: `scripts/00-base.sh` → `scripts/45-snapshots.sh`,
`scripts/60-update.sh`, `scripts/61-rollback.sh`, and
`scripts/lib/rice-version.sh`. Checks: idempotency (safe to re-run),
error handling (`set -euo pipefail` present and honored, no silent
failures), and whether `60-update.sh`'s phase-5 lint gate covers
everything `.github/workflows/lint.yml` checks (the components-map
convention). Live upstream state re-verified 2026-09-26 where noted.
Part of an 11-pass repo audit; each pass gets its own section here.
Findings are documented without fixes.

Note on overlap: pass 1 (both halves) already logged the stale package
names `00-base.sh` installs (`mesa-vdpau`, `nvidia`, `NetworkManager`,
`rofi-wayland`, `swww`). Those are not re-litigated here; this pass is
about script *logic*, not package provenance. The package-provenance
half also logs the `00-base.sh` step-banner numbering drift (and adds
the stale "step [4/8]" prose reference) — the banner bullet below is
kept only for the additional "intialized" typo and the BUILDENV
whole-line-replacement note.

Verified correct (no action):

- Every script in scope carries `set -euo pipefail` and refuses
  EUID 0 before any mutation, and every externally-visible failure
  mode (offline fetch, non-ff history, snapshot-tool missing/failed,
  lint-gate break, phase/gate failure) exits with the documented code
  rather than dying silently inside a half-finished pipeline.
- Re-run idempotency holds on the stateful steps: multilib + its
  Include are gated on grep/awk probes; ccache-in-BUILDENV is verified
  *after* the edit with a fail-closed abort; PostgreSQL initdb is
  gated on `PG_VERSION` and role/db creation on `pg_roles` /
  `pg_database` existence; MariaDB is gated on the datadir and uses
  `CREATE ... IF NOT EXISTS`; every `systemctl enable --now` is
  naturally idempotent; 20-sddm.sh's snapshots are timestamped-unique
  under /root; 30-dotfiles.sh's backups are fresh timestamped dirs and
  the msmtp/isync/neomutt example-copies never overwrite a
  personalized file; 45-snapshots.sh's snapper branch gates on
  `list-configs` and re-applies `set-config` harmlessly, and its
  timeshift branch rewrites config through timeshift's own CLI.
- Gate-list audit (the pass's central question): the phase-5 gate
  covers lint.yml's `bash -n` file list **exactly** (both
  `scripts/*.sh` + `scripts/lib/*.sh` globs and all eleven named
  config scripts), the jq set **exactly** (the four `//`-prefixed
  JSONs plus wlogout's layout with `-s`), the g++ `-Werror
  -fsyntax-only` keybind-menu check, and `lint-themes.sh` — whose
  steps [1/3] and [3/3] subsume lint.yml's separate "theme presets
  carry every pywal format" step (same eight-format presence loop,
  same switch-theme.sh copy-list comparison, plus the deeper hex-sync
  check lint.yml runs anyway). No drift hides behind the subsumption.
- `scripts/lib/rice-version.sh`: the `=`-in-value invariant holds
  (write path replaces the whole record via `$0=k"="v`; read path
  strips only the first `KEY=` prefix); env files are touched 0600,
  rewritten via temp+mv, and `rollback.env`'s identity fields are
  `:?`-guarded at source time in 61-rollback.sh.
- `rice_git_restore`'s four-way restore (named checkout / retract own
  ff-advance / detach when someone else moved the branch / detach when
  the branch is gone) never force-resets a ref it doesn't own —
  matches its header comment and the update contract.
- 60-update.sh's pipeline ordering is sound: the rollback ticket is
  written *before* the checkout advances, the snapshot is taken before
  anything mutates, "already up to date" exits before the snapshot,
  the dry-run path writes nothing (including skipping the lock), and
  the self-reexec guards in both 60 and 61 handle the script being
  rewritten mid-parse.

What was wrong (and the correct spec):

- `scripts/20-sddm.sh` metadata edit — **stale against current
  upstream, and now points the greeter at nothing**. The sed rewrites
  `ConfigFile=` to ` astronaut.conf` — a bare basename (with a stray
  leading space) — but upstream sddm-astronaut-theme master (verified
  2026-09-26: metadata v1.4, Theme-API=2.0) ships
  `ConfigFile=Themes/astronaut.conf`; the palettes moved under
  `Themes/*.conf`. The rewritten value resolves to a file that does
  not exist in the clone, so on today's theme the "select astronaut"
  step actively breaks what it claims to select (greeter falls back
  to built-in defaults or mis-renders — exactly what the rollback
  snapshot is for). Correct spec: write
  `ConfigFile=Themes/astronaut.conf` — or drop the sed entirely
  (upstream already defaults to astronaut) — and strengthen the
  `Name=`-only "seems incomplete" guard into "the resolved ConfigFile
  path must exist in the clone".
- `scripts/60-update.sh` phase-5 gate — **the gate's header comment
  misdescribes the three CI checks it omits**. shellcheck (error
  severity), emacs byte-compile, and the luajit parse of init.lua
  never run locally — not even conditionally — yet the comment says
  "it fails here too IF and ONLY IF the tool is present". A tree that
  breaks any of those three passes the update gate and fails CI after
  the push. Correct spec: either implement what the comment describes
  (`command -v`-guarded shellcheck / emacs / luajit runs) or rewrite
  the comment to say the three are CI-only by policy. Secondary
  asymmetry in the same gate: the `bash -n` loop skips vanished files
  (`[[ -e $f ]] || continue`) but the jq loop doesn't, so an update
  that removes one of the four JSON files fails its own gate. Both
  loops should behave the same, or the comment should say why the
  JSON set is treated as non-optional.
- `scripts/00-base.sh` pg_hba fail-closed check — **one-shot only,
  and can pass vacuously**. (a) The check greps
  `<(sudo cat "$HBA")`; if the cat itself fails, grep sees empty
  input, finds no `host all all` row, and the refuse-to-continue
  branch never fires — fail-open inside a fail-closed block.
  (b) Worse: the check runs only on the fresh-cluster path. Any
  first-run abort after initdb (sed no-op on a changed stock file,
  user Ctrl-C, power cut) leaves the cluster initialized; every
  re-run then takes the "cluster already intialized, leaving it ...
  alone" branch and `enable --now postgresql.service` with pg_hba
  never validated — carrying the exact wide-open
  `host all all ... trust` rows the first run refused to start with.
  Correct spec: move the fail-closed check in front of the
  `enable --now` so it runs on every path (not just fresh initdb),
  and read the file with `sudo grep -Eq ... "$HBA"` directly so the
  reader's exit status propagates to the check.
- `scripts/61-rollback.sh` config restore — **completeness silently
  depends on rsync, which nothing on the btrfs path installs**.
  Restore uses `rsync -a --delete` when rsync exists, else `cp -a`
  without --delete, so files the failed update *added* to ~/.config
  survive the rollback. `rsync` is absent from 00-base.sh's package
  list; it reaches a machine only as a hard dependency of timeshift
  (verified: extra/timeshift 26.09.0-1 depends on rsync) on
  45-snapshots.sh's non-btrfs branch. On a btrfs/snapper box, the
  recovery path that defines itself as "the pre-update state" is only
  exactly that on machines that happen to have rsync. Correct spec:
  add rsync to 00-base.sh's core list (it also underpins timeshift),
  or make the fallback delete-then-copy.
- `scripts/60-update.sh` line-331 / `61-rollback.sh` line-69 —
  **the failed-phase path can die before rollback starts**. Both
  `VAR=$(ls -1dt "$HOME"/.config-backup-* 2>/dev/null | head -n 1)`
  fallbacks sit on the right of `||` unguarded: when no backup dir
  matches (state recorded by a pre-update-system deploy, or the user
  cleaned `~/.config-backup-*` while deployed.env/rollback.env
  survive), `ls` fails, pipefail propagates, and `set -e` kills the
  updater *after* the failed phase but *before* 61 runs — and kills
  61 mid-rollback in the standalone case. Contrived state, but it
  sits precisely on the recovery path. Correct spec: append `|| true`
  (the empty-string fallback below already handles the empty result).
- `scripts/30-dotfiles.sh` — **unguarded late steps can strand a
  deploy before it is recorded**. `wal -i` runs with no
  `command -v wal` guard: decline python-pywal16 at 10-aur's review,
  later drop `wallpaper.jpg` in place (README's own post-install
  step), and every 30 run dies under `set -e` after configs are
  copied but before `rice_env_write_deployed` — deployed.env keeps
  pointing at the old commit and 50-verify's drift check then
  false-fails a correct state. Inside 60-update it escalates: phase
  30 fails → automatic rollback re-runs 30 → wal fails again → the
  rollback itself reports NOT clean (exit 3). A declined AUR package
  plus a wallpaper wedges the whole update/rollback loop. Same class,
  lower likelihood: the unconditional `chmod 600` on
  `msmtp/config` + `isync/mbsyncrc` dies the same way if neither a
  personalized copy nor the in-repo `.example` exists (both examples
  exist today — robustness gap, not a live bug). Correct spec:
  `command -v wal`-guard the palette generation (the no-wallpaper
  branch already degrades gracefully through switch-theme.sh, which
  needs no wal binary), and guard the chmod with file-existence.
- `scripts/10-aur.sh` build_one — **message/behavior mismatch on
  failure**. "No .pkg.tar.zst produced; something went wrong.
  *Skipping* install." is followed by `return 1`, and under `set -e`
  the caller aborts the whole run: nothing is skipped, the remaining
  queue never runs, and the end-of-run `SKIPPED_PACKAGES` summary
  omits the failed package entirely (it only tracks user-declined
  builds). A maintainer force-push to an AUR repo kills the run the
  same way via `git pull --ff-only`. Loud abort is a defensible
  policy; the messaging and the final summary must match what
  actually happens — and per-package containment (record FAILED
  alongside SKIPPED, keep going) would make the reviewed queue
  restartable without re-reviewing the packages that already built.
- `scripts/00-base.sh` makepkg.conf edits — **unverified success
  messages**. The MAKEFLAGS sed matches the stock `#MAKEFLAGS="-j2"`
  line exactly and the CFLAGS/CXXFLAGS sed matches stock
  `-march=x86-64 -mtune=generic` exactly; the day upstream
  makepkg.conf drifts, the seds no-op while the script prints
  "MAKEFLAGS set to -j$(nproc)" / "retargeted to -march=native"
  anyway — and reprints the false success on every re-run. The ccache
  block immediately below demonstrates the verify-after pattern
  (grep for `!ccache` → loud ERROR, exit 1); these two edits should
  follow it.
- Minor, one line each:
  - `60-update.sh --branch` validation accepts leading `-`
    (`--branch --detach` passes `^[A-Za-z0-9._/-]+$`; leading-dash
    refnames are valid per `git check-ref-format` — verified — so if
    such a branch ever existed on origin, `git checkout "$BRANCH"`
    would parse it as an option). Reject `-*` explicitly. Low
    severity: requires a deliberately-pushed odd branch on the user's
    own origin.
  - `20-sddm.sh`: an existing `10-theme.conf` with no `^Current=`
    line no-ops the sed while the script still reports the theme
    selected — the missing-metadata case is fatal, this one is
    silent. Check the key landed, like the ccache verify does.
  - `00-base.sh`: banner numbering drift — `[1/8]`, `[2/8]`, then
    `[3/9]`–`[9/9]` (also in pass 1's package-provenance section,
    with the stale "step [4/8]" prose reference). Typo "intialized"
    in the pg-cluster-exists branch. The BUILDENV whole-line
    replacement discards pre-existing custom tokens without notice.
  - `45-snapshots.sh` timeshift branch: `findmnt -o SOURCE /` feeds
    straight into `--snapshot-device`; on LUKS/LVM roots that's a
    `/dev/mapper/*` path timeshift's CLI may reject. Fails loudly
    under `set -e` (acceptable) — recorded for the troubleshooting
    docs.
  - `40-gaming.sh`'s recipe heredoc references `prismlauncher`, which
    no script in the rice installs.
  - `61-rollback.sh`'s step 3 re-runs 30-dotfiles.sh, whose ClamAV
    timer / vdirsyncer prompts stay interactive inside an
    "automatic" rollback — foreground-safe, but worth a note in the
    header.

## Review pass 3 — 50-verify.sh completeness

Scope: `scripts/50-verify.sh` cross-referenced against everything the
rice actually installs or enables: `00-base.sh`'s package sets and
`systemctl enable` calls, `10-aur.sh`'s build list, `20-sddm.sh`,
`30-dotfiles.sh`'s user timers, `40-gaming.sh`, `45-snapshots.sh`,
`hyprland.conf`'s exec-once set, and `config/systemd/user/*`. Check:
every major subsystem has a corresponding verify check, and any
installed component with NO verify coverage is flagged. Part of an
11-pass repo audit; each pass gets its own section here. Findings are
documented without fixes — the script itself is untouched.

Verified correct (no action):

- Four of the six headline subsystems have real coverage. GPU is
  checked as install-state cross-referenced with hardware ([2/9]:
  `lspci` vendor matched against `pacman -Qi nvidia`/`mesa`, with
  NVIDIA-hardware-plus-mesa correctly a PASS since 00-base.sh lets
  the user decline the proprietary driver). Firewall [3/9] tests both
  halves — the systemd unit AND `ufw status`, the two failure modes
  that look fine alone. Snapshots [8/9] mirror 45-snapshots.sh's
  btrfs/snapper vs other/Timeshift branch with the same `findmnt`
  call, so verify can never disagree with install about which path
  was taken. Bluetooth [5/9] is covered.
- `50-verify.sh`'s "never fixes" contract holds: every check is
  read-only (grep/systemctl is-active/pacman -Qi/findmnt/compgen via
  `sudo -n`, git rev-parse); nothing mutates.
- [9/9]'s drift check reads the same `RICE_COMMIT=`/`RICE_BRANCH=`
  keys `rice_env_write_deployed` writes in
  `scripts/lib/rice-version.sh`, and its "checkout moved" report
  matches the update contract exactly.
- [1/9]'s monitor/wallpaper logic matches the monitor contract:
  wildcard and explicit layouts both PASS, and only a missing
  `monitor=`/`wallpaper=` line fails — which there is
  exactly the broken-config state the check exists to catch.
- The script's own header is honest about its scope, including that
  [7/9] runs against the repo checkout by design.

What was wrong (and the correct spec):

- **Network — an entire headline subsystem with zero verify
  coverage.** `NetworkManager` is in 00-base.sh's main transaction
  and the README's archinstall step selects "Network:
  NetworkManager", so the service is enabled by archinstall on the
  documented install path — no rice script ever enables it and no
  verify check ever asks about it: no `NetworkManager.service` state,
  no connectivity probe. Compounding: pass 1's provenance section
  logs that the mis-cased `NetworkManager` package name hard-fails
  00-base.sh's step-[3/9] transaction on a fresh install — meaning
  the network stack (and everything after it) never lands, and a
  verify run that checks nothing about networking still reports its
  other checks as green. Correct spec: at minimum
  `systemctl is-enabled`/`is-active NetworkManager.service` (both
  read without root), reported as a state check.
- **SDDM — the check labeled "SDDM" never checks the display
  manager.** [6/9] verifies only that a rollback snapshot exists
  under /root; nothing checks that `sddm.service` is enabled
  (20-sddm.sh's step [5/5]) or that the theme the conf.d drop-in
  points at resolves. With pass 2's `ConfigFile=` finding (the sed
  writes ` astronaut.conf`, a path absent from upstream's current
  `Themes/*.conf` layout), a fresh install can boot to a black
  greeter while verify's only SDDM line says PASS — the exact
  failure mode the whole rollback contract exists for. Compounded
  by the sudo gate: without passwordless sudo, [6/9] degrades to an
  uncounted SKIP, so the default invocation has zero EFFECTIVE SDDM
  coverage at all. Correct spec: `systemctl is-enabled sddm.service`
  (no sudo needed), plus existence of the theme dir and of the
  resolved `ConfigFile` path in the clone; keep the /root snapshot
  probe as the sudo-gated extra it already is.
- **Audio — pipewire + wireplumber installed, never verified.**
  00-base.sh installs both (main transaction); they run as user
  units (`pipewire.socket`, `wireplumber.service`), so a dead audio
  stack passes verify silently. Checkable without root via
  `systemctl --user is-active wireplumber.service pipewire.socket`.
- **gamemoded — never verified.** 40-gaming.sh's own header says the
  script "is mostly about wiring them up, not just installing them"
  — the wiring is the `gamemoded.service` user-unit enable, which is
  precisely the thing verify never re-checks. Correct spec:
  `systemctl --user is-enabled gamemoded.service`.
- **cpupower.service — unconditionally enabled, never verified.**
  Coverage auditing is what surfaces that it is enabled at all:
  00-base.sh's step [7/9] header says "Optional" and the README's
  step-1 comment promises a governor prompt that "defaults to no",
  but the block contains no `read -p` — cpupower is installed, the
  governor written, and the service enabled on every run. (The
  doc/behavior mismatch belongs to pass 2's script-logic window;
  recorded here only as the reason this squares as an
  installed-and-enabled component with no verify line.) Correct
  spec: `systemctl is-active cpupower.service` plus
  `cpupower frequency-info` governor readback.
- **postgresql.service / mysqld.service — never verified.**
  00-base.sh's step [9/9] enables both when accepted, and its
  prompts default to yes — so a default-yes install leaves two
  listening database daemons verify never probes (`is-active`, or
  `pg_isready` / `mariadb-admin ping` for a live answer). Pass 2
  already logged that the pg_hba fail-closed validation runs only on
  the fresh-initdb path; verify is the natural home for a repeated
  readback of that scoping, and it has none.
- **AV coverage stops at freshclam.** [4/9] checks the signature
  updater and never the scan side: the daily `clamav-scan.timer`
  that 30-dotfiles.sh offers to enable has no check — a dead timer
  or a scan-targets.sh that fails nightly stays invisible.
  `chkrootkit` is manual-run by design (README), so its absence is
  defensible; recorded for completeness. Correct spec for the timer:
  `systemctl --user is-active clamav-scan.timer`, reported as state
  (the user may have declined — that's a report, not a FAIL).
- **Theming coverage is repo-side only; the deployed system is
  never asked.** [7/9] audits the repo checkout's presets and
  switch-theme.sh's cp list (documented in the header as by design),
  but switch-theme.sh copies from `$SCRIPT_DIR/themes` — the
  DEPLOYED `~/.config/hypr/themes/` tree — which verify never
  audits: a corrupted or partially-deployed preset set is invisible,
  and [9/9]'s drift check catches only a moved checkout, not damaged
  payloads at the same commit. Nothing checks the live palette
  either: `~/.cache/wal` populated, `current-theme` recorded, or the
  `~/.config/zed/themes/pywal.json` symlink 30-dotfiles.sh creates.
  And while [1/9] requires an uncommented `wallpaper=` line in
  hyprpaper.conf — the STATIC FALLBACK's config — the default
  wallpaper path per hyprland.conf's exec-once is mpvpaper, whose
  binary presence and `wallpaper.mp4` TODO get no check at all.
- **The README overstates verify's coverage.** Line 447's install
  block says 50-verify reports "first-boot TODOs cleared" — no such
  check exists. Nothing probes the first-boot TODOs section's items:
  `wallpaper.jpg` presence, NVIDIA's `nvidia_drm.modeset=1
  nvidia_drm.fbdev=1` on /proc/cmdline (a skipped cmdline means a
  broken session WITH a green [2/9] GPU check), or AppArmor's `lsm=`
  line (the TODO tells the user to check
  `/sys/kernel/security/lsm` by hand; verify doesn't). AppArmor
  being inert until a hand-edited cmdline is deliberate and fine;
  the finding is the README promising a TODO-cleared check that
  isn't implemented. Correct spec: either add the three read-only
  probes (each is one grep) or reword line 447.

Minor, one line each:

- [4/9]'s banner reads "clamav-freshclam" but the section also
  carries the Neomutt signing-placeholder check — the mail stack's
  only verify presence hides under the AV banner, so an audit of
  "is mail covered?" reads as a no when it's a yes.
- hyprland.conf's exec-once services (waybar, swaync, hypridle, both
  xdg-desktop-portals, cliphist, eww) have no probe; 60-update.sh's
  gate already runs `hyprctl configerrors` in-session, but
  standalone 50-verify.sh never asks hyprctl anything, so outside
  the update pipeline no check touches the live compositor.
- `rice-update-check.timer` — notify-only, deliberately never
  auto-enabled (README has the manual enable line), so its absence
  from verify is defensible; listed so the coverage table is
  complete. (Its `[[ -d $RICE_REPO/.git ]]` check failing on
  worktrees is already a logged update-system follow-up — not
  re-litigated.)
- `vdirsyncer-google.timer` — enabled only when the user wires the
  OAuth config; same "report state, don't FAIL" category as the
  ClamAV timer.
- The build pipeline (makepkg.conf's MAKEFLAGS/ccache/`-march=native`
  edits, `[localrepo]` registration) has no post-hoc readback in
  verify — pass 2 logged that the first two seds can no-op silently
  while printing success, and verify is where that readback would
  live. Defensible as install-time-only; noted for the record.
- The header says "Run AFTER 00–40 have completed", but [8/9]
  verifies 45-snapshots.sh's branch — the banner's range predates
  the snapshot script's slot. One-word fix when the script is next
  touched.

## Review pass 4 — Hyprland core config vs. upstream docs

Scope: `config/hypr/hyprland.conf`, `hypridle.conf`, `hyprpaper.conf`,
`keybinds-extra.conf`, `gpu-env.sh`, `switch-theme.sh`,
`start-mpvpaper.sh` — every directive, bind flag, window-rule effect,
env var, and daemon keyword re-checked against the current upstream
wikis (Hyprland, hypridle, hyprpaper) and elFarto/nvidia-vaapi-driver's
README. This is a re-run of the audit that originally caught the
`Mesa_*` casing, hypridle `lock_cmd`-in-listener, and
hyprpaper-into-Hyprland `source=` bugs; per the brief, lines added
since that pass (the keybind-variable apparatus, xdg-mime exec-onces,
mpvpaper-by-default, the wlogout/calculator float rules, the wal border
sourcing) got the same first-principles treatment. Findings are
documented without fixes — no config file was touched.

Documentation baseline, stated once: the wiki is now versioned and its
default view tracks latest git; release snapshots exist per tag. As of
this pass Arch ships `hyprland 0.56.2-3` (built 2026-09-04), and since
Hyprland 0.55 hyprlang is deprecated in favour of a Lua config API:
every current page (including the frozen v0.56.0 snapshot) leads with
"Since Hyprland 0.55, hyprlang is deprecated in favor of lua" and
documents only the `hl.*` forms. hyprlang still parses on the release
channel (Arch's 0.56.2-3 links libhyprlang; the 0.55 changelog carries
active `config/legacy` fixes), so nothing below is argued from the
syntax flip alone: where a construct is absent from BOTH the 0.54 (last
hyprlang-documented) and 0.56 pages, it is dead today, not merely
deprecated.

Verified correct (no action):

- hypridle.conf, every key: `lock_cmd`, `before_sleep_cmd`,
  `after_sleep_cmd` are the documented `general{}` keys and
  `on-timeout = loginctl lock-session` is upstream's own example for
  the lock listener; the file's comment about listeners not expanding
  `$lock_cmd` matches upstream's description. Upstream has since added
  only optional keys (unlock_cmd, on_lock_cmd/on_unlock_cmd,
  inhibit_sleep, per-listener ignore_inhibit/condition_cmd) — nothing
  required is missing.
- Every env var NAME in hyprland.conf matches the current
  Environment-variables page, including `QT_QPA_PLATFORM = wayland;xcb`
  (the `;xcb` fallback is still the documented form). `qt6ct` is fine —
  the page documents QT_QPA_PLATFORMTHEME with qt5ct as its example;
  the variable is what matters.
- gpu-env.sh in full: the multi-GPU-gated DRI_PRIME, the `__GL_*`
  trio, per-vendor VDPAU_DRIVER/LIBVA_DRIVER_NAME, and the
  MESA_SHADER_CACHE_DIR/MAX_SIZE pair fixed in the earlier pass are all
  still real. Notably, the current Nvidia page's ENTIRE remaining env
  recommendation is `LIBVA_DRIVER_NAME=nvidia` +
  `__GLX_VENDOR_LIBRARY_NAME=nvidia` — exactly what gpu-env.sh sets on
  that vendor.
- The binds' dispatcher vocabulary matches the last hyprlang docs
  (v0.54.0 Dispatchers, quoted): killactive, exit, fullscreen,
  togglefloating, movefocus/movewindow with l/r/u/d, movetoworkspace,
  workspace N and e±1, and resizeactive taking a "relative pixel delta
  vec2 (e.g. 10 -10)" — so the rice's `-20 0` is a correct delta on the
  channel the file speaks. pseudo/togglesplit are layout-owned
  dispatchers the main page defers to the dwindle page. `dpms on|off`
  is fired from hypridle, not a keybind, which is exactly the case the
  page's "Do not use with a keybind directly" carves out.
- Bind machinery on the legacy layer: binde/bindl/bindel/bindm
  suffixes, mouse:272/273, XF86 keysyms, the `code:33` comment example,
  `$variable` substitution in bind lines, and stacked modifiers all
  still parse on 0.56 (libhyprlang linked, config/legacy maintained).
- keybinds-extra.conf's allocation comments check out:
  `$key_calendar` and `$key_lapce` share G under different modifiers
  (SUPER+SHIFT vs SUPER, no collision), and the listed free
  SUPER+SHIFT letters (B, P, V, W, Y, Z) match the live bind map.
- The earlier fixes hold: the comment that hyprlang's `source` cannot
  take shell redirection is accurate, hypridle/hyprpaper configs are
  still correctly NOT sourced into hyprland.conf, and the wal template
  `colors-hyprland.conf` later-assignment-wins border override is
  legitimate for the hyprlang channel. switch-theme.sh and
  start-mpvpaper.sh carry no Hyprland config directives (hyprctl CLI
  only); nothing to flag against the docs.

What was wrong (and the correct spec):

- **hyprpaper.conf is dead against current hyprpaper — the daemon exits
  before showing anything.** Upstream's ConfigManager registers only
  `splash`/`splash_offset`/`splash_opacity`/`ipc` plus a special
  category `wallpaper { monitor, path, fit_mode, timeout, order,
  recursive }`, parses with `throwAllErrors = true`, and main.cpp is
  `if (!g_config->init()) return 1;`. The rice's `preload = ...`
  keyword is not registered at all, and `wallpaper = , path` (flat
  assignment) is not either — the current hyprpaper docs (both the
  latest-git and v0.56.0 pages) show ONLY the block form. So the
  documented "comment mpvpaper, uncomment hyprpaper" toggle, part of
  the monitor+wallpaper contract, currently launches a daemon that
  aborts on its own config. Correct spec: drop the preload line and
  use the block form with an empty monitor as the all-outputs fallback
  (docs: "Monitor can be left empty for a fallback"):

      wallpaper {
          monitor =
          path = ~/.config/hypr/wallpaper.jpg
      }

  `ipc = on` and `splash = false` still parse (hyprlang bools), though
  splash's upstream default flipped to true.
- **The decoration shadow keys are dead on BOTH doc generations.**
  `drop_shadow`, `shadow_range`, `shadow_render_power`, and
  `col.shadow` appear nowhere on the 0.54 or 0.56 Variables pages; the
  documented form is a `shadow` subcategory under decoration with
  `enabled`, `range`, `render_power`, `color`, plus new
  `color_inactive`/`offset`/`scale`/`sharp`. Each line raises a config
  error and the intended tuning (range 12, power 2, translucent black)
  silently reverts to defaults (range 4, power 3). Correct spec
  (hyprlang channel): `decoration { shadow { enabled = true; range =
  12; render_power = 2; color = rgba(00000055); } }`.
- **misc:focus_fallback never existed.** The Variables pages (either
  era) contain only `general:no_focus_fallback` — which this config
  already sets to true in general{}. The stray `focus_fallback = false`
  in misc{} is a config error on every load and changes nothing even in
  intent. Correct spec: delete the line.
- **opengl:force_introspection in the commented NVIDIA block is dead.**
  The opengl category documents only `nvidia_anti_flicker` — on the
  0.54 page as well, so this predates the Lua migration. A user who
  correctly follows the NVIDIA opt-in instructions would load a config
  error. Correct spec: drop that line from the commented block.
- **The commented NVIDIA block's wlroots-era and VA-API vars are
  stale-to-invalid.** Per the current Nvidia page plus elFarto's
  README: WLR_NO_HARDWARE_CURSORS and WLR_DRM_NO_ATOMIC appear nowhere
  (Hyprland hasn't been wlroots-based since the aquamarine switch; the
  modern equivalent is the `cursor:no_hardware_cursors` option);
  GBM_BACKEND is gone too; the only two env vars the page still
  recommends are the two gpu-env.sh already sets. `NVD_BACKEND,
  wayland` is an invalid value — the page documents
  `NVD_BACKEND=direct` and upstream allows only `direct` or `egl` (with
  a warning that egl is broken on driver 525+). And `NVD_GPU_ADAPTER`
  is not a variable anywhere: the README's full NVD_* set is
  NVD_BACKEND, NVD_LOG, NVD_MAX_INSTANCES, and the two
  NVD_MAX_DETACHED_BACKING_* knobs. Layer 2 of the GPU-agnostic contract would hand NVIDIA users four
  dead-or-invalid exports. Correct spec: keep __GL_GSYNC_ALLOWED /
  __GL_VRR_ALLOWED / LIBVA_DRIVER_NAME / __GLX_VENDOR_LIBRARY_NAME and
  drop the rest (or point WLR_NO_HARDWARE_CURSORS at
  cursor:no_hardware_cursors if the comment wants a compositor-level
  knob).
- **NVIDIA cmdline guidance drifted.** The block comment (mirrored in
  the README's first-boot TODO) requires `nvidia_drm.modeset=1
  nvidia_drm.fbdev=1`; the current page says "As of Nvidia driver
  version 570.86.16, fbdev has now been enabled by default when modeset
  is also enabled. Therefore we simply need to enable modeset."
  Doc-side staleness, harmless but against the contract's layer 4.
- **All 13 window-rule lines predate the window-rules rewrite.** The
  12 `windowrule = <effect>, ^(regex)$` lines use bare-regex filters
  (the v1 reading: implicit class match), and the lone
  `windowrulev2 = nofocus, class:^(gamescope)$` mixes a keyword and a
  rule name (`no_focus` in current docs) that no longer appear in the
  docs either. Since 0.54 — still the hyprlang era — the documented
  form is blocks: `windowrule { name = ...; match:class =
  "^(steam_app_\\d+)$"; float = true; workspace = "5"; }`; on the 0.56
  page it is `hl.window_rule({ match = { class = "..." }, float = true
  })`. `windowrulev2` has zero hits on either. Whether the legacy layer
  still parses the comma line on 0.56 is not documented either way; the
  only forms upstream documents are the two above. Correct spec: block
  form with `match:class = ...` (float/center/workspace exist as
  documented effects; nofocus became no_focus).
- **MOZ_ENABLE_WAYLAND fell off the Environment-variables page.**
  Firefox has defaulted to Wayland for years; the line is inert cargo.
  (HYPRCURSOR_THEME/SIZE were never on that page — they live on the
  hyprcursor page — and remain correct.)
- **Migration exposure, logged once for the whole file, with the
  per-construct mapping this config will need when hyprlang is
  removed** (nothing here is required today; all of it is required for
  the config to survive the removal):
  - `monitor=,preferred,auto,1` → `hl.monitor({ output = "", mode =
    "preferred", position = "auto", scale = 1 })` (0.56 Monitors page
    documents only this; empty output is the documented fallback rule).
  - `env = X, y` → `hl.env("X", "y")`.
  - `exec-once = cmd` → `hl.on("hyprland.start", function() ...
    hl.exec_cmd("cmd") end)` per the current Autostart page.
  - `$mod`/`$key_*`/`$cmd` substitution → Lua locals and concatenation
    (`local mainMod = "SUPER"`, `hl.bind(mainMod .. " + K", ...)`); the
    Binds page shows no `$`-substitution anywhere.
  - binde/bindl/bindel/bindm → `hl.bind(keys, dsp, { repeating = true
    } / { locked = true } / { repeating = true, locked = true } /
    { mouse = true, ... })`.
  - dispatchers → hl.dsp.*: killactive→hl.dsp.window.close(),
    togglefloating→hl.dsp.window.float(), movefocus l→hl.dsp.focus({
    direction = "left" }), movewindow→hl.dsp.window.move({ direction =
    ... }), movetoworkspace→hl.dsp.window.move({ workspace = "5" }),
    workspace N / e+1→hl.dsp.focus({ workspace = "e+1" }), dpms→
    hl.dsp.dpms({ action = "on" }). Layout-owned pseudo/togglesplit
    move to the dwindle page's functions.
  - SEMANTIC TRAP already visible in the docs: the Lua resize
    dispatcher's `relative` parameter defaults to false (exact size),
    while hyprlang resizeactive took a delta — porting `-20 0` forward
    without `relative = true` inverts the behavior.
  - bezier/animation → `hl.curve("smoothOut", { type = "bezier",
    points = {...} })` + `hl.animation({ leaf = "windows", ... })`;
    the leaf names windows/windowsOut/border/fade/workspaces are still
    valid.
  - windowrule lines → `hl.window_rule({ match = { class = "..." },
    float = true })` (rules now take typed values).
  - `source = ~/.cache/wal/colors-hyprland.conf` and the
    keybinds-extra.conf source line have no hyprlang-source equivalent
    documented for the Lua config; the wal border template renders
    hyprlang assignments, so AGENTS.md palette-contract item 8 (the
    live border repaint path) needs a Lua-format renderer or a
    dofile-style loader at migration time.
  - hypridle.conf and hyprpaper.conf are unaffected by Hyprland's Lua
    migration (separate daemons, their own hyprlang parsers) — the
    hyprpaper breaking change recorded above is a daemon-side rewrite,
    unrelated to the compositor's.
- **Two risk items no document can settle, recorded honestly:** the
  current docs show hyprctl dispatch only with hl.dsp.* call strings
  (the rules page's hyprctl example), so `hyprctl dispatch dpms on` in
  hypridle.conf and the `hyprctl reload` flows in hyprland.conf and
  switch-theme.sh rest on legacy-string routing that is no longer
  documented; and `input:touchpad:tap-to-click` flipped documented
  spelling to `tap_to_click` between the 0.54 and 0.56 pages with no
  note on whether the legacy layer normalizes the dashed form. Neither
  is provably broken on 0.56; both are first suspects the day a bind or
  resume path misbehaves.

## Review pass 5 — Theme preset parity (4 presets)

Scope: all 32 files under `config/hypr/themes/{mocha,gruvbox,tokyonight,
osaka-jade}/`, `scripts/lint-themes.sh`, `config/hypr/switch-theme.sh`'s
copy block, and the wallpaper-mode counterparts the presets shadow:
`config/wal/templates/*`. The brief: re-run lint-themes.sh's own logic
by hand across all four presets, then go past its file-presence and
hex-membership level into the hex VALUES themselves — slot-for-slot
equality across formats, which the lint structurally cannot see.
Findings-only; only this section changed.

Method, stated once: the lint's three checks were re-implemented
independently (EXPECTED inventory per preset dir; case-insensitive hex
membership seeded from each colors.sh; the `sed -n '/cp -f/,/WAL_DIR\/
"$/p'` + `grep -oE` extraction of switch-theme.sh's cp list), then
extended with the deep checks below, then the real script was executed
under git-bash as a cross-check (exit 0; "SUMMARY: theme system is
fully synchronized"). Template-render checks substitute pywal16's
ACTUAL placeholder semantics, verified against `pywal/util.py` in
eylles/pywal16 master: `{name}` expands to `#rrggbb`, `{name}.rgb` to
the decimal triplet `r,g,b`, and `{name}.strip` to `rrggbb` without
the '#'.

Verified correct (no action):

- All 8 formats in all 4 presets, exactly — no missing file, no orphan
  file, and the cp block extracts to exactly those 8 basenames under
  the lint's own sed/grep pipeline. `THEMES=(...)` in switch-theme.sh
  matches the directory names, and `cycle`'s marker lookup maps every
  stored name back to an index.
- Slot-level equality, the property the lint does not test: in each
  preset, `background`, `foreground`, `cursor`, and `color0..15` carry
  byte-identical values across colors.sh, colors.el, colors-wal.vim,
  colors-waybar.css, and colors-rofi.rasi (19 slots x 5 files x 4
  presets, zero mismatches; the rasi legitimately omits cursor). Every
  preset's colors-hyprland.conf follows the template's slot layout —
  active border = rgb(color4) rgb(color1) 90deg, inactive = rgb(color0)
  — in hex form. The slot files are therefore true pre-renders: one
  source of truth honored positionally, not just as a set.
- colors-zed.json is an EXACT render of the wal template per preset:
  deep JSON comparison (all ~130 color-bearing keys, including every
  8-digit alpha form .../00, /33, /4d, /66, /1f, /26 in the right key)
  against config/wal/templates/colors-zed.json with that preset's own
  slots substituted. Wallpaper mode and preset mode hand Zed
  structurally identical themes; every alpha suffix is template-owned,
  not preset-authored. All four are valid JSON (parsed in the check),
  and config/hypr/themes/*/colors.el is additionally covered by
  lint.yml's emacs byte-compile step.
- colors-neomutt.muttrc is byte-identical across the 4 presets and
  contains only literal ANSI slot names (`color0`..`color15` are
  terminal-palette indices in muttrc syntax) — correct content for a
  component whose palette the terminal emulator (ghostty's wal-fed
  colors.conf) owns. config/neomutt/neomuttrc sources it from
  ~/.cache/wal/ as designed.
- osaka-jade is the only preset with mixed-case hex (`#FF5345`,
  `#C1C497`); every consumer parses case-insensitively and the lint
  lowercases before comparing, so this is cosmetic asymmetry, not
  drift. Logged for symmetry.
- The different "base colors" counts the lint reports (16 / 11 / 18 /
  11) are by design: mocha and tokyonight alias color9..14 onto
  color1..6 (canonical Catppuccin / Tokyo Night behavior where the
  bright set reuses the hues), while gruvbox and osaka-jade ship
  distinct brights. Not drift.

What was wrong — all three items live on the wallpaper-mode side, in
files that only render when `wal -i` runs (preset mode, which copies
hand-verified files, is unaffected by the first two):

- **`config/wal/templates/colors-hyprland.conf` renders invalid
  Hyprland on the first `wal -i`.** It writes `rgb({color4.rgb})`, and
  pywal16 substitutes `.rgb` as a bare DECIMAL triplet, so wallpaper
  mode emits e.g. `col.active_border = rgb(137,180,250)
  rgb(243,139,168) 90deg` — while Hyprland's gradient grammar takes
  HEX inside rgb(), the exact form all four presets ship
  (`rgb(89b4fa)`) and the template's own comment describes ("No `#` on
  the hex — Hyprland's col.* syntax takes bare rgb()"). The intended
  placeholder is `{colorN.strip}`. Because hyprland.conf sources the
  rendered file last (later assignment wins, palette-contract item 8),
  the bad render overrides whatever a preset copy established: after
  any `wal -i`, borders get at best silently wrong colors and at worst
  a config error, until a preset is re-applied. Correct spec: all three
  `{colorN.rgb}` become `{colorN.strip}`.
- **`config/wal/templates/colors-neomutt.muttrc` renders garbage
  tokens.** Its `color{colorN}` pattern substitutes to `color#89b4fa`
  — one invalid muttrc word — on 12 of 13 lines (`color indicator
  color0 color#89b4fa`, ...). In wallpaper mode, neomuttrc's
  `source ~/.cache/wal/colors-neomutt.muttrc` raises a parse error per
  line and the index-color scheme never applies. The presets ship the
  right content (literal `color4`-style names, braces removed; see the
  byte-identical note above) — the template should contain exactly that
  literal text, since wal copies plain text through unchanged and only
  substitutes `{...}` tokens. Correct spec: drop the braces.
- **lint-themes.sh's header promises a template check that exists
  nowhere — and as described could not have caught either bug above.**
  Lines 7-8 state that templates "are checked separately: every
  {placeholder} must be a name wal exports". No such check runs in the
  script (three sections: inventory / membership / cp list), in
  lint.yml's two theme steps (file presence; this script), or in
  60-update.sh's lint gate. And it is a name-level promise:
  `{color4.rgb}` and `color{color4}` consist solely of valid wal export
  names, so both broken templates pass it. What the header actually
  needs is render-equivalence — substitute a fixed known palette and
  require the rendered payload to equal the presets' payload (this
  pass's method) — the only level at which wrong substitution
  semantics surface. Correct spec when lint-themes.sh is next touched:
  extend step 2 into a temp-dir render check, or trim the header to
  describe what the script really does.

## Review pass 6 — Editor configs (nvim/emacs/zed/ox/croft/neomacs)

Scope: `config/nvim/init.lua` (plus the committed `lazy-lock.json`),
`config/emacs/init.el`, `config/zed/{settings,keymap}.json`,
`config/ox/{.oxrc.template,ox-theme.sh,ox-launch.sh}`,
`config/croft/croft-launch.sh`, `config/neomacs/neomacs-launch.sh`,
and the machinery they point at: `config/wal/templates/{colors.el,
colors-zed.json}`, the presets' editor-facing formats, `00-base.sh`'s
install blocks, `10-aur.sh`'s AUR list, `30-dotfiles.sh`, and
`hyprland.conf`'s exec-once + editor binds. The brief: every pywal
reference must name a file pywal16 actually renders, and every LSP
server an editor wires must be something the scripts really install.
Findings-only; only this section changed.

Verified correct (no action):

- Every editor-facing wal path resolves against pywal16's ACTUAL
  template inventory (eylles/pywal16 master, pywal/templates):
  `colors-wal.vim` and `colors.sh` are stock; `colors-zed.json` is
  stock upstream too and deliberately overridden by this repo's richer
  version; `colors.el` exists only because
  `config/wal/templates/colors.el` ships it (user templates override
  stock by name and render into ~/.cache/wal). The old `colors.vim`
  mis-path in init.lua is fixed and now documented in-file; all four
  presets carry all three editor-facing formats, and switch-theme.sh's
  cp block copies each of them.
- Deployment chain matches the comments: 30-dotfiles.sh's blanket
  `cp -a config/.` lands the wal templates at ~/.config/wal/templates/
  (palette-contract item 4), and lines 139-140 create
  ~/.config/zed/themes/pywal.json -> ~/.cache/wal/colors-zed.json,
  matching settings.json's `"theme": "Pywal"` and the template's
  embedded theme name (hot-reload claim = Zed's documented behavior).
- LSP inventory == install inventory: init.lua's nvim-lspconfig block
  wires exactly `pyright, rust_analyzer, clangd, lua_ls, bashls, gopls,
  ts_ls` plus `html, cssls, jsonls, eslint`; 00-base.sh's [4/9] block
  installs `pyright, rust-analyzer, clang` (Arch folded
  clang-tools-extra into `clang` — the package now
  `Provides: clang-tools-extra=22.1.8`, so clangd IS delivered),
  `lua-language-server, bash-language-server, gopls, typescript-
  language-server`, and 10-aur.sh builds vscode-langservers-extracted
  for the remaining four. eglot's only two explicit entries
  (pyright-langserver, rust-analyzer) are both installed; the rest
  ride eglot's probe defaults by design. Zed ships no
  `language_servers` key; for the servers whose Zed adapter binary
  names match what the scripts install (rust-analyzer, clangd, gopls,
  bash-language-server, the vscode-langservers-extracted four), PATH
  discovery does hold — Python and TypeScript are the exceptions, see
  the findings below.
- nvim pinning holds: the lazy.nvim bootstrap SHA
  `85c7ff3711b730b4030d03144f6db6375044ae82` equals upstream tag
  v11.17.5 (GitHub API) as the comment claims, and lazy-lock.json lists
  exactly the five spec'd plugins, their declared deps (plenary, three
  cmp sources, LuaSnip), and lazy.nvim itself — nothing extra.
- Ox's chain is real end-to-end: `--config`/`-c` is a genuine ox CLI
  flag (upstream src/cli.rs — its --help example is literally
  `ox -r -c ~/.config/.oxrc ...`), every `.oxrc.template` placeholder
  is among colors.sh's exports (background/foreground/color0..8), and
  colors.sh is in every preset's copy set. croft's pinned hint
  (`cargo install croft-software@0.1.942 --locked`) matches crates.io
  (0.1.942 is newest and un-yanked; binary name `croft`). neomacs
  correctly shims to the AUR `neomacs-bin` binary and reuses
  config/emacs/init.el.
- Editor binds are coherent: lapce (SUPER+G) and calendar
  (SUPER+SHIFT+G) share a letter under different modifiers, exactly as
  the README's binding-collision note already documents; croft/ox go
  through `$terminal -e`, neomacs/neovide launch directly, and the
  `$key_*`/`$*_command` indirections in keybinds-extra.conf all
  resolve.
- Zed key/keymap validation against the current configuring-zed docs
  and, where the docs were ambiguous, zed-industries/zed main sources:
  `code_lens: "on"` (off/on/menu), `diagnostics_max_severity: "hint"`,
  `vertical_scroll_margin`, `file_scan_exclusions`, `show_whitespaces:
  "selection"`, `scrollbar.show`, the project_panel/terminal blocks,
  `autosave: "on_focus_change"`, `format_on_save: "on"`,
  `ensure_final_newline_on_save`, `remove_trailing_whitespace_on_save`,
  `buffer_line_height: "comfortable"`, `auto_update`,
  `auto_install_extensions` — all valid as shipped. The keymap actions
  (workspace::ToggleVimMode, task::Spawn/Rerun,
  terminal_panel::ToggleFocus, editor::Format) are built-ins, and the
  extension ids `sql` and `postgres-language-server` both resolve in
  the current extensions registry.

What was wrong — three behavioral bugs, one stale doc reference, one
undocumented exception:

- **`zed/settings.json` still ships legacy booleans for two keys that
  are string-only enums on current Zed.** `"auto_indent": true` and
  `"relative_line_numbers": true` predate Zed's enum migration:
  `AutoIndentMode` (crates/settings_content/src/language.rs) accepts
  only syntax_aware/preserve_indent/none and `RelativeLineNumbers`
  (crates/settings_content/src/editor.rs) only
  disabled/enabled/wrapped — plain serde string enums, no boolean
  alias, and the current docs list only the string forms. Both values
  fail to deserialize; Zed's fallible-settings parser records the file
  as Failed (the settings-error banner path) and the affected fields
  fall back to defaults. Correct spec: `"auto_indent":
  "syntax_aware"` (which is also the default, so the line can simply
  go) and `"relative_line_numbers": "enabled"`.
- **Zed does not use the PATH-installed Python/TypeScript servers under
  its defaults — it downloads its own.** 00-base.sh [4/9]'s comment
  ("Zed discovers servers from $PATH itself — no settings.json entry
  needed") only holds where Zed's adapter binary name matches what the
  scripts install. Per zed.dev's language docs (checked today):
  Python defaults to **basedpyright** as the primary language server
  plus **Ruff** for formatting/linting — neither is installed by any
  script — and TypeScript defaults to **vtsls**, while 00-base.sh
  ships typescript-language-server (the documented ALTERNATE, only
  used behind a `languages.TypeScript.language_servers` opt-in). Zed's
  documented fallback when the expected binary is absent is a private
  automatically-installed copy, so the first `.py`/`.ts` buffer opened
  triggers an unreviewed network download into Zed's data dir
  (extension auto-installs are policy-accepted; LSP downloads are not
  surfaced anywhere today), and the pacman-managed pyright /
  typescript-language-server only ever serve nvim and eglot — not the
  rice's default editor. Correct spec: either pin the lists in
  `config/zed/settings.json`
  (`["pyright", "!basedpyright", ...]` for Python;
  `["typescript-language-server", "!vtsls", ...]` for
  TypeScript/TSX/JavaScript), or package basedpyright/ruff/vtsls so
  the default adapters resolve from PATH.
- **Ox never re-themes in wallpaper mode.** ox-theme.sh runs at deploy
  (30-dotfiles.sh:156) and on preset switches (switch-theme.sh:58), but
  hyprland.conf's exec-once wallpaper branch is
  `wal -i ... && ghostty-theme.sh` only. So the documented wallpaper
  flow — drop wallpaper.jpg and re-login, or run `wal -i` by hand —
  refreshes ghostty's colors.conf while ~/.config/ox/.oxrc (which
  ox-launch.sh always feeds to ox via --config) keeps whatever palette
  the last preset or deploy rendered, indefinitely. Correct spec: add
  an ox-theme.sh call next to ghostty-theme.sh in that exec-once (the
  script already self-guards when colors.sh is missing). The
  mid-session manual-`wal -i` gap exists for ghostty too and is
  pre-existing; out of this pass's scope.
- **init.el's 00-base.sh step references point at labels the script
  never prints.** init.el cites the "[8/8]" Emacs prompt (line 11) and
  the "[4/8]" LSP block (line 21); the script's own echoes number steps
  1-2 as [N/8] but steps 3-9 as [N/9] — internally inconsistent, and
  init.el's references resolve to nothing under either scheme except a
  nonexistent /8 range. Correct spec: normalize the script's counter to
  /9 throughout and update init.el to "[8/9]"/"[4/9]" (AGENTS.md's
  prose "step 4"/"step 8" wording stands).
- **lapce is installed (00-base.sh:115), bound (SUPER+G), and
  README-listed, yet has zero rice config** — no `config/lapce/`, no
  palette wiring, no LSP settings. That makes it an undocumented
  exception to the palette contract's "VLC stays unthemed — every
  other in-session component follows the palette" clause: either
  declare it unthemed-by-design alongside VLC, or give it the same
  treatment as the other editors. (This also closes the pass-scope
   note: the brief named lapce, but there is no `config/lapce/` to
   audit.)

## Review pass 7 — Mail/calendar stack (neomutt/isync/msmtp/khal/vdirsyncer)

Scope: `config/neomutt/neomuttrc` + `accounts/{gmail,other}.muttrc.example`,
`config/isync/mbsyncrc.example`, `config/msmtp/config.example`,
`config/khal/config`, `config/vdirsyncer/config.example`, plus the
machinery around them: `.gitignore`'s credential rules,
`30-dotfiles.sh`'s copy-if-absent/chmod/timer blocks, `50-verify.sh`'s
neomutt check, the `vdirsyncer-google.{service,timer}` units,
`00-base.sh`'s package list, and README's "Mail and calendar setup".
The brief: (1) no real credentials or account identifiers committed —
only `.example` files may carry real-looking values, and those must be
obviously placeholder; (2) neomutt's GPG-signing placeholder-key warning
(already guarded by 50-verify.sh) must still be accurately documented as
a manual TODO. Method: full `git log -p` over those paths, a secret
sweep across all 106 tracked files, `git check-ignore -v` on the live
rules, and upstream checks against neomutt.org's current reference, the
Arch `neomutt 1:20260616-1` package file list, and `mutt_oauth2.py` at
neomutt/neomutt main. Findings-only; only this section changed.

Verified correct (no action):

- **Credential hygiene holds on all three layers: tree, gitignore,
  history.** Tracked mail-stack files are the seven in scope plus the
  two vdirsyncer units — every identity value is placeholder
  (`you@gmail.com`, `you@example.com`, "Your Name",
  `imap/smtp.example.com`, `pass mail/other`, `YOUR_GPG_KEY_ID_HERE`,
  `YOUR_CALENDAR_CLIENT_ID`/`_SECRET`). `check-ignore` confirms the
  ignore rules bite: `config/msmtp/config`, `config/isync/mbsyncrc`,
  `config/vdirsyncer/config`, `config/neomutt/accounts/*.muttrc` (with
  the `!*.muttrc.example` re-inclusion), `config/neomutt/oauth/`, and
  `config/vdirsyncer/*token*` all ignored. History scan over every
  commit touching these paths (5 commits): only placeholder values ever
  committed — the trajectory runs the right direction, with the old
  `imap_user`/`smtp_url` inline-auth lines REMOVED in favor of the
  msmtp/OAuth indirection. The repo-wide sweep found no private keys,
  API keys, or non-placeholder secrets anywhere in the 106 tracked
  files.
- The two non-`.example` tracked configs carry no identifiers:
  `neomuttrc` uses only the role labels gmail/other, and
  `config/khal/config`'s `[[google]]` stanza is a generic label whose
  `type = discover` + wildcard `path = ~/.calendars/google/*` design is
  exactly what keeps user-specific calendar names OUT of the committed
  file — khal never needs per-calendar committed config.
- README's OAuth instructions resolve end-to-end: Arch's neomutt
  package ships `/usr/share/neomutt/oauth2/mutt_oauth2.py` (what
  `pacman -Ql neomutt | grep oauth2` finds, per the README); upstream's
  script has a `#!/usr/bin/env python3` shebang, encrypts the token
  store through GPG by default, and *self-enforces* mode 600 on the
  token file. Its bare-token stdout is precisely what both `.example`
  recipes need — isync's `AuthMechs XOAUTH2` + `PassCmd` and msmtp's
  `auth xoauth2` + `passwordeval` — and both point at the same
  `~/.config/neomutt/oauth/` path the README tells the user to populate.
- **The GPG-signing placeholder TODO is accurately documented as
  shipped.** Defaults in `neomuttrc` (`crypt_autosign = no` +
  `pgp_default_key = "YOUR_GPG_KEY_ID_HERE"`) make signing inert; the
  "Mail and calendar setup" sentence ("signing is disabled until
  YOUR_GPG_KEY_ID_HERE is replaced with a real key and crypt_autosign is
  explicitly enabled") describes precisely that state; and 50-verify.sh's
  guard (which reads the DEPLOYED `~/.config/neomutt/neomuttrc`, not
  the repo copy) fails only the dangerous combination — autosign yes
  *with* the placeholder — and passes the shipped config. Placement in
  the mail-setup prose rather than "Mandatory first-boot TODOs" is
  correct: mail credentials are not blocking for the rice. Variable-name
  sanity also checked: `pgp_default_key` is the documented default-key
  knob (renamed from `pgp_self_encrypt_as` in 2018; used for signing
  unless `pgp_sign_as` is set) under both the classic and gpgme
  backends, and `crypt_use_gpgme = yes` merely restates the current
  upstream default — harmless.
- Install pipeline honors the contract: 30-dotfiles.sh copies
  `.example` -> real only when no personalized file exists, chmods
  msmtp/config + isync/mbsyncrc to 600, and enables
  `vdirsyncer-google.timer` only once a real vdirsyncer config exists.
  The units carry no identifiers (`ExecStart=...vdirsyncer sync
  google_calendar`; 15-minute cadence with `Persistent=true`).
  `00-base.sh` ships the whole stack from official repos (`neomutt
  isync msmtp gnupg khal vdirsyncer`).
- Routing coherence: neomuttrc's `folder = ~/Mail`,
  `+{gmail,other}/Inbox` mailboxes, and the two folder-hooks align with
  the mbsync stores (`~/Mail/gmail/`, `Inbox`) and the msmtp account
  names (`msmtp -a gmail` / `-a other`) the account examples set; the
  startup-source-once + folder-hook re-apply pattern (with the explanatory
  comment) is the correct defense against `$from`/`$sendmail` pinned to
  whichever file was sourced last.

Findings (documented, unfixed per audit convention):

- **The 50-verify.sh guard matches only the legacy variable spelling;
  upstream renamed it in 2021.** `$crypt_autosign` became
  `$crypt_auto_sign` on 2021-03-21 (neomutt.org reference 3.81/3.85).
  The old name still works as a silent synonym, so the shipped
  `set crypt_autosign = no` line is fine — but the verify grep is
  `set[[:space:]]+crypt_autosign[[:space:]]*=[[:space:]]*yes`, and only
  against neomuttrc. A user enabling signing per CURRENT upstream docs
  writes `set crypt_auto_sign = yes`; that spelling passes verify green
  with the placeholder key still set — the exact combination the check
  exists to catch. README's mail section also names only the legacy
  spelling. Correct spec when 50-verify.sh is next touched: match both
  (`crypt_auto(sign|_sign)`) and add a one-line upstream-rename
  parenthetical to the README sentence.
- **The placeholder key is not fully inert when opportunistic encryption
  engages.** `neomuttrc` sets `crypt_opportunistic_encrypt = yes`, and
  `$pgp_self_encrypt` defaults to yes and encrypts-to-self using
  `$pgp_default_key` (reference 3.347 -> 3.325). Compose to a recipient
  whose key resolves and the send trips on `YOUR_GPG_KEY_ID_HERE` — no
  such key in the keyring — even though signing stays off. Conditional
  on a populated recipient keyring and the error is loud and
  self-diagnosing, so severity is minor; the gap is that the README's
  TODO sentence covers signing only. Correct spec: extend that sentence
  to say the placeholder must be replaced before opportunistic
  encryption can work too (or ship `pgp_self_encrypt = no` alongside
  the current defaults).
- Minor mode asymmetry: 30-dotfiles.sh's chmod 600 covers
  `msmtp/config` and `isync/mbsyncrc` but not the two
  `neomutt/accounts/*.muttrc` copies made by the same loop, whose own
  comment says the quartet "contain user addresses". The account files
  hold no credentials (sending routes through msmtp's 600 file), just
  the From address + realname at umask defaults; whether that is
  readable by other local users depends on ~/.config and parent perms.
  One-line extension of the existing chmod when it is next touched.
  (Pass 2's robustness bullet — the same chmod dies under `set -e` if
  neither target exists — covers the same line, different defect.)

Cross-references, not re-litigated: pass 5's `colors-neomutt.muttrc`
template finding directly governs this stack (neomuttrc sources the
rendered file) and remains open — the shipped default stays correct
only because 30-dotfiles.sh seeds the mocha preset (its copies carry
valid content); pass 3's note that the mail placeholder check hides
under 50-verify.sh's "[4/9] clamav" banner; pass 2's chmod robustness
gap.

## Review pass 8 — Desktop shell configs (waybar/swaync/rofi/wlogout/eww)

Scope: all ten files under `config/{waybar,swaync,rofi,wlogout,eww}/`,
including the one compiled component (`rofi/keybind-menu.cpp`), plus the
wiring that launches them — `hyprland.conf`'s exec-once lines, `$menu`,
the vlc-open rofi line, and the wlogout bind — and `30-dotfiles.sh`'s
keybind-menu rebuild step. The brief: (1) every component importing
pywal cache files must point at `colors-waybar.css` (GTK `@define-color`
syntax), never web-CSS `colors.css`, per the AGENTS.md palette contract
item 3 — rofi excepted to `colors-rofi.rasi` via item 4; (2) confirm no
component added since the policy was written reintroduces that bug.
Method: full read of every in-scope file; per-path `git log --follow
--diff-filter=A` to date each component against the contract's commits;
a repo-wide `colors.css` sweep plus a full `.css/.scss/.rasi` inventory
of `config/`; upstream verification against swaync v0.12.6 (Arch's
current release: configSchema.json, baseWidget/dnd Vala sources) and
v0.7.1's shipped default config for the GTK3-era key history, eww
master source (eww_config.rs, validate.rs, main.rs), and wlogout's
documented layout format. Findings-only; only this section changed.

Verified correct (no action):

- **All five components import the right pywal file — the colors.css
  bug class stays dead.** waybar/style.css:7, swaync/style.css:8,
  eww/eww.scss:7, and wlogout/style.css:9 each `@import
  "../../.cache/wal/colors-waybar.css"` (the relative path resolves
  ~/.config/<tool>/ to ~/.cache/wal/), and rofi/config.rasi:38
  `@import`s `../../.cache/wal/colors-rofi.rasi` exactly as contract
  item 4 requires. The repo-wide sweep finds `colors.css` in only two
  places: AGENTS.md's prohibition itself and this README's "Notable
  bug-fix audit" entry for the phase-2 fix. The five stylesheets are
  also the only CSS in the tree — the full inventory under config/ adds
  only the preset copies and the wal template that feeds rofi.
- **Every `@name` reference resolves.** The four GTK stylesheets use
  only @background/@foreground/@color1..8; the stock pywal16 template
  and all four preset copies define @background/@foreground/@cursor/
  @color0..15 (mocha checked slot-for-slot). config.rasi's
  @color1/2/3/4/8 all exist in the custom rasi template's color0..15
  set, which the presets mirror (pass 5's slot-level check).
- **The policy's dates line up and nothing added since violates it.**
  The contract was born in 67bb1f9 (2026-08-11) and made true by
  db8ee0d (2026-08-15) — the same "Phase 2" commit that migrated the
  consumers off colors.css and rewrote AGENTS.md item 3. Since then
  these five directories gained exactly one file:
  `rofi/keybind-menu.cpp` (2c717c8, 2026-09-15). It spawns bare
  `rofi -dmenu -p keybinds -format i` — no `-theme`/`-config`, no
  inline colors, its header codifying that "all styling lives in
  config.rasi" — so the menu inherits the wal palette through
  colors-rofi.rasi like every other rofi surface. (cc29eff's 2026-09-10
  waybar/config touch is a comment-only wording change.) The other
  post-policy themed additions under config/ — the wal templates,
  preset files, ghostty-theme.sh, the ox renderer — are the contract's
  own items 4-9 channels; no new CSS consumer appeared anywhere.
- **Launch wiring passes no style overrides.** `exec-once = waybar`,
  `exec-once = swaync`, `$menu = rofi -show drun -show-icons`, the
  vlc-open `rofi -dmenu -p "play url"` line, `bind = $mod SHIFT,
  $key_logout, exec, wlogout`, and `eww open bar_main || true` all run
  each tool against its default config path — the file carrying the
  palette import. No `-theme`/`--style`/`-c` flag exists anywhere.
- keybind-menu's deploy contract is intact: the repo tracks only the
  .cpp; 30-dotfiles.sh rebuilds it into ~/.config/rofi/ with
  -DRICE_REPO, drops the cp -a'd source copy, and the `#ifndef
  RICE_REPO` fallback keeps lint.yml's -fsyntax-only check building
  without a -D.
- swaync/config.json's remaining keys are all valid against the
  current upstream schema (v0.12.6): the positionX/positionY/layer
  enum values, cssPriority "user" (the documented way to also override
  ~/.config/gtk-4.0/gtk.css), the 6/4/0 timeout triple, fit-to-screen,
  keyboard-shortcuts, image-visibility, the five built-in widget names,
  and every widget-config key it sets (title's text/clear-all-button/
  button-text, dnd's text, volume's label/show-per-app). The `//`
  header stays per AGENTS.md's lint section.
- wlogout/layout matches the upstream format its own header documents
  (one JSON object per button, no wrapper array), uses portable
  loginctl/systemctl actions instead of hyprctl, and style.css styles
  generic `button` selectors, so the documented label <-> `#label`
  convention adds no coupling. eww.yuck's defvar+defpoll same-name
  pattern is valid per eww master (validate.rs has no duplicate-name
  check; generate_initial_state overlays defvar values on the
  script-var seeds, so "loading..." is simply the pre-first-poll
  initial), the Wayland window properties (stacking "fg", exclusive
  false, focusable false) are schema-valid, and `eww open` starts the
  daemon itself when the socket is absent (main.rs's WithServer arm),
  so the single exec-once line is self-sufficient. waybar's
  hyprland/workspaces and hyprland/window module names are current
  (waybar removed the wlr/workspaces spelling in 0.10).

Findings (documented, unfixed per audit convention):

- **swaync/style.css's DND rules target a class swaync never applies.**
  Control-center widgets get `widget` + `widget-<name>` CSS classes
  (v0.12.6 baseWidget.vala), so the DND row is `.widget-dnd`, and its
  switch carries the explicit back-compat class `control-center-dnd`
  (dnd.vala: "Backwards compatible towards older CSS stylesheets");
  upstream's own default stylesheet targets `.widget-dnd` and its
  inner `switch`. The shipped `.dnd { ... }` and `.dnd > switch { ... }`
  therefore match nothing: the row's @background/padding and the
  switch's palette colors (@color1 unchecked, @color3 checked) are dead
  CSS, and the toggle renders with swaync's defaults — the one control
  in the notification center that escapes the pywal palette (the label
  still tints via the global `* { color: @foreground }`). Correct spec
  when style.css is next touched: `.dnd` -> `.widget-dnd`, and
  `.dnd > switch` -> `.widget-dnd switch` (or `.control-center-dnd`
  for the switch alone).
- **swaync/config.json carries keys current swaync doesn't have.**
  `transition-speed` is not a swaync key — the v0.7.1 default config
  already used `transition-time`, and v0.12.6's schema still does — so
  the setting is inert; the intended 200ms coincidentally equals the
  default, hiding the miss until someone tunes it. The mpris block
  sets `image-size` (deprecated upstream in favor of the
  `--mpris-album-art-icon-size` CSS variable) and `image-radius` (a
  real GTK3-era key — v0.7.1 shipped it — dropped in the GTK4 port and
  absent from the v0.12.6 schema), and `notification-icon-size` is
  likewise deprecated in favor of `--notification-icon-size`. swaync
  reads only the keys it knows, so nothing visibly breaks — which is
  exactly how the drift went unnoticed. Correct spec when the file is
  next touched: switch to `transition-time`, drop the two dead mpris
  keys (accept the defaults or move to the CSS variables), and migrate
  the icon size.
- **hyprland.conf's palette header describes a mechanism that doesn't
  exist.** Line 13: "Tools (waybar, swaync, rofi) read source =
  common.<theme>.rasi/.css templates that import pywal vars." No
  `common.<theme>` file exists in the repo or in wal's output — the
  sentence predates phase 2 (db8ee0d fixed the imports and rewrote the
  AGENTS.md contract but missed this comment). What actually happens:
  each tool's own stylesheet @imports ~/.cache/wal/colors-waybar.css
  (waybar, swaync, wlogout, eww) or colors-rofi.rasi (rofi) per
  contract items 3-4. Anyone debugging colors from this comment finds
  nothing to read. Correct spec: rewrite it to describe the @import
  flow and name all five tools.
- **eww.yuck's cpu poll displays top's since-boot average.** `top
  -bn1`'s first and only iteration reports CPU usage averaged since
  boot — the classic top gotcha; instantaneous usage needs the second
  iteration (run `top -bn2` and take the second `Cpu(s)` line) or two
  /proc/stat reads. The demo bar therefore shows a near-static CPU%
  that doesn't track live load, while its MEM sibling is fine (the
  free-based $3/$2 math is correct for procps output). Minor — the
  widget exists to exercise the eww binary — but it is the only
  "live" number the bar shows.
- Minor batch, cosmetic: (1) waybar/config lists `hyprland/window` in
  both modules-left and modules-center, so the focused title renders
  twice per bar (valid config, almost certainly unintended); (2)
  rofi/config.rasi sets `lines: 10` in configuration{} but `lines: 12`
  in the listview{} theme block — the theme value wins, leaving the 10
  dead; (3) hyprland.conf:152's eww comment is garbled mid-sentence
  ("separate from waybar —Dates a small bar at top-right"); (4) the
  README `## Tree` diagram pre-dates several merges — rofi/ still
  lists only config.rasi (keybind-menu.cpp missing), and the mail
  stack, clamav, systemd/user timers, zed keymap.json, and wal's
  colors-neomutt.muttrc template have no entries at all.

## Review pass 9 — systemd user units (config/systemd/user/*)

Scope: all seven files under `config/systemd/user/` —
`clamav-scan.{service,timer}`, `rice-update-check.{service,timer,sh}`,
`vdirsyncer-google.{service,timer}` — plus everything that enables or
references them: `00-base.sh` (the script the brief names),
`30-dotfiles.sh` (the script that actually enables the user units),
`40-gaming.sh` (gamemoded.service), README's update-checker enable
line, and the ExecStart chain into `config/clamav/scan-targets.sh`.
The brief: (1) every .service has a matching, sane .timer where one
exists; (2) no unit runs as an unnecessarily broad user/group;
(3) enabled units match what's shipped — no orphaned unit files, no
referenced-but-missing ones. Method: full read of all seven files and
both ExecStart targets, a repo-wide `systemctl` sweep across all
scripts, git index mode checks (exec bits), and semantics checked
against systemd.timer(5)/systemd.service(5). Findings-only; only this
section changed.

Verified correct (no action):

- **Pairing is 3-for-3 in both directions.** Every .service has a
  same-named .timer, and every .timer's implicit activation target
  (no `Unit=` anywhere — the same-name default) exists on disk. All
  three timers carry `[Install] WantedBy=timers.target`; none of the
  services carry `[Install]`, which is correct for timer-activated
  units. All three services are `Type=oneshot`, the right shape for
  timer-triggered batch jobs.
- **No unit runs broad.** All six units are systemd `--user` units
  executing as the login user; there are no `User=`/`Group=`/
  `SupplementaryGroups=` directives and no sudo/doas anywhere in the
  units or their helpers, and `scan-targets.sh:8-11` actively refuses
  EUID 0. The repo's only `sudo systemctl` calls (00-base.sh x6,
  45-snapshots.sh x2, 20-sddm.sh x1) enable system-manager services
  whose own packages define the privilege model (freshclam drops to
  the clamav user via its packaged unit) — root there is required,
  not excessive.
- **Enablement matches shipping exactly: zero orphaned unit files,
  zero referenced-but-missing units.** 00-base.sh itself enables no
  user units — its six enables (bluetooth, ufw, clamav-freshclam,
  cpupower, postgresql, mysqld) are all package-shipped units whose
  packages the same script installs (cpupower: installed :270,
  enabled :299, with a comment explaining the two-name config-file
  detection). The repo-shipped user timers are enabled from
  30-dotfiles.sh: `clamav-scan.timer` via an opt-in `[y/N]` prompt
  (:118-123), `vdirsyncer-google.timer` only when
  `~/.config/vdirsyncer/config` exists (:126-131 — impossible on a
  fresh install since `config/vdirsyncer/` ships only
  `config.example`, matching pass 7's credential design), and
  `rice-update-check.timer` only via README's manual enable line
  (AGENTS.md's "NOT auto-enabled" contract holds). gamemoded.service
  (40-gaming.sh:20-22) is shipped by the gamemode package, not this
  repo.
- **Every ExecStart path resolves on the target.**
  `%h/.config/clamav/scan-targets.sh` is mode 755 in the git index
  and re-chmodded at 30-dotfiles.sh:110;
  `%h/.config/systemd/user/rice-update-check.sh` is 644 in the index
  but chmod +x'd at :116 (after the blanket `cp -a`, correct order);
  `/usr/bin/vdirsyncer` is the official-repo path installed by
  00-base.sh:124. rice-update-check.sh is also fully wired into CI
  (bash -n + shellcheck) and the 60-update.sh lint gate.
- **Cadences match their purposes.** Update check: `OnCalendar=daily`
  + `RandomizedDelaySec=30min` + `Persistent=true` — the one timer
  whose catch-up flag is live. Calendar: 15-minute session cadence,
  the figure README's mail/calendar section documents. AV scan: ~20
  min after session start, then roughly daily while the session
  persists.
- **Deploy/update plumbing is sound.** Unit files land via the
  blanket `cp -a` and `daemon-reload` runs after it (30-dotfiles.sh
  :117); 60-update.sh re-runs 30-dotfiles.sh (:317), so changed units
  are reloaded on update; enable symlinks persist across redeploys;
  `enable --now` is idempotent on re-run.

Findings (documented, unfixed per audit convention):

- **`Persistent=true` is dead config on two of the three timers.**
  `clamav-scan.timer` and `vdirsyncer-google.timer` use only
  monotonic triggers (`OnBootSec` + `OnUnitActiveSec`), and per
  systemd.timer(5) `Persistent=` "only has an effect on timers
  configured with OnCalendar=" — so the catch-up-after-downtime
  behavior both lines imply never happens. Only
  `rice-update-check.timer` (`OnCalendar=daily`) gets real catch-up.
  For the AV scan the missed-run case is the one that matters: a
  scan skipped because the machine was off simply doesn't run until
  the next boot+20min. Correct spec when the timers are next
  touched: either switch to `OnCalendar=daily` (making `Persistent=`
  real and the "Daily" descriptions literally true) or drop the dead
  lines.
- **README overstates the ClamAV timer's enablement.** Lines
  108-110: "`30-dotfiles.sh` enables a daily user timer" — the
  script prompts `[y/N]` and defaults to leaving it disabled
  (30-dotfiles.sh:118-123). Pass 3's audit text (line 1556) says
  "offers to enable", which is the accurate version. Wording fix on
  the next README touch.
- **The three timer-driven jobs disagree about failing the unit, and
  nothing documents it.** rice-update-check.sh is built to never
  light up `systemctl --user --failed` (exits 0 on every failure —
  its header explains why); scan-targets.sh propagates clamscan's
  exit status, so a detection (1) *or* a scan error (2+) parks the
  unit in the failed list until the next clean run;
  vdirsyncer-google.service propagates vdirsyncer's exit, so an
  offline laptop nets a failed unit that self-heals at the next
  15-minute trigger. Each stance is defensible — loud on malware,
  silent on a notifier — but the divergence is a design call that
  exists nowhere in writing, and for calendar sync the transient-
  offline failure is pure `--failed`/journal noise.
- **The heaviest user job fires 20 minutes after boot with no
  scheduling concessions.** `clamav-scan.service` runs a recursive
  clamscan over Downloads, both Maildirs, and every discovered
  mounted Windows `Users` dir with no `Nice=`/`IOSchedulingClass=`
  in the unit and no nice/ionice in scan-targets.sh — i.e. at
  roughly the moment the user logs in and starts working. Low
  severity; add `Nice=19` and `IOSchedulingClass=idle` to the unit
  when it's next touched.
- Minor batch: (1) 30-dotfiles.sh runs `systemctl --user
  daemon-reload` twice (:117 and again at :127 inside the vdirsyncer
  branch) — the second is redundant with the first, harmless; (2) no
  CI step parses the unit files themselves — lint.yml covers the
  .sh helper (bash -n + shellcheck) but never runs anything like
  `systemd-analyze verify` over the six units, so a typo'd directive
  would deploy silently until a timer misfires (coverage-gap note,
  same theme as pass 3); (3) AGENTS.md's layout entry (:166) and
  components map (:285-286) name clamav-scan and rice-update-check
  but not `vdirsyncer-google.*`, which arrived with the pass-7
  mail/calendar stack — doc-completeness lag; (4) the README `##
  Tree` diagram omitting `config/systemd/user/` is already logged in
  pass 8's minor batch — not re-litigated.

---

## Review pass 10 — CI coverage completeness (.github/workflows/lint.yml)

Scope: lint.yml's seven steps mapped file-by-file against the full
tracked tree — 23 shell files (22 `.sh` plus the extensionless POSIX-sh
`config/vlc/vlc-open`), 12 JSON/JSONC files, 6 Elisp files, 1 Lua file,
1 C++ translation unit (no headers exist). Method: `git ls-files`
inventory plus a repo-wide `^#!` shebang sweep and a git-index exec-bit
check (catches shell files hiding without the `.sh` suffix); every file
assigned to the lint step that claims it; each candidate gap validated
empirically with a byte-faithful replica of the CI pipeline (python
`json` in place of `jq`, same `sed '/^\/\//d'` strip; `bash -n` for the
preset colors.sh set); drift dated via `git log` on lint.yml and the
files involved. `.zed/tasks.json` and `60-update.sh`'s lint gate were
audited as parallel copies of those lists, not as CI themselves.
Findings-only; only this section changed.

Verified correct (no action):

- **Shell is the fully-covered class: 23/23, twice over.** The bash -n
  step and the shellcheck step share one list — the two glob arms
  (`scripts/*.sh` = 11, `scripts/lib/*.sh` = 1) plus 11 explicitly
  named config-side files. The shebang sweep found exactly the same 23,
  no more: the classic gap class (an extensionless script the globs
  can't see, or a new file nobody listed) is currently empty — even
  `config/vlc/vlc-open` (`#!/bin/sh`) is named explicitly. Globs absorb
  future `scripts/` additions automatically; the explicit config list
  is where a new helper would be forgotten, and that's findings 1-6's
  theme.
- **Lua 1/1 and C++ 1/1.** `config/nvim/init.lua` gets a LuaJIT
  bytecode parse (nvim's exact dialect — the right choice over generic
  luacheck for init.lua), and `config/rofi/keybind-menu.cpp` compiles
  under `-Wall -Wextra -Werror -fsyntax-only`. No other .lua/.cpp/.h
  files exist to fall through.
- **Elisp 5/6, and the covered 5 are drift-proof.** `init.el` plus
  `config/hypr/themes/*/colors.el` byte-compiled via a glob — a *new
  preset* can't escape coverage the way a new one-off file can. The
  emacs step even deletes its own `.elc` artifacts afterwards.
- **The five JSON files lint.yml names are the right five of the
  original set, genuinely parsed.** swaync/config.json,
  zed/settings.json, zed/keymap.json, postgres-language-server.jsonc
  under `jq empty` (with the deliberate `//` headers stripped), and
  wlogout/layout under `jq -s` because it's concatenated button
  objects, not one document. The postgres commit (13a8857) is the
  template for the fix pattern this pass checks for: it extended
  lint.yml, `.zed/tasks.json`, and `60-update.sh`'s gate in the same
  commit that added the file.
- **Reverse-drift check is clean.** Every file lint.yml names still
  exists; no stale entries, no renamed-away paths. The two theme-matrix
  steps and lint-themes.sh are glob-driven over `themes/*/`, so the
  preset side is structurally drift-immune.

Findings (documented, unfixed per audit convention):

- **`config/nvim/lazy-lock.json` has never been covered by anything.**
  Added 2026-09-06 in 1dc12c4 (the lazy.nvim pinning commit — the
  moment it became a tracked, hand-maintained file under the editor
  plugin rule) and untouched since; lint.yml has been edited at least
  six times in the meantime (through 359df11 on 2026-09-25) without
  picking it up. It's pure single-object JSON and parses with a plain
  `jq empty`, no stripping needed (verified). The exposure window is
  precisely the edit the file exists for: a plugin bump is a hand-edit
  of pinned SHAs after an upstream diff review, and a trailing-comma or
  brace slip there deploys silently into every nvim cold start. This is
  the same drift class the postgres commit had to patch for
  postgres-language-server.jsonc — minus the fix.
- **`.zed/tasks.json` is checked by nothing, including itself.** Pure
  JSON, verified parseable, last meaningfully touched 2026-09-25
  (359df11). Its "Repo: JSON validation" and "Repo: Full lint" tasks
  embed verbatim copies of lint.yml's shell and JSON lists — so the
  file is simultaneously an uncovered JSON file and a second home for
  the master lists (see the structural finding). A syntax break here
  fails silently as missing tasks in the authoring box's Zed.
- **`config/waybar/config` is the covered swaync/wlogout `//`-JSONC
  class and never made the list.** Verified wrinkle: waybar's header
  comment block is indented, while lint.yml's strip is column-anchored
  (`sed '/^\/\//d'`) — replicating the pipeline shows 4 comment lines
  survive the anchor in waybar/config (0 in swaync and wlogout), so
  the file can't be dropped into the existing loop as-is; the strip
  must widen to `^[[:space:]]*//` (or the comments un-indent) in the
  same change that adds the file. Parses clean once stripped.
- **The four `config/hypr/themes/*/colors-zed.json` are grep-checked,
  never parsed.** lint-themes.sh proves hex *membership* against the
  preset's colors.sh via `grep -oE '#[0-9a-fA-F]{6}'`, which by
  construction cannot see JSON structure: delete a comma between two
  alpha-suffixed entries (`"#9399b233"` still matches the 6-hex regex)
  and every current gate stays green while Zed rejects the generated
  theme at load. All four parse clean under plain `jq empty` today
  (verified).
- **The four `config/hypr/themes/*/colors.sh` are real shell —
  `source`'d at runtime — and never `bash -n`'d.** switch-theme.sh
  copies the preset's colors.sh to `~/.cache/wal/colors.sh` and
  ghostty-theme.sh:39 does `source "$WAL"` on that path, so a syntax
  break lands mid-session at the next theme switch, not at a gate. All
  four pass `bash -n` today (verified). Secondary effect:
  lint-themes.sh seeds its known-color key set by grepping that same
  file, so a broken quote doesn't fail loudly at seed time — it shrinks
  the key set and turns the sibling files' correct hexes into spurious
  FAILs, pointing the investigation at the wrong files.
- **Both wal templates are valid-but-uncovered, and the checker's own
  header claims the templates are checked.** Every placeholder in
  `config/wal/templates/colors-zed.json` sits inside a quoted string,
  so the template is pure JSON (verified parseable as-is); colors.el is
  18 quoted `setq`s — valid Elisp the existing byte-compile step would
  accept. Neither is in any step. Worse, lint-themes.sh's header
  (:7-8) states templates "are checked separately: every {placeholder}
  must be a name wal exports" — and the word "placeholder" occurs
  nowhere else in the script; its three checks are preset inventory,
  preset hex sync, and the switch-theme cp-list. All five wal templates
  (the render inputs for rofi/emacs/zed/hyprland/neomutt palettes) are
  validated by nothing, so a `{palce0}`-class typo ships silently and
  wal renders it verbatim into the live config.
- **Root cause is structural: the master lists exist in six places.**
  The shell list is duplicated across lint.yml's bash -n step,
  lint.yml's shellcheck step, `.zed/tasks.json` x2 ("Repo: Bash
  syntax", "Repo: Full lint"), `60-update.sh:280-285`, and AGENTS.md's
  lint block; the JSON list across lint.yml, tasks.json x2, and
  60-update.sh:289. Drift between the copies has already started:
  60-update.sh's gate comment (:267) still says "the three //-prefixed
  JSONs" though 13a8857 grew that loop to four files, and AGENTS.md
  step 2 still describes checking "swaync + wlogout" only (zed's two
  JSONs and the postgres .jsonc exist in lint.yml but not in the doc).
  Findings 1-6 are what six hand-synced copies predictably produce; a
  single sourced manifest (or globs where the language allows) removes
  the whole class.

Minor batch: (1) systemd unit files get no `systemd-analyze verify` —
already logged in pass 9's minor batch, not re-litigated here; (2)
lint.yml itself has no YAML parse gate, but GitHub surfaces malformed
workflow YAML as a workflow-file error rather than a red job, so the
failure mode is self-announcing — low value; (3) the remaining types
(.rasi, .css, .scss, .yuck, .toml, .conf, .desktop, the muttrc
examples) have no syntax gate by design — pass 8's swaync selector rot
suggests the CSS family is the weakest uncovered class if a future
pass extends the matrix.

---

## Review pass 11 — Docs accuracy (README.md / AGENTS.md / LICENSE)

Scope: the eleventh and final pass — the docs themselves. The two
doc-owned tables the brief names (README's "What's in this rice", 49
rows, and AGENTS.md's "Components map", 23 rows) plus every behavioral
claim in README.md's prose, AGENTS.md's contracts and layout tree, and
LICENSE, each re-checked against the scripts/configs they describe.
Second half of the brief: a repo-wide sweep for stale TODO /
`@@ TODO @@` / placeholder markers that code has already resolved but
docs never dropped. Method: full read of README.md (2,715 lines) and
AGENTS.md (536), the tracked inventory from `git ls-files` (106
files), then line-level checks of each doc claim against
`scripts/00-base.sh`, `10-aur.sh` `PACKAGES=()`, `30-dotfiles.sh`,
`45-snapshots.sh`, `50-verify.sh`, `hyprland.conf`,
`keybinds-extra.conf`, `zed-handler.desktop`, `zed/settings.json` +
`keymap.json`, `.zed/tasks.json`, `MangoHud.conf`, `ghostty/config`,
`init.el`/`init.lua`, `vlc-open`, `switch-theme.sh`, and
`.github/workflows/lint.yml`. Code-side bugs referenced below stay
owned by their original passes — this pass judges the DOCS against
current reality. Findings-only; only this section changed.

**TODO / placeholder sweep — clean where it should be.** Exactly two
`@@ TODO @@` markers exist in the tree (`hyprland.conf:24` monitors,
`hyprpaper.conf:8` wallpaper) and both are the live, documented
first-boot items (README TODOs #1–#3) — not stale. The remaining
placeholders are intentional and documented as such: neomutt's
`YOUR_GPG_KEY_ID_HERE` (pass 7), the mail-stack `.example` identities,
and `postgres-language-server.jsonc`'s placeholder creds (`:4` says so
out loud). `30-dotfiles.sh:149`'s runtime "wallpaper is a TODO" echo
matches the docs. No resolved-but-unremoved TODO marker found
anywhere.

Verified correct (no action):

- **LICENSE ↔ README**: `## License`'s "MIT — © 2026 Ziad Ibrahim"
  matches LICENSE's copyright line and title exactly.
- **Component table ↔ scripts, row by row.** All 49 rows resolve: every
  "pacman (extra)" package sits in `00-base.sh`'s transactions (steam
  at :129, tmux/lazygit :133, yazi/thunar set :135, vlc/obs/audacity
  :136, yt-dlp/streamlink :137, bitwarden :138, bluez/blueman :139,
  ufw :140, clamav/libnotify/apparmor/firejail :141, LSP seven :172–179,
  DBs :143), every AUR row matches one of `10-aur.sh`'s ten
  `PACKAGES=(...)` entries (:219–230) 1:1 with AGENTS.md's source-build
  table, and every behavioral note holds — bluetooth.service enable
  (:185), ufw baseline (:191–197), freshclam (:203), blueman-applet
  exec-once (hyprland.conf:80), AppArmor's inert-until-cmdline status
  (:206–210), the mpvpaper-default/hyprpaper-fallback split
  (hyprland.conf:83–86), and bibata/cursor + fish-under-ghostty
  (hyprland.conf:218–221, ghostty/config:46).
- **Keybind claims resolve end-to-end.** SUPER+E/R/Z/Y/G/C editor
  launches, SUPER+SHIFT+A/D/I AI CLIs (`$claude_command`/
  `$deepseek_command`/`$kilo_command` exist at keybinds-extra.conf:47–49),
  SUPER+SHIFT+O/U/M, SUPER+V bitwarden, SUPER+SHIFT+T theme cycle (order
  matches `THEMES=(mocha gruvbox tokyonight osaka-jade)`,
  switch-theme.sh:30), SUPER+SHIFT+/ keybind menu, SUPER+SHIFT+E yazi /
  SUPER+SHIFT+F thunar per the component table — all match
  hyprland.conf:269–312 + keybinds-extra.conf:28–64. The free-letter
  comment (keybinds-extra.conf:26) still matches the live bind map.
- **Theme formats**: each preset dir carries exactly the eight formats
  README :236 lists, `colors-neomutt.muttrc` included; lint.yml's
  presence matrix names the same eight (:59, :66).
- **Editor claims**: Zed keymap's Ctrl+Alt+B/R/T/F tasks binds match
  README :750–753; settings.json carries every feature the editor
  section lists (font :15, autosave :18, format-on-save :19, signature
  help :22–23, code_lens :24, inlay hints :26, trailing-whitespace :32);
  Emacs's `C-c w/q/e/b/n` set (init.el:119–123) matches README :805; the
  F2 modal/plain contract exists in all three editors (init.lua:324,
  init.el, keymap.json:8); nvim's FATS/SUPER + Ctrl-O/Ctrl-S/Ctrl-Z
  claims hold (init.lua:287–331).
- **Script-behavior claims**: 50-verify.sh runs exactly the nine [n/9]
  checks AGENTS.md's layout tree states; snapper retention 5 hourly +
  7 daily (45-snapshots.sh:80–84) matches README :573–574; MangoHud's
  Right_Shift HUD toggle (MangoHud.conf:45) matches README :903–904;
  vlc-open's yt-dlp/streamlink split + `streamlink --player vlc`
  (vlc-open:25, 30) and its youtube.lua-distrust header match README
  :87–88; the update-checker's enable line (README :662) names the real
  unit; the mail section's copy-if-absent / chmod-600 / conditional
  vdirsyncer enable all match 30-dotfiles.sh:118–131; the AI-tools
  section matches the exported vars and binds.
- **$. mirroring** — AGENTS.md's components-map rows all point at files
  that exist and own the named concern (re-spot-checked, not just pass
  1's word for it).

What was wrong (and the correct spec) — new this pass:

- **Step 0's clone instructions point at a repo that does not exist.**
  README :385–386 says `git clone
  https://github.com/Fatmanams/Hyprland-Fat-rice-.git` and
  `cd Hyprland-Fat-rice-` — trailing dash. The actual remote (verified
  via `git remote get-url origin` and `gh repo view`) is
  `https://github.com/Fatmanams/Hyprland-Fat-rice` — no trailing dash.
  The very first copy-paste a fresh user runs 404s. Highest-severity
  finding in the pass. Correct spec: drop the trailing `-` in both
  lines. Resolved in fix/step0-clone-url.
- **README's two keybind lists disagree about SUPER+SHIFT+E, and the
  code sides with the component table.** The bindings list (:834) says
  "SUPER + SHIFT + E — Open Thunar (was SUPER+E before Zed won it)".
  The code binds `$mod SHIFT, E` to `$files` = yazi
  (hyprland.conf:279, keybinds-extra.conf:40) and Thunar to
  `$mod SHIFT, F` (hyprland.conf:280, `$gui_files` at :41) — which is
  exactly what the component table already says (:89–90). The :834 row
  is stale from the pre-yazi layout. Correct spec: SUPER+SHIFT+E opens
  the TUI file manager (yazi); Thunar is SUPER+SHIFT+F.
- **"You can run each script at most once" (:456) contradicts the same
  README's update pipeline.** :632–633 documents 60-update.sh phase 6
  as "re-runs `00-base.sh` → `45-snapshots.sh` in order" on every
  update, and pass 2 verified re-run idempotency is a designed
  property of the stateful steps. The sentence as written tells a
  reader never to re-run anything, which would make updates
  impossible. Correct spec: drop it or reword to "safe to re-run; the
  update pipeline does exactly that" (it is the install steps' one-
  shot *necessity*, not a cap, that was presumably meant).
- **The `## Tree` diagram has drifted further than pass 8 recorded.**
  Pass 8's minor batch logged the missing `rofi/keybind-menu.cpp`,
  mail-stack dirs, `clamav/`, `systemd/user/`, `zed/keymap.json`, and
  `wal/templates/colors-neomutt.muttrc` — all still absent. New since
  that note and unlogged anywhere: the `scripts/` block ends at
  `50-verify.sh` (:2657) — `60-update.sh`, `61-rollback.sh`,
  `install-zed.sh`, `lint-themes.sh`, and `scripts/lib/rice-version.sh`
  (5 of the 12 script files, i.e. the entire update/rollback pipeline
  the README's own Updates section describes) have no entries; and the
  top level omits `.zed/tasks.json` and `postgres-language-server.jsonc`
  (both referenced elsewhere in the README). Correct spec when the
  Tree is next touched: regenerate it from `git ls-files` instead of
  by hand.
- **AGENTS.md's Repository layout omits four tracked paths.** LICENSE,
  `postgres-language-server.jsonc`, and
  `config/wal/templates/colors-neomutt.muttrc` were logged in pass 1's
  governance section and remain absent; pass 11 adds a fourth not
  previously named: `.github/workflows/lint.yml` — despite the README
  Tree carrying it (:2649) and the lint/verify section being ABOUT it.
- **AGENTS.md's lint/verify section documents 5 checks; lint.yml runs
  8 named steps.** Missing from the doc: shellcheck (error severity),
  the emacs byte-compile glob, the preset format-presence matrix, and
  the luajit parse; and step 2's jq set still reads "swaync + wlogout"
  (:243–245) while CI parses four `//`-prefixed JSONs (swaync, zed
  settings, zed keymap, postgres-language-server.jsonc) plus wlogout
  under `-s`. This is pass 10's structural finding (the master lists
  exist in six places) observed from the docs side.
- **The README promises a cpupower governor prompt the script never
  shows.** Install-step-1 comment (:414–416): "Two interactive prompts
  near the end: the CPU `performance` governor ... and the OPTIONAL
  emacs-wayland install. Both default to no." Only the Emacs prompt
  exists (00-base.sh:323, correctly `[y/N]`). The governor block
  (00-base.sh:243–301) contains no `read` at all — it installs
  cpupower (:270), writes `governor='performance'` (:293–297), and
  enables the service (:299) unconditionally. Pass 3 sighted this and
  deferred it to pass 2's script-logic window; pass 2 didn't log it,
  so it lands here, its rightful docs window. Correct spec: either the
  prompt the README promises or a README rewrite saying the governor
  is applied unconditionally (with the laptop caveat kept).
- **README overstates 50-verify.sh's coverage.** :447 says it reports
  "first-boot TODOs cleared" — no such check exists; [1/9] verifies
  monitor/wallpaper *line presence* only, and nothing probes
  wallpaper.jpg, the NVIDIA cmdline, or AppArmor's `lsm=` (pass 3,
  still unfixed — re-confirmed against the nine banners).
- **README overstates the ClamAV timer's enablement and cadence.**
  :108–110: "`30-dotfiles.sh` enables a daily user timer" — the script
  prompts `[y/N]` and defaults to leaving it disabled
  (30-dotfiles.sh:118–122; pass 3's "offers to enable" is the accurate
  wording), and "daily" is doubly wrong: the timer is
  OnBootSec+OnUnitActiveSec with a dead `Persistent=` (pass 9).
- **GPU-vendor detection overclaims the prompt.** :279–281 says
  00-base.sh "installs the right driver stack with a single
  confirmation prompt". Only the NVIDIA branch prompts
  (00-base.sh:220, `[Y/n]`); the Intel/AMD stack installs
  unconditionally (:233–241) with no prompt — on the *majority* vendor
  path there is nothing to confirm.
- **zed-handler "covers JavaScript" — declared, never registered.**
  README :679 says the handler covers "C headers, JavaScript, TOML,
  YAML, markdown, shell, plaintext". `zed-handler.desktop:9` does
  declare the JS/TS MimeTypes, but the session actually defaults only
  the types in hyprland.conf's `xdg-mime default` exec-once
  (:137–148), which names no JavaScript/TypeScript entry. Declared
  candidate ≠ default handler; JS/TS files get no rice-registered
  opener. Correct spec: extend the exec-once list to the JS/TS types
  the .desktop already declares, or drop JavaScript from the README
  sentence.
- **The F2 bindings-table row predates the Zed contract.** :839 reads
  "F2 (in nvim/emacs)" — Zed got the same toggle in
  config/zed/keymap.json:8, which this README's own editor section
  documents at :691–696. One-word fix, "nvim/emacs/zed".
- **`## Contents` is missing entries and lags the audit history.**
  "## Updates and fail-safe rollback" (:602) — a full H2 — has no
  Contents line, and the audit subsection bullets (:35–37) stop at
  pass 2, so passes 3–10 (and now 11) are reachable only by scrolling.
  Convention note: the lag grew one section per pass because no pass
  touches the TOC; this finding inherits that.

Still accurate, still unfixed — doc-side drift earlier passes logged,
re-confirmed unfixed at e6511a6, cross-referenced not re-litigated:

- Stale package names in prose/comments: `rofi-wayland` (README :58,
  :148; AGENTS.md :71; 10-aur.sh :75), `swww` (README :59, :150),
  `nvidia`/`nvidia-dkms` gotcha wording (README :327–336;
  00-base.sh :218–229), `NetworkManager` mis-casing (00-base.sh :118),
  `mesa-vdpau` + `libva-mesa-driver` (00-base.sh :239), the
  `python-pywal` framing (AGENTS.md :73; 10-aur.sh :77) — pass 1, both
  halves. The component table stays consistent with the code; the code
  is what targets the dead names.
- `sudoedit -e nano` (README :854; endorsed by AGENTS.md :489;
  hyprland.conf :55's `sudoedit -f -e nano` variant) — invalid
  invocation per sudo(8), pass 1 governance.
- README's source-build inventory is 9 rows vs 10 `PACKAGES=()`
  entries — `chkrootkit` still missing (:133–143), breaking the rule-5
  contract AGENTS.md :509–510 states — pass 1 governance.
- The orphaned "`gamemode`, `gamescope`, ..." bullet stranded inside
  "### Keybind customization" (:213) — pass 1 governance.
- README first-boot TODO #3 (:500–503) documents hyprpaper's flat
  `wallpaper = <monitor>, ...` form, dead against current hyprpaper
  upstream — pass 4; the doc half of that finding lives in this pass's
  window (the `@@ TODO @@` marker itself stays legitimate — it's the
  per-monitor syntax next to it that broke).
- hyprland.conf :13's palette header describes the nonexistent
  `common.<theme>` mechanism — pass 8. Read this file's header with
  pass 8's correction, not as-is.
- README's LSP row (:79, "used by Zed + Emacs/eglot") and the editor
  section's "system language servers ... remain the source of truth"
  (:702–703) overstate Zed's side — pass 6 showed Zed falls back to
  downloading basedpyright/ruff/vtsls rather than using the PATH
  pyright/typescript-language-server.
- The mail section names only the legacy `crypt_autosign` spelling
  (:171–173) and its placeholder-TODO sentence covers signing but not
  opportunistic encryption — pass 7.
- `init.el`'s `[8/8]`/`[4/8]` step references (:9, :21) point at a
  numbering the script never prints; 00-base.sh's own banners mix /8
  and /9 (:39, :57 vs :100–333) — passes 1/2/6.
- AGENTS.md's systemd/user layout entry (:166) and components-map rows
  (:285–286) name clamav-scan and rice-update-check but not
  `vdirsyncer-google.*` — pass 9 minor batch.
- NVIDIA cmdline docs (README :313–317; hyprland.conf :241–242)
  require `nvidia_drm.fbdev=1`, default-on since driver 570.86.16 —
  pass 4.

Minor batch, one line each:

- hyprland.conf :4's header says "review the optional TODOs ...
  marked `@@ TODO @@`" (plural); the file carries exactly one marker
  (:24) — the second lives in hyprpaper.conf :8, a different file.
- README :748–750 enumerates five .zed/tasks.json task groups; the
  file ships seven — "Repo: C++ syntax" and "Repo: Theme sync
  (lint-themes)" go unmentioned.
- hyprland.conf :301's `# Logout menu (wlogout).` header sits directly
  above the SUPER+SHIFT+N mail bind; the wlogout bind is nine lines
  lower (:309) — comment placement, not behavior.
- AGENTS.md's authoring-box note (:7–8) says paths "may show
  `D:\linux rice`"; the current checkout is `D:\hhhy\Hyprland-Fat-rice`
  — the hedge word "may" keeps it technically true; noted only because
  this pass exists to catch exactly this class.

---

## Tree

```
linux-rice/
├── README.md                                this
├── AGENTS.md                                the agent-facing contract (read it first when editing)
├── LICENSE                                  MIT
├── .gitignore
├── .gitattributes                           forces LF line endings
├── .github/workflows/lint.yml               CI: bash -n, shellcheck, jq, emacs byte-compile, luajit parse, preset matrix
├── scripts/
│   ├── 00-base.sh                          official-repo install + makepkg.conf
│   ├── 10-aur.sh                           reviewed-PKGBUILD builds + repo-add
│   ├── 20-sddm.sh                          bare git clone + rollback snapshot
│   ├── 30-dotfiles.sh                      copies config/ into ~/.config (backup first)
│   ├── 40-gaming.sh                        verifies gaming extras + templates
│   ├── 45-snapshots.sh                     snapper on btrfs / timeshift-rsync elsewhere (picks by root fs)
│   └── 50-verify.sh                        read-only post-deploy health check (PASS/FAIL, never fixes)
└── config/
    ├── hypr/
    │   ├── hyprland.conf                   compositor config (multi-monitor wildcard)
    │   ├── hyprpaper.conf                  static wallpaper FALLBACK (all outputs)
    │   ├── start-mpvpaper.sh               one animated wallpaper process per output
    │   ├── hypridle.conf                   idle / lock / suspend listeners
    │   ├── keybinds-extra.conf             populated defaults; user-editable bind assignments
    │   ├── switch-theme.sh                 preset palette switcher (SUPER+SHIFT+T cycles)
    │   ├── themes/{mocha,gruvbox,tokyonight,osaka-jade}/  pre-generated pywal-format palettes (eight formats each)
    │   └── gpu-env.sh                      NVIDIA/Intel/AMD auto-detect env vars (source from shell rc)
    ├── nvim/
    │   ├── init.lua                         single-file nvim IDE: lazy.nvim specs inline, pywal-driven, FATS/SUPER
    │   └── lazy-lock.json                   pinned plugin commits (lazy.nvim-generated, committed)
    ├── emacs/
    │   └── init.el                          opt-in single-file Emacs config; eglot for LSP
    ├── croft/                               optional Croft TUI launcher
    ├── neovide/                             GPU Neovim GUI settings; inherits nvim palette
    ├── ox/                                  pywal-rendered Ox Lua config + launcher
    ├── neomacs/                             optional GPU Emacs launcher
    ├── waybar/
    │   ├── config                          top bar layout
    │   └── style.css                       pywal16 @import colors
    ├── swaync/
    │   ├── config.json                     notification center + widgets
    │   └── style.css                       pywal16 @import colors
    ├── rofi/
    │   └── config.rasi                      drun/run/window launcher
    ├── eww/
    │   ├── eww.yuck                        tiny demo widget
    │   └── eww.scss                        pywal16 @import colors
    ├── wlogout/
    │   ├── layout                          6 fields: lock/logout/suspend/hibernate/reboot/shutdown
    │   └── style.css                       pywal16 @import colors
    ├── ghostty/
    │   ├── config                          primary terminal; baked Mocha = pre-wal fallback
    │   └── ghostty-theme.sh                wal colors.sh -> ghostty colors.conf (+reload-config)
    ├── MangoHud/
    │   └── MangoHud.conf                   gaming HUD config
    ├── zed/
    │   └── settings.json                   theme "Pywal" (wal-generated) + Nerd font + autosave
    ├── vlc/
    │   ├── vlc-open                        URL -> resolve (yt-dlp/streamlink) -> play in VLC (SUPER+SHIFT+M)
    │   └── vlcrc                           minimal; defaults left alone (see file comments)
    ├── wal/
    │   └── templates/
    │       ├── colors-rofi.rasi            custom pywal template -> ~/.cache/wal/colors-rofi.rasi
    │       ├── colors.el                   custom pywal template -> ~/.cache/wal/colors.el (emacs)
    │       ├── colors-zed.json             custom pywal template -> ~/.cache/wal/colors-zed.json (zed)
    │       └── colors-hyprland.conf        custom pywal template -> ~/.cache/wal/colors-hyprland.conf (borders)
    └── applications/
        └── zed-handler.desktop             xdg-mime default for python/c/c++/lua/java/rust/json
```

---

## License

MIT — © 2026 Ziad Ibrahim. See [`LICENSE`](LICENSE).
