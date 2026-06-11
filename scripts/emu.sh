#!/usr/bin/env bash
# Reliable Android emulator launch for this 2017 Intel Mac (Iris Plus 640, 8 GB).
#
# Why these flags:
#   -gpu swiftshader_indirect : software Vulkan/GLES. The host Intel GPU lacks the
#                               Vulkan feature (VulkanVirtualQueue) the default
#                               'auto' renderer needs on API 36 — that was the
#                               "crashes while loading" cause.
#   -no-snapshot              : cold boot, ignore Quick-Boot snapshots (a corrupt
#                               snapshot also crashes on load).
#   -no-boot-anim             : small CPU/RAM saving on a dual-core machine.
set -euo pipefail

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AVD="${1:-clustez}"

# Free RAM: kill any stray emulator first (8 GB is tight).
pkill -f qemu-system 2>/dev/null || true

# -feature -Vulkan : host Iris 640 can't do hardware Vulkan, so the guest was
#                    falling back to *software* Vulkan (CPU-pegging on 2 cores).
#                    Disabling it makes HWUI use Skia-GLES, which IS hardware-
#                    accelerated here via ANGLE->Metal. Verified: debug.hwui.renderer=skiagl.
# -no-audio        : trims overhead. Resolution lowered to 720x1280 in config.ini.
exec "$SDK/emulator/emulator" -avd "$AVD" \
  -gpu swiftshader_indirect \
  -feature -Vulkan \
  -no-audio \
  -no-boot-anim \
  "${@:2}"
