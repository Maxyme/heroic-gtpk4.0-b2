# Game Porting Toolkit (GPTK) 4.0 Beta 2 for Heroic Games Launcher

This repository automates the installation and integration of **Apple Game Porting Toolkit 4.0 Beta 2** into **Heroic Games Launcher** using an existing GPTK base (such as `GPTK-3.0-3`).

---

## Step 0: Prerequisites & Downloads

* **Apple Silicon Mac** running macOS Sonoma, Sequoia, or later.
* **Heroic Games Launcher**: Installed from [heroicgameslauncher.com](https://heroicgameslauncher.com).
* **Base GPTK Runner in Heroic**:
  * In Heroic, open **Wine Manager** (Wine icon on left).
  * Download the latest GPTK version available (e.g., **`GPTK-3.0-3`**).
* **GPTK 4.0 Beta 2 DMG**:
  * Download **Game Porting Toolkit 4.0 Beta 2** from [Apple Developer Downloads](https://developer.apple.com/download/all/).
  * Double-click the DMG to mount it (mounts at `/Volumes/Game Porting Toolkit 4.0 Beta 2`).
* **Winetricks**:
  * Install via Homebrew: `brew install winetricks`  
  *(Or use the Winetricks tool built directly into Heroic's UI)*.

---

## Quick Start (Automated Script)

From this folder, simply run the automated installer:

```bash
cd ~/Code/heroic-gtpk4.0-b2
chmod +x install_gptk4_heroic.sh patch_gptk.py
./install_gptk4_heroic.sh
```

The script automatically:
1. Detects your mounted GPTK 4.0 Beta 2 DMG.
2. Finds your `GPTK-3.0-3` runner in Heroic and clones it to `GPTK-4.0-Beta`.
3. Patches all 6 GPTK 4.0 Windows DLLs for ABI compatibility.
4. Copies `D3DMetal.framework`, `libd3dshared.dylib`, and the patched DLLs into the new runner.

---

## Manual Step-by-Step Instructions

### 1. Clone your GPTK 3.0-3 Base Runner
```bash
cd "$HOME/Library/Application Support/Heroic/tools/wine"
cp -R GPTK-3.0-3 GPTK-4.0-Beta
```
*(Always clone an existing GPTK runner rather than creating an empty folder so Wine binaries and Apple's Rosetta `%gs` context handlers are preserved)*.

### 2. Binary-Patch the GPTK 4.0 DLLs
*(Fixes `STATUS_DLL_INIT_FAILED` / `c0000142` Wine 7.7 ABI incompatibility)*

Run the included patcher:
```bash
cd ~/Code/heroic-gtpk4.0-b2
python3 patch_gptk.py --dmg "/Volumes/Game Porting Toolkit 4.0 Beta 2" --out "./patched_dlls"
```

### 3. Inject GPTK 4.0 Files into the Runner
```bash
RUNNER="$HOME/Library/Application Support/Heroic/tools/wine/GPTK-4.0-Beta"

# Copy native macOS frameworks
cp -R "/Volumes/Game Porting Toolkit 4.0 Beta 2/redist/lib/D3DMetal.framework" "$RUNNER/lib/"
cp "/Volumes/Game Porting Toolkit 4.0 Beta 2/redist/lib/libd3dshared.dylib" "$RUNNER/lib/"

# Copy patched Windows DLLs
cp ./patched_dlls/*.dll "$RUNNER/lib/wine/x86_64-windows/"
```

---

## Heroic Game Configuration

1. **Quit Heroic completely** (`Cmd + Q`) and reopen it.
2. Go to your game's **Settings (gear icon) > Wine**.
3. Under **Wine Version**, select:
   ```text
   GPTK-4.0-Beta
   ```
4. Scroll down to **Environment Variables** and add:
   | Variable | Value | Description |
   | :--- | :--- | :--- |
   | `ROSETTA_ADVERTISE_AVX` | `1` | Enables AVX translation in Rosetta 2 |
   | `D3DM_ENABLE_METALFX` | `1` | Enables DLSS -> MetalFX translation |
   | `D3DM_SUPPORT_DXR` | `1` | Enables DirectX Raytracing (DXR) |
   | `D3DM_MTL4` | `1` | Activates Metal 4 pipeline optimizations |
   | `WINEDLLOVERRIDES` | `d3dcompiler_47=n,b` | Forces native Microsoft shader compiler |

---

## Unreal Engine 5 Fix (Slate Shader Crash)

Unreal Engine 5 games crash on startup if using Wine's built-in `d3dcompiler_47.dll`. To fix:
* In Heroic, click on your game $\rightarrow$ **Winetricks** $\rightarrow$ install **`d3dcompiler_47`**.  
* *(Or via CLI)*:
  ```bash
  WINEPREFIX="/path/to/game/prefix" winetricks d3dcompiler_47
  ```
