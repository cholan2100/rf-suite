# RF Suite

Containerized Linux engineering environment for RF / EDA work:
KiCad 10, FreeCAD 1.0, openEMS, Qucs-S + qucsator-rf, ngspice, scikit-rf, noVNC desktop.

Containerized Linux engineering environment for RF / EDA work — no agent system included.

## Quick start

```bash
docker compose up -d
# Web desktop:
# http://localhost:6080/vnc.html
```

Windows helpers in `bin\`:

* `rf-gui.bat` — start container + open browser
* `rf-bash.bat` — interactive shell
* `rf-run.bat python tests/verify_environment.py` — headless check

## Verify

```bash
python tests/verify_environment.py
```

## Config

Copy `.env.example` to `.env` and adjust `PROJECT_PATH`, `WEB_PORT=6080`, `VNC_PORT=5900`, `MCP_PORT=8000`.
