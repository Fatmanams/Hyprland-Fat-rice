# zed-workspace -- first-launch sample project

`install.ps1` copies this folder into your Documents (default:
`Documents\zed-workspace`) and opens it in Zed once, so that:

- the extensions listed in the deployed `settings.json`
  (`auto_install_extensions`) install themselves on startup, and
- each language's server downloads in the background the first time a
  file of that language is opened (rust-analyzer for Rust, clangd for
  C/C++, Pyright for Python, lua-language-server for Lua).

The downloads show up in Zed's status bar while they run; the editor
is usable immediately.

## What is here

| Path              | Language | Build / run                                     |
|-------------------|----------|-------------------------------------------------|
| `src/main.c`      | C        | `cmake -S . -B build` then `cmake --build build` |
| `src/main.cpp`    | C++      | same CMake build (VS generator on Windows)     |
| `rust/hello.rs`   | Rust     | `cargo run` (from a cargo project) or open file |
| `python/hello.py` | Python   | `python python/hello.py`                       |
| `lua/hello.lua`   | Lua      | `luajit lua/hello.lua`                          |

The C/C++ targets build with the MSVC toolchain that the installer
deploys (Visual Studio 2022 Build Tools); CMake picks the Visual
Studio generator on Windows automatically, so no developer prompt is
needed. Debug launch presets for both CMake layouts live in the
global `debug.json` the installer deployed.

## Try the workflow

1. Open one of the sample files and wait for the language server to
   download (bottom status bar).
2. `Ctrl+Alt+B` opens the task picker: "Python: run file",
   "Lua: run file (luajit)", "StyLua: format file", "ruff: check
   file" and friends are global tasks from the deployed `tasks.json`.
3. `F2` toggles Zed's native vim mode (same modal/plain contract as
   the rice's nvim/Emacs setups).

This workspace is yours: edit it, delete it, or replace it with a real
project once the downloads have finished.
