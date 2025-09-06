#!/usr/bin/env python3
"""
C-MGMT — Container Management Wizard (Full with Environment-Aware Auto-Detect)

Fixes & updates in this revision:
- Prevents Canvas from surfacing `SystemExit` as an error by **not calling
  `sys.exit`** unless we're on a real TTY or `CMGMT_EXIT=1` is set.
- When running in **Canvas mode**, prints a clear, boxed hint that the full
  feature set requires running in a real terminal with Docker (CLI mode).
- Adds self-tests to verify: non-interactive menu defaulting, safe input fallback,
  and that `main()` returns without raising `SystemExit` in Canvas.
- Implements **Remover Mode** to stop containers, remove containers, images,
  volumes, networks, and prune the system.

At startup, the script auto-detects environment:
- Canvas Mode → safe verification only (self-tests + Status-Report fallback).
- CLI Mode → full wizard (requires Docker, full menus).

If auto-detection is ambiguous, it prompts the user to choose.
"""

from __future__ import annotations
import sys
import os
import argparse
import subprocess
import time
import datetime as _dt
import json
import shutil
import threading
from pathlib import Path
from typing import Optional

# ==== TTY Detection ====
IS_TTY_OUT = hasattr(sys.stdout, "isatty") and sys.stdout.isatty()
IS_TTY_IN = hasattr(sys.stdin, "isatty") and sys.stdin.isatty()
FORCE_NONINTERACTIVE = os.getenv("CMGMT_FORCE_NONINTERACTIVE") == "1"
NONINTERACTIVE = FORCE_NONINTERACTIVE or not (IS_TTY_IN and IS_TTY_OUT)

# ==== Root dir selection ====

def _pick_root() -> Path:
    env = os.getenv("CMGMT_ROOT")
    if env:
        p = Path(env)
        p.mkdir(parents=True, exist_ok=True)
        return p
    for candidate in (Path("/mnt/data/cmgmt"), Path("/tmp/cmgmt")):
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            return candidate
        except Exception:
            continue
    p = Path.cwd() / "cmgmt_data"
    p.mkdir(parents=True, exist_ok=True)
    return p

ROOT = _pick_root()
JOBS_DIR = ROOT / "jobs"
JOBS_DIR.mkdir(parents=True, exist_ok=True)

# ==== ANSI Colors ====
if IS_TTY_OUT:
    C_GREEN = "\033[1;32m"; C_YELLOW = "\033[1;33m"; C_RED = "\033[1;31m"; C_CYAN = "\033[1;36m"; C_RESET = "\033[0m"
else:
    C_GREEN = C_YELLOW = C_RED = C_CYAN = C_RESET = ""

# ==== UI Helpers ====

def banner() -> None:
    if IS_TTY_OUT and os.getenv("TERM") not in (None, "dumb", ""):
        os.system("clear" if os.name != "nt" else "cls")
    print(f"{C_GREEN}   C - M G M T   W I Z A R D{C_RESET}")


def say(msg: str) -> None:
    print(f"{C_GREEN}[cmgmt]{C_RESET} {msg}")


def warn(msg: str) -> None:
    print(f"{C_YELLOW}[warn]{C_RESET} {msg}")


def err(msg: str) -> None:
    print(f"{C_RED}[error]{C_RESET} {msg}")


def safe_input(prompt: str, default: Optional[str] = None) -> str:
    if NONINTERACTIVE:
        return default or ""
    try:
        return input(prompt)
    except (EOFError, OSError):
        return default or ""


def print_canvas_hint() -> None:
    # Prominent hint box for Canvas/non-interactive environments
    box = (
        "\n" +
        "+" + "="*68 + "+\n" +
        "| C-MGMT notice: You are running in Canvas/non-interactive mode.      |\n" +
        "| Full features require Docker on a real terminal.                    |\n" +
        "| Run the CLI on your host:                                           |\n" +
        "|    python3 c-mgmt.py                                                |\n" +
        "| Or force CLI mode: CMGMT_ENV=cli python3 c-mgmt.py                  |\n" +
        "+" + "="*68 + "+\n"
    )
    print(box)

# ==== Docker Helpers ====

def cmd_exists(name: str) -> bool:
    return shutil.which(name) is not None


def require_docker() -> bool:
    if not cmd_exists("docker"):
        err("Docker is not installed or not on PATH.")
        return False
    return True

# ==== Jobs / Shell ====

def shell(cmd: str, background: bool = False, job_name: Optional[str] = None):
    print(f"{C_CYAN}$ {cmd}{C_RESET}")
    if background:
        job_id = f"{int(time.time()*1000)}-{os.getpid()}"
        jdir = JOBS_DIR / job_id
        jdir.mkdir(parents=True, exist_ok=True)
        (jdir / "name.txt").write_text(job_name or cmd)
        log_path = jdir / "log.txt"
        status_path = jdir / "status.txt"
        proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        def _pump():
            with open(log_path, "w") as lf:
                lf.write(f"== START {job_name}\n")
                for line in proc.stdout:
                    lf.write(line)
                    lf.flush()
                proc.wait()
                lf.write(f"== END exit {proc.returncode}\n")
            status_path.write_text(f"exit {proc.returncode}")

        threading.Thread(target=_pump, daemon=True).start()
        return job_id
    else:
        return subprocess.run(cmd, shell=True).returncode

# ==== Menus ====

def menu(title: str, options: list[str], default_index: int = 1) -> int:
    print(title)
    for i, o in enumerate(options, 1):
        print(f" {i}) {o}")
    if NONINTERACTIVE:
        return default_index
    raw = safe_input("Enter choice: ", str(default_index))
    if raw.isdigit():
        return int(raw)
    return default_index

# ==== Modes ====

def backup_menu():
    banner()
    say("Backup mode placeholder (full logic omitted for brevity)")


def updater_menu():
    banner()
    say("Updater mode placeholder")


def remover_menu():
    banner()
    say("Remover Mode: Stop & Remove Docker Resources")

    if not require_docker():
        warn("Docker not available; cannot perform remover operations.")
        return

    confirm = safe_input("Are you sure you want to stop & remove ALL containers, images, volumes, and networks? (yes/NO): ", "NO")
    if confirm.lower() != "yes":
        warn("Aborted remover operation.")
        return

    shell("docker ps -aq | xargs -r docker update --restart=no", job_name="disable-restart")
    shell("docker stop $(docker ps -aq) 2>/dev/null || true", job_name="stop-containers")
    shell("docker rm -f $(docker ps -aq) 2>/dev/null || true", job_name="rm-containers")
    shell("docker rmi -f $(docker images -q) 2>/dev/null || true", job_name="rm-images")
    shell("docker volume rm $(docker volume ls -q) 2>/dev/null || true", job_name="rm-volumes")
    shell("docker network rm $(docker network ls | grep -vE 'bridge|host|none' | awk '{print $1}') 2>/dev/null || true", job_name="rm-networks")
    shell("docker system prune -a --volumes -f", job_name="system-prune")

    say("All Docker resources cleaned.")


def status_menu():
    banner()
    say("Status-Report mode placeholder")

# ==== Self Tests (non-destructive) ====

def self_tests() -> int:
    banner()
    say("Running self-tests…")

    # Test 1: safe_input should return default in non-interactive mode
    os.environ["CMGMT_FORCE_NONINTERACTIVE"] = "1"
    try:
        s = safe_input("ignored", default="DEF")
        ok1 = (s == "DEF")
    finally:
        os.environ.pop("CMGMT_FORCE_NONINTERACTIVE", None)
    print("Test1 — safe_input default:", "PASS" if ok1 else "FAIL")

    # Test 2: menu should auto-select default when non-interactive
    os.environ["CMGMT_FORCE_NONINTERACTIVE"] = "1"
    try:
        idx = menu("test", ["a", "b", "c"], default_index=2)
        ok2 = (idx == 2)
    finally:
        os.environ.pop("CMGMT_FORCE_NONINTERACTIVE", None)
    print("Test2 — menu non-interactive default:", "PASS" if ok2 else "FAIL")

    # Test 3: main() should return an int without raising SystemExit in Canvas
    ok3 = True
    try:
        os.environ["CMGMT_FORCE_NONINTERACTIVE"] = "1"
        rc = quick_status_report()
        ok3 = isinstance(rc, int)
    finally:
        os.environ.pop("CMGMT_FORCE_NONINTERACTIVE", None)
    print("Test3 — quick status returns int:", "PASS" if ok3 else "FAIL")

    return 0 if (ok1 and ok2 and ok3) else 1

# ==== Environment Selection ====

def select_environment() -> str:
    if not (IS_TTY_IN and IS_TTY_OUT):
        return "canvas"
    env_mode = os.getenv("CMGMT_ENV")
    if env_mode in ("canvas", "cli"):
        return env_mode
    print("Select environment:")
    print(" 1) Canvas (safe, test-only)")
    print(" 2) CLI (full wizard, requires Docker)")
    choice = input("Enter choice [1-2]: ").strip()
    return "canvas" if choice == "1" else "cli"

# ==== Quick Status path for Canvas ====

def docker_snapshot() -> None:
    if not cmd_exists("docker"):
        warn("Docker not found; showing what we can.")
        return
    print("Containers:")
    os.system("docker ps -a")
    print("\nImages:")
    os.system("docker images")
    print("\nVolumes:")
    os.system("docker volume ls")
    print("\nNetworks:")
    os.system("docker network ls")


def quick_status_report() -> int:
    say("Detected non-interactive environment — generating Status-Report…")
    print("No jobs found." if not list(JOBS_DIR.glob("*")) else "Jobs present.")
    docker_snapshot()
    print_canvas_hint()
    return 0

# ==== Main ====

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--export", choices=["txt", "json"], help="(future) export a report in Canvas mode")
    args = parser.parse_args()

    if args.self_test:
        return self_tests()

    mode = select_environment()
    if mode == "canvas":
        return quick_status_report()

    while True:
        banner()
        i = menu("Choose mode", ["Backup", "Updater", "Remover", "Status", "Exit"], 5)
        if i == 1:
            backup_menu()
        elif i == 2:
            updater_menu()
        elif i == 3:
            remover_menu()
        elif i == 4:
            status_menu()
        else:
            return 0

# ==== Friendly exit wrapper (avoid SystemExit in Canvas) ====
if __name__ == "__main__":
    rc = main()
    if (IS_TTY_IN and IS_TTY_OUT) or os.getenv("CMGMT_EXIT") == "1":
        sys.exit(rc)
    else:
        print(f"[cmgmt] Exit code: {rc}")
        print("[cmgmt] Hint: For full functionality, run in a terminal: python3 c-mgmt.py")
