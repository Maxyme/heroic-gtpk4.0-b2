#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEROIC_TOOLS="$HOME/Library/Application Support/Heroic/tools/wine"
TARGET_RUNNER="$HEROIC_TOOLS/GPTK-4.0-Beta"
PATCHED_DLL_DIR="$SCRIPT_DIR/patched_dlls"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   GPTK 4.0 Beta 2 -> Heroic Wine Runner Installer    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[!] Error: python3 is not installed or not in PATH.${NC}"
    exit 1
fi

# 2. Check for mounted GPTK DMG
echo -e "\n${BLUE}[1/5] Checking for mounted GPTK DMG...${NC}"
DMG_PATH=$(find /Volumes -maxdepth 1 -name "Game Porting Toolkit*" 2>/dev/null | head -n 1)

if [ -z "$DMG_PATH" ]; then
    echo -e "${RED}[!] Error: No mounted Game Porting Toolkit DMG found in /Volumes.${NC}"
    echo -e "${YELLOW}Please double-click and mount your 'Game Porting Toolkit 4.0 Beta 2' DMG first, then re-run this script.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Found mounted DMG at:${NC} $DMG_PATH"

# 3. Locate existing Apple GPTK Wine base (prioritizing GPTK-3.0-3)
echo -e "\n${BLUE}[2/5] Locating base Apple GPTK Wine runner in Heroic...${NC}"
BASE_RUNNER=""

# Check for GPTK-3.0-3 first
if [ -d "$HEROIC_TOOLS/GPTK-3.0-3" ]; then
    BASE_RUNNER="$HEROIC_TOOLS/GPTK-3.0-3"
elif [ -d "$HEROIC_TOOLS" ]; then
    for candidate in "$HEROIC_TOOLS"/*GPTK* "$HEROIC_TOOLS"/*gptk* "$HEROIC_TOOLS"/*Game-Porting-Toolkit*; do
        if [ -d "$candidate" ] && [ "$candidate" != "$TARGET_RUNNER" ]; then
            BASE_RUNNER="$candidate"
            break
        fi
    done
fi

# Check Homebrew default location if not in Heroic tools
if [ -z "$BASE_RUNNER" ] && [ -d "/usr/local/opt/game-porting-toolkit" ]; then
    BASE_RUNNER="/usr/local/opt/game-porting-toolkit"
fi

# Fallback: prompt user if not automatically found
if [ -z "$BASE_RUNNER" ]; then
    echo -e "${YELLOW}[?] Could not automatically find an Apple GPTK Wine runner (e.g. GPTK-3.0-3).${NC}"
    echo -e "Enter the path to your Apple GPTK base runner folder:"
    read -r user_base
    if [ -d "$user_base" ]; then
        BASE_RUNNER="$user_base"
    else
        echo -e "${RED}[!] Error: Specified path does not exist.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[✓] Base runner detected:${NC} $BASE_RUNNER"

# 4. Create GPTK-4.0-Beta runner
echo -e "\n${BLUE}[3/5] Creating dedicated runner 'GPTK-4.0-Beta'...${NC}"
mkdir -p "$HEROIC_TOOLS"

if [ -d "$TARGET_RUNNER" ]; then
    echo -e "${YELLOW}[!] Warning: $TARGET_RUNNER already exists.${NC}"
    read -p "Overwrite existing GPTK-4.0-Beta runner? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TARGET_RUNNER"
        cp -R "$BASE_RUNNER" "$TARGET_RUNNER"
    else
        echo -e "[*] Keeping existing base files, proceeding to update components..."
    fi
else
    cp -R "$BASE_RUNNER" "$TARGET_RUNNER"
fi
echo -e "${GREEN}[✓] Runner structure ready at:${NC} $TARGET_RUNNER"

# 5. Patch GPTK 4.0 Windows DLLs
echo -e "\n${BLUE}[4/5] Patching GPTK 4.0 Windows DLLs for ABI compatibility...${NC}"
python3 "$SCRIPT_DIR/patch_gptk.py" --dmg "$DMG_PATH" --out "$PATCHED_DLL_DIR"

# 6. Copy native frameworks & patched DLLs into the runner
echo -e "\n${BLUE}[5/5] Injecting GPTK 4.0 libraries into runner...${NC}"

# Ensure lib directories exist
mkdir -p "$TARGET_RUNNER/lib"
mkdir -p "$TARGET_RUNNER/lib/wine/x86_64-windows"

# Copy native macOS frameworks
echo "[*] Copying D3DMetal.framework and libd3dshared.dylib..."
cp -R "$DMG_PATH/redist/lib/D3DMetal.framework" "$TARGET_RUNNER/lib/"
cp "$DMG_PATH/redist/lib/libd3dshared.dylib" "$TARGET_RUNNER/lib/"

# Copy patched Windows DLLs
echo "[*] Copying patched PE DLLs to runner windows library directory..."
cp "$PATCHED_DLL_DIR"/*.dll "$TARGET_RUNNER/lib/wine/x86_64-windows/"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}  ✓ GPTK 4.0 Beta 2 has been successfully installed!  ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "\n${BLUE}How to use in Heroic Games Launcher:${NC}"
echo -e "1. Restart Heroic (Quit with Cmd+Q and relaunch)."
echo -e "2. Go to your game's ${YELLOW}Settings (gear icon) > Wine${NC}."
echo -e "3. Under ${YELLOW}Wine Version${NC}, select: ${GREEN}GPTK-4.0-Beta${NC}"
echo -e "4. In ${YELLOW}Environment Variables${NC}, add the following:"
echo -e "     ${YELLOW}ROSETTA_ADVERTISE_AVX${NC} = 1"
echo -e "     ${YELLOW}D3DM_ENABLE_METALFX${NC}   = 1"
echo -e "     ${YELLOW}D3DM_SUPPORT_DXR${NC}      = 1"
echo -e "     ${YELLOW}D3DM_MTL4${NC}             = 1"
echo -e "     ${YELLOW}WINEDLLOVERRIDES${NC}      = d3dcompiler_47=n,b"
echo -e ""
echo -e "${BLUE}For Unreal Engine 5 titles (Fix Slate Shader Crash):${NC}"
echo -e "Run winetricks on your prefix to install native d3dcompiler_47:"
echo -e "     ${YELLOW}WINEPREFIX=\"<path_to_game_prefix>\" winetricks d3dcompiler_47${NC}"
echo -e "======================================================\n"
