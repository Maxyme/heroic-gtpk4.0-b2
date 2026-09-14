#!/usr/bin/env python3
"""
GPTK 4.0 DLL Binary Patcher for Apple GPTK Wine (Wine 7.7)
Fixes STATUS_DLL_INIT_FAILED (0xc0000142) by:
  1. Replacing '__wine_unix_call_dispatcher' with '__wine_unix_call' (null-padded)
  2. Patching dereference 'movq (%rsi), %rax' (48 8b 06) -> direct assignment 'movq %rsi, %rax' (48 89 f0)
"""

import os
import sys
import glob
import argparse

DLL_TARGETS = [
    "d3d10.dll",
    "d3d11.dll",
    "d3d12.dll",
    "dxgi.dll",
    "nvapi64.dll",
    "nvngx-on-metalfx.dll"
]

OLD_STR = b"__wine_unix_call_dispatcher\x00"
NEW_STR = b"__wine_unix_call\x00" + (b"\x00" * 11)  # 28 bytes total

OLD_OPCODE = b"\x48\x8b\x06"  # movq (%rsi), %rax
NEW_OPCODE = b"\x48\x89\xf0"  # movq %rsi, %rax


def find_default_dmg():
    matches = glob.glob("/Volumes/Game Porting Toolkit*")
    return matches[0] if matches else None


def patch_file(src_path, dst_path):
    with open(src_path, "rb") as f:
        data = f.read()

    str_count = data.count(OLD_STR)
    op_count = data.count(OLD_OPCODE)

    patched = data.replace(OLD_STR, NEW_STR)
    patched = patched.replace(OLD_OPCODE, NEW_OPCODE)

    with open(dst_path, "wb") as f:
        f.write(patched)

    return str_count, op_count


def main():
    parser = argparse.ArgumentParser(description="Patch GPTK 4.0 DLLs for Wine 7.7 compatibility")
    parser.add_argument("--dmg", help="Path to mounted GPTK DMG volume", default=None)
    parser.add_argument("--out", help="Output directory for patched DLLs", default="./patched_dlls")
    args = parser.parse_args()

    dmg_path = args.dmg or find_default_dmg()
    if not dmg_path or not os.path.isdir(dmg_path):
        print("[!] Error: GPTK DMG volume not found. Please mount the DMG or provide --dmg <path>", file=sys.stderr)
        sys.exit(1)

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)

    print(f"[*] Reading from DMG: {dmg_path}")
    print(f"[*] Output directory: {out_dir}\n")

    success_count = 0
    for dll_name in DLL_TARGETS:
        matches = glob.glob(f"{dmg_path}/**/{dll_name}", recursive=True)
        if not matches:
            print(f"[-] Warning: '{dll_name}' not found in DMG. Skipping.")
            continue

        src = matches[0]
        dst = os.path.join(out_dir, dll_name)
        str_count, op_count = patch_file(src, dst)
        print(f"[+] {dll_name}:")
        print(f"    - String '__wine_unix_call_dispatcher' replaced: {str_count} time(s)")
        print(f"    - Opcode '48 8b 06' -> '48 89 f0' replaced: {op_count} time(s)")
        success_count += 1

    print(f"\n[✓] Successfully patched {success_count}/{len(DLL_TARGETS)} DLLs to '{out_dir}'")


if __name__ == "__main__":
    main()
