# RF Suite

[![KiCad](https://img.shields.io/badge/KiCad-10.0.4-314CB0?logo=kicad&logoColor=white)](https://kicad.org/)
[![FreeCAD](https://img.shields.io/badge/FreeCAD-1.0.0-CB333B?logo=freecad&logoColor=white)](https://www.freecad.org/)
[![openEMS](https://img.shields.io/badge/openEMS-v0.37.0--rc2-00599C)](https://openems.de/)
[![Qucs-S](https://img.shields.io/badge/Qucs--S-24.4.1-green)](https://ra3xdh.github.io/)
[![ngspice](https://img.shields.io/badge/ngspice-44.2-blue)](https://ngspice.sourceforge.io/)
[![Python](https://img.shields.io/badge/Python-3.13.5-3776AB?logo=python&logoColor=white)](https://www.python.org/)

Containerized Linux RF toolchain suite for RF / microwave engineering, PCB design,
3D electromagnetic simulation, and circuit simulation — everything runs inside a
Debian 13 (Trixie) Docker container, nothing to install on the host except Docker.

## Toolchain

| Category | Tool | Version | Capabilities |
| :--- | :--- | :--- | :--- |
| **PCB & EDA** | KiCad | 10.0.4 | Schematic capture, PCB layout, `kicad-cli` headless DRC / Gerber / STEP export |
| | KiCad Python (`pcbnew`) | 10.0.4 (Python 3.13) | Programmatic board synthesis, routing, zone fills |
| | KiCad 3D raytracer | 10.0.4 | Photorealistic board renders (`kicad-cli pcb render`) |
| | RF-tools-KiCAD | latest | Via fencing, track rounding, solder-mask helpers |
| | kicad-mcp-server | latest | KiCad MCP server module |
| **Electromagnetics** | openEMS + CSXCAD | v0.37.0-rc2 | 3D full-wave FDTD solver, multi-port S-parameter extraction |
| | AppCSXCAD | v0.37.0 | 3D mesh / geometry visualizer |
| **Circuit simulation** | Qucs-S | 24.4.1 | Schematic capture, S-parameter / AC / DC simulation |
| | qucsator-rf | 1.0.3 | RF solver backend |
| | ngspice | 44.2 | SPICE engine for transient / non-linear simulation |
| **3D mechanical CAD** | FreeCAD | 1.0.0 | Parametric CAD, STEP/STL export |
| | freecad-microwave workbench | >= 0.0.2 (enforced at build) | RF/microwave modelling, openEMS export |
| **RF & math (Python 3.13)** | scikit-rf | 2.1.0 | S-parameter math, Touchstone I/O, Smith charts, de-embedding |
| | numpy, scipy, matplotlib, pandas, h5py | — | Numerics, plotting, data |
| | shapely, trimesh | — | Geometry / mesh processing |
| | pypdfium2, Pillow, cairosvg, svglib, reportlab | — | Rendering, masks, vector artwork, reports |
| **Remote desktop** | noVNC + Openbox + x11vnc | — | Browser GUI at `http://localhost:6080`, VNC on `:5900` |

Base image: `ghcr.io/inti-cmnb/kicad10_auto:latest` (Debian 13 Trixie + KiCad 10).

## Quick start

Prerequisites: Docker (Docker Desktop with WSL 2 backend on Windows, or Docker Engine on Linux).

```bash
docker compose up -d
# Web desktop: http://localhost:6080/vnc.html  (default password: rfworkbench)
```

Windows helpers in `bin\`:

| Script | Description |
| :--- | :--- |
| `rf-gui.bat` / `.ps1` | Start container + open web desktop in browser |
| `rf-bash.bat` / `.ps1` | Interactive bash shell in `/workspace` |
| `rf-run.bat` / `.ps1` | Run a command headlessly, e.g. `rf-run.bat python tests/verify_environment.py` |
| `rf-kicad.bat` | Launch KiCad GUI + open browser |
| `rf-qucs.bat` | Launch Qucs-S + open browser |
| `rf-freecad.bat` | Launch FreeCAD + open browser |
| `rf-openems.bat` | Launch AppCSXCAD + open browser |

## Verify the installation

```bash
# Inside the container, or from the host:
bin\rf-run.bat python tests/verify_environment.py
```

Runs 14 checks: KiCad CLI + `pcbnew`, FreeCAD CLI + Python API, Microwave
workbench version gate (>= 0.0.2), openEMS binary + Python bindings, qucsator,
ngspice, scikit-rf, rendering libs, MCP server module, RF-tools plugin, KiCad
raytracer.

## Configuration

Copy `.env.example` to `.env` and adjust as needed:

* `PROJECT_PATH` — host path mounted at `/workspace` (default: `.`)
* `WEB_PORT=6080` — noVNC web desktop
* `VNC_PORT=5900` — direct VNC client access
* `MCP_PORT=8000` — MCP server / API access
* `RESOLUTION=1920x1080` — virtual desktop resolution
* `VNC_PASSWORD=rfworkbench` — desktop password

## Project structure

```
rf-suite/
├── Dockerfile              # Debian 13 + EDA/solver build
├── docker-compose.yml      # Service rf-suite, image rf-suite:latest
├── entrypoint.sh           # Xvfb + Openbox + x11vnc + noVNC startup
├── .env.example            # Template configuration
├── requirements.txt        # Python scientific / RF stack
├── bin/                    # Windows helper scripts (.bat / .ps1)
├── config/                 # Openbox window-manager configs
├── scripts/                # openEMS / Qucs-S / plugin install scripts
└── tests/                  # verify_environment.py diagnostic suite
```

## Rebuilding

```bash
docker compose build
```

The build compiles openEMS and Qucs-S from source (takes ~30 min) and enforces
freecad-microwave >= 0.0.2 — the build fails loudly if an older cached copy is
found.
