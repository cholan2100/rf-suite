#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "  Setting up RF Plugins, Workbenches, and MCP Servers"
echo "======================================================================"

# 1. Setup RF-tools-KiCAD
echo "[1/4] Installing RF-tools-KiCAD..."
KICAD_10_DIR="/root/.local/share/kicad/10.0/scripting/plugins"
KICAD_8_DIR="/root/.local/share/kicad/8.0/scripting/plugins"
mkdir -p "$KICAD_10_DIR" "$KICAD_8_DIR" /usr/share/kicad/plugins

if [ ! -d "$KICAD_10_DIR/RF-tools-KiCAD" ]; then
    git clone --depth 1 https://github.com/easyw/RF-tools-KiCAD.git "$KICAD_10_DIR/RF-tools-KiCAD"
fi
cp -rn "$KICAD_10_DIR/RF-tools-KiCAD" "$KICAD_8_DIR/" || true
cp -rn "$KICAD_10_DIR/RF-tools-KiCAD" /usr/share/kicad/plugins/ || true

# 2. Setup freecad-microwave Workbench
echo "[2/4] Installing freecad-microwave workbench..."
FREECAD_MOD_DIR="/root/.local/share/FreeCAD/Mod"
mkdir -p "$FREECAD_MOD_DIR"
mkdir -p /usr/lib/freecad/Mod

if [ ! -d "$FREECAD_MOD_DIR/freecad-microwave" ]; then
    git clone --depth 1 https://github.com/mishka-zz/freecad-microwave.git "$FREECAD_MOD_DIR/freecad-microwave"
fi

# Minimum-version guard: refuse anything older than 0.0.2.
# Upstream has no git tags; the version authority is Microwave/__init__.py (__version__).
MW_VERSION_FILE="$FREECAD_MOD_DIR/freecad-microwave/Microwave/__init__.py"
MW_VERSION="$(grep -E '^__version__ *=' "$MW_VERSION_FILE" 2>/dev/null | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/' || true)"
echo " freecad-microwave version: ${MW_VERSION:-<unknown>} (requires >= 0.0.2)"
if [ -z "${MW_VERSION:-}" ]; then
    echo "ERROR: could not determine freecad-microwave version from $MW_VERSION_FILE" >&2
    exit 1
fi
if [ "$(printf '%s\n%s\n' '0.0.2' "$MW_VERSION" | sort -V | head -n 1)" != "0.0.2" ]; then
    echo "ERROR: freecad-microwave $MW_VERSION is older than required 0.0.2 - remove $FREECAD_MOD_DIR/freecad-microwave and rebuild" >&2
    exit 1
fi

# Link Microwave module into FreeCAD Mod directories and python site-packages
ln -sf "$FREECAD_MOD_DIR/freecad-microwave" /usr/lib/freecad/Mod/Microwave || true

PYTHON_SITE_PKG=$(python3 -c "import site; print(site.getsitepackages()[0])")
if [ -d "$FREECAD_MOD_DIR/freecad-microwave/Microwave" ]; then
    ln -sf "$FREECAD_MOD_DIR/freecad-microwave/Microwave" "$PYTHON_SITE_PKG/Microwave" || true
fi

# 3. Setup Seeed-Studio kicad-mcp-server
echo "[3/4] Installing kicad-mcp-server..."
MCP_DIR="/opt/kicad-mcp-server"
if [ ! -d "$MCP_DIR" ]; then
    git clone --depth 1 https://github.com/Seeed-Studio/kicad-mcp-server.git "$MCP_DIR"
fi

cd "$MCP_DIR"
pip3 install --break-system-packages --ignore-installed -e . || pip3 install --break-system-packages --ignore-installed . || true

# 4. Create compatibility symlinks for Windows script paths
echo "[4/4] Creating compatibility paths and wrappers..."
# When scripts refer to Windows-style tools or default paths, provide shims:
mkdir -p /usr/local/bin
cat << 'EOF' > /usr/local/bin/rf-env-info
#!/bin/bash
echo "=== RF Workbench Linux Container ==="
echo "KiCad:     $(kicad-cli --version 2>/dev/null || echo 'Not found')"
echo "FreeCAD:   $(freecadcmd --version 2>/dev/null || echo 'Not found')"
echo "openEMS:   $(openEMS --version 2>&1 | head -n 2 | tail -n 1 || echo 'Installed')"
echo "Qucsator:  $(qucsator -v 2>&1 | head -n 1 || echo 'Not found')"
echo "Ngspice:   $(ngspice -v 2>&1 | head -n 2 | tail -n 1 || echo 'Not found')"
echo "Python:    $(python3 --version 2>&1)"
echo "Display:   $DISPLAY (noVNC at http://localhost:6080)"
echo "Workspace: /workspace"
echo "====================================="
EOF
chmod +x /usr/local/bin/rf-env-info

echo "RF plugins and workbenches setup completed!"
