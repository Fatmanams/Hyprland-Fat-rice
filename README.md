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
| Launcher         | rofi-wayland        | pacman (extra)          | was AUR-only, moved upstream |
| Wallpaper        | swww                 | pacman (extra)          | was AUR-only, moved upstream |
| Animated wallpaper | mpvpaper           | **AUR — makepkg'd**     | default; hyprpaper kept as static fallback |
| Wall daemon      | hyprpaper            | pacman (extra)          | static fallback config |
| Clipboard        | cliphist + wl-clipboard | pacman (extra)       |       |
| Idle / lock      | hypridle + hyprlock  | pacman (extra)          |       |
| Color theming    | python-pywal16       | **AUR — makepkg'd**     |       |
| Widgets          | eww                  | **AUR — makepkg'd**     | tiny demo widget alongside waybar |
| Cursor theme     | bibata-cursor-theme  | **AUR — makepkg'd**     | Modern variant, 24px |
| Logout menu      | wlogout              | **AUR — makepkg'd**     |       |
| Terminal         | ghostty              | pacman (extra)          | primary; shell = fish (pacman) |
| Code editor      | zed                  | **AUR — makepkg'd**     | primary $EDITOR + $CODE for python/c/c++/lua/java/rust/json; theme "Pywal" generated from wal (catppuccin ext kept as cold-boot fallback) |
| GUI code editor   | lapce                | pacman (extra)          | optional Rust editor with built-in LSP, terminal, remote development, and Vim mode |
| Terminal editor   | croft                | upstream cargo install  | optional VS Code-style TUI; no Arch/AUR package, launcher gives the reviewed upstream command |
| Quick editor     | neovim              | pacman (extra)          | terminal IDE: lazy.nvim plugins (lspconfig / treesitter / cmp / telescope / nvim-tree), pywal-driven colors, FATS/SUPER mode (F2) |
| Neovim GUI       | neovide              | pacman (extra)          | GPU-accelerated Neovim client; inherits the pywal-driven Neovim palette |
| Terminal editor  | ox                  | **AUR — review required** | lightweight TUI editor; Ox config is generated from the active pywal16 palette; verify `ox-bin` availability before running the AUR stage |
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
| `zed`                  | `<https://aur.archlinux.org/zed.git>`    | **Review carefully**: large Rust project, many cargo crates, may pull release assets during build |
| `ox-bin`               | `<https://aur.archlinux.org/ox-bin.git>` | Requested prebuilt Ox binary; verify the package exists before approval. `ox-git` is the source-build alternative. |
| `neomacs-bin`          | `<https://aur.archlinux.org/neomacs-bin.git>` | Prebuilt experimental GPU Emacs fork; review release URLs, checksums, and install paths before approval. |
| `helium-browser-bin`   | `<https://aur.archlinux.org/helium-browser-bin.git>` | Precompiled Helium (imputnet chromium fork), repackaged from the upstream release tarball — verified WITH its `.asc` via `validpgpkeys` (Helium signing key), plus two sha256-pinned local patches. No build(), no hooks, no curl\|bash. |
| `mpvpaper`             | `<https://aur.archlinux.org/mpvpaper.git>` | Video wallpaper daemon (v1.9). Pinned GitHub release tarball with b2sum, meson/ninja build, deps libmpv + libwayland (mpv auto-pulled by makepkg -s), optdep socat. No install hooks, no curl\|bash, no red flags. |
| `vscode-langservers-extracted` | `<https://aur.archlinux.org/vscode-langservers-extracted.git>` | HTML/CSS/JSON/ESLint language servers (v4.10.0), used by Zed and Emacs' eglot. Source is the upstream npm registry tarball pinned with a sha256sum; `package()` is `npm i -g` into `$pkgdir` with the npm cache confined to `$srcdir`, plus chown + license install. No `build()`, no install hooks, no curl\|bash. It vendors node_modules — inherent to the npm tarball, not added by the PKGBUILD. |

**Packages you originally listed as AUR-only that are now in official
repos** — these are installed by `scripts/00-base.sh`, **not** built:

- `rofi-wayland` — in `extra`
- `ghostty` — in `extra`
- `swww` — in `extra`
- `swaync` — in `extra`
- `cliphist` — in `extra`
- `nwg-look` — in `extra`
- `kvantum` and `kvantum-qt5` — in `extra`

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
resolved) and opens the selected one at its file:line in `zed --wait`;
the menu binary is rebuilt from `config/rofi/keybind-menu.cpp` by every
`30-dotfiles.sh` run.
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
  windows (its baked Mocha palette is only the pre-wal fallback). Zed
  follows too: every mode lands `colors-zed.json` in `~/.cache/wal/`,
  which is symlinked to `~/.config/zed/themes/pywal.json` and
  hot-reloaded as the "Pywal" theme. Window borders follow too —
  `hyprland.conf` ends with `source = ~/.cache/wal/colors-hyprland.conf`,
  so any palette change repaints them live. VLC isn't themed by
  presets (by design), and GTK/Qt apps use nwg-look / kvantum profiles
  which are manual picks, not wal-driven.

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
git clone https://github.com/Fatmanams/Hyprland-Fat-rice-.git
cd Hyprland-Fat-rice-
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
#    hardware, ufw/clamav-freshclam/bluetooth live, SDDM snapshot on
#    disk, every theme preset carrying all eight pywal formats, and the
#    snapshot tooling live (snapper timers on btrfs, cronie otherwise —
#    same branch 45-snapshots.sh took). Best run after one Hyprland
#    session has booted.
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
   the path read by both `hyprpaper.conf`'s preload= AND the `wal -i`
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
   `hyprpaper.conf` uses `wallpaper = , ...` to cover every output. Replace
   it with one `wallpaper = <monitor>, ...` line per monitor if displays
   need different images.

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
| `SUPER + C`        | Open croft in Ghostty (prints the install hint if missing) |
| `SUPER + SHIFT + E`| Open Thunar (was SUPER+E before Zed won it)  |
| `SUPER + SHIFT + T`| Cycle theme preset (mocha/gruvbox/tokyonight/osaka-jade) |
| `SUPER + V`        | Open Bitwarden                               |
| `SUPER + SHIFT + M`| Prompt for a URL in rofi, play it in VLC (YouTube etc. resolved by yt-dlp, Twitch by streamlink — see `config/vlc/vlc-open`) |
| `SUPER + SHIFT + /`| Browse every Hyprland keybind in rofi ($vars resolved); Enter opens the selected bind's file:line in `zed --wait` |
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
