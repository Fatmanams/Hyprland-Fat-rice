#!/usr/bin/env bash
# gpu-env.sh — app-level env vars for the rice. Source from your shell rc:
#
#     # in ~/.zshrc or ~/.bashrc, near the top:
#     if [ -f ~/.config/hypr/gpu-env.sh ]; then
#         . ~/.config/hypr/gpu-env.sh
#     fi
#
# This file AUTO-DETECTS the running GPU at shell start and only sets
# the env vars that matter for that vendor. Adding/removing env vars
# affects what's inherited by games launched from Steam/Proton, native
# Vulkan games, and any CLI tool that respects $LIBVA_DRIVER_NAME,
# $MESA_*, $NV_*, $__GL_*, $VK_* etc.
#
# Detection: looks for the running GPU by parsing `lspci` (run once below;
# plain output, NOT `lspci -nn` — with -nn the class code is inserted
# between the controller name and the colon ("VGA compatible controller
# [0300]: ..."), which breaks name-based greps).
# Both `lspci` and `glxinfo` are installed by 00-base.sh (pciutils is
# a base dep; glxinfo comes from `mesa-demos` — added to 00-base).

gpu_env_loaded=0

# ---- Detect vendor ------------------------------------------------------
# One lspci call per shell start; vendor detection and the GPU-count check
# below both grep this same capture.
pci=""
if command -v lspci >/dev/null 2>&1; then
    pci=$(lspci)
fi

gpu_vendor() {
    local line
    line=$(printf '%s\n' "$pci" | grep -Ei '(VGA compatible controller|3D controller|Display controller)' || true)
    if printf '%s\n' "$line" | grep -qi NVIDIA; then
        echo nvidia
    elif printf '%s\n' "$line" | grep -qi 'Advanced Micro Devices'; then
        echo amd
    elif printf '%s\n' "$line" | grep -qi Intel; then
        echo intel
    else
        echo unknown
    fi
}

VENDOR=$(gpu_vendor)

# ---- Common (any GPU) ---------------------------------------------------
# DRI_PRIME=1 only makes sense on PRIME/hybrid setups (iGPU + dGPU). On a
# single-GPU box it can point apps at a render node that doesn't exist, so
# only export it when lspci reports more than one GPU controller.
gpu_count=$(printf '%s\n' "$pci" | grep -cEi '(VGA compatible controller|3D controller|Display controller)' || true)
unset DRI_PRIME
if [ "$gpu_count" -gt 1 ]; then
    export DRI_PRIME=1                          # honour PRIME offload (hybrid laptops/desktops)
fi
unset gpu_count
# (Previously had `VK_ICD_FILENAMES_ALL_KNOWN=1` here — that's not a real
# Vulkan loader env var per Khronos's loader docs at
# https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderInterfaceArchitecture.md
# The real ICD env vars are VK_ICD_FILENAMES (deprecated),
# VK_DRIVER_FILES, VK_ADD_DRIVER_FILES. Removed because the line was
# doing nothing — Steam's runtime already handles ICD selection, and
# adding the real ones would force-select a single driver and break PRIME)

# ---- NVIDIA-specific -----------------------------------------------------
if [ "$VENDOR" = nvidia ]; then
    # Frame pacing + threaded GL optimisations (mostly win for Proton/VK):
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_GSYNC_ALLOWED=1
    export __GL_VRR_ALLOWED=1
    # VDPAU/VAAPI routing (NVIDIA):
    export VDPAU_DRIVER=nvidia
    export LIBVA_DRIVER_NAME=nvidia
    # Proton/Vulkan picks the right ICD automatically since Steam ships its
    # own loader overrides; we leave VK_ICD_FILENAMES unset so mesa/nvidia
    # both can co-register when running PRIME.

# ---- AMD/Intel (Mesa) ----------------------------------------------------
elif [ "$VENDOR" = amd ] || [ "$VENDOR" = intel ]; then
    # NOTE: Mesa env var names are all-caps per the Mesa docs at
    # https://docs.mesa3d.org/envvars.html — earlier versions of this
    # file used mixed-case `Mesa_*` vars that Mesa silently ignored,
    # AND used `MESA_GLSL_CACHE_DIR` which is not real (the actual
    # var is `MESA_SHADER_CACHE_DIR`).
    export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"  # real var per Mesa docs
    export MESA_SHADER_CACHE_MAX_SIZE=2G                          # generous for game loads
    # If you specifically need GL version spoofing for an old game,
    # uncomment: export MESA_GL_VERSION_OVERRIDE=4.6
    # (Don't export it by default — Mesa reports the real version to apps
    # that probe, and lies confuse game engine detection more than help.)

    if [ "$VENDOR" = intel ]; then
        export LIBVA_DRIVER_NAME=iHD              # Broadwell+; on Haswell use i965
        export VDPAU_DRIVER=va_gl
    else
        export LIBVA_DRIVER_NAME=radeonsi         # Mesa VA-API on AMD
        export VDPAU_DRIVER=radeonsi              # fallback if VPDU hits
        # (Previously exported the bogus `radeonsi_shader_cache_enable` —
        # not a real env var. Mesa's shader cache is controlled by the
        # MESA_SHADER_CACHE_* vars above; this AMD-specific one was no-op.)
    fi
fi

unset -f gpu_vendor
unset pci
gpu_env_loaded=1
