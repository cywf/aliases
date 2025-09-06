#!/usr/bin/env python3
"""
c-mgmt.py — Container Management Wizard (Python Edition)
Modes:
- Backup-Tool
- Updater
- Remover
- Status-Report
"""

import os, sys, subprocess, datetime, shutil, threading
from pathlib import Path
from rich.console import Console
from rich.table import Table
from rich.progress import Progress
from InquirerPy import inquirer

console = Console()
ROOT = Path("/tmp/cmgmt")
JOBS = ROOT / "jobs"
JOBS.mkdir(parents=True, exist_ok=True)

# ===== Helpers =====
def run(cmd, background=False):
    """Run a system command, log it, optionally background."""
    console.print(f"[cyan]$ {cmd}[/cyan]")
    if background:
        proc = subprocess.Popen(cmd, shell=True,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT,
                                text=True)
        jid = f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}-{os.getpid()}"
        jdir = JOBS / jid
        jdir.mkdir(parents=True)
        logf = open(jdir / "log.txt", "w")
        def _pipe():
            for line in proc.stdout:
                logf.write(line)
                logf.flush()
            proc.wait()
            (jdir / "status.txt").write_text(f"exit {proc.returncode}")
        threading.Thread(target=_pipe, daemon=True).start()
        console.print(f"[green]Started background job {jid}[/green]")
        return jid
    else:
        return subprocess.run(cmd, shell=True).returncode

def pause(): input("Press Enter to return...")

# ===== Backup Mode =====
def backup_menu():
    while True:
        choice = inquirer.select(
            message="Backup-Tool Mode",
            choices=[
                "Snapshot containers ➜ images",
                "Backup all volumes",
                "Save images to tar",
                "Build & Push image",
                "Commit & Push Dockerfile to GitHub",
                "Back"
            ]).execute()
        if choice.startswith("Snapshot"):
            run("docker ps")
            cid = inquirer.text(message="Container ID (or 'all')?").execute()
            if cid == "all":
                run("for c in $(docker ps -q); do docker commit $c ${c}-snap; done", background=True)
            else:
                run(f"docker commit {cid} {cid}-snap", background=True)
        elif choice.startswith("Backup all"):
            run("mkdir -p /tmp/docker-backups && "
                "for v in $(docker volume ls -q); do "
                "docker run --rm -v $v:/data -v /tmp/docker-backups:/backup busybox "
                "tar czf /backup/${v}.tar.gz /data; done", background=True)
        elif choice.startswith("Save"):
            run("docker images")
            img = inquirer.text(message="Image (or 'all')?").execute()
            if img == "all":
                run("mkdir -p /tmp/docker-images && "
                    "for i in $(docker images --format '{{.Repository}}:{{.Tag}}'); do "
                    "docker save -o /tmp/docker-images/${i//[:\/]/_}.tar $i; done", background=True)
            else:
                safe = img.replace("/", "_").replace(":", "_")
                run(f"docker save -o /tmp/{safe}.tar {img}", background=True)
        elif choice.startswith("Build & Push"):
            path = inquirer.text("Dockerfile dir?").execute()
            ref  = inquirer.text("Image ref (e.g. user/app:tag)?").execute()
            run(f"docker build -t {ref} {path} && docker push {ref}", background=True)
        elif choice.startswith("Commit & Push"):
            repo = inquirer.text("Local repo path?").execute()
            msg  = inquirer.text("Commit message?").execute()
            run(f"cd {repo} && git add Dockerfile docker-compose.yml && "
                f"git commit -m '{msg}' && git push", background=True)
        else: break
        pause()

# ===== Updater Mode =====
def updater_menu():
    while True:
        choice = inquirer.select(
            message="Updater Mode",
            choices=[
                "Pull latest image",
                "Apply restart/mem/cpu policies",
                "Security scan (Trivy/Docker Scout)",
                "Exec into container shell",
                "Generate Dockerfile",
                "Generate docker-compose.yml",
                "Back"
            ]).execute()
        if choice.startswith("Pull"):
            cid = inquirer.text("Container ID?").execute()
            run(f"docker pull $(docker inspect -f '{{{{.Config.Image}}}}' {cid})", background=True)
        elif choice.startswith("Apply"):
            cid = inquirer.text("Container ID?").execute()
            rp = inquirer.select(message="Restart policy",
                                 choices=["no","on-failure","always","unless-stopped"]).execute()
            run(f"docker update --restart={rp} {cid}", background=True)
        elif choice.startswith("Security"):
            img = inquirer.text("Image?").execute()
            if shutil.which("trivy"):
                run(f"trivy image {img}", background=True)
            else:
                run(f"docker scout cves {img}", background=True)
        elif choice.startswith("Exec"):
            cid = inquirer.text("Container ID?").execute()
            os.system(f"docker exec -it {cid} /bin/bash")
        elif choice.startswith("Generate Dockerfile"):
            base = inquirer.select("Base", choices=["debian:bookworm-slim","ubuntu:22.04","alpine:3.20"]).execute()
            out  = inquirer.text("Output path (e.g. ./Dockerfile)").execute()
            Path(out).write_text(f"FROM {base}\nWORKDIR /app\nCOPY . /app\nCMD echo Hello from C-MGMT\n")
            console.print(f"[green]Wrote {out}[/green]")
        elif choice.startswith("Generate docker-compose"):
            svc  = inquirer.text("Service name?").execute()
            img  = inquirer.text("Image?").execute()
            out  = inquirer.text("Output path (e.g. ./docker-compose.yml)").execute()
            Path(out).write_text(f"version: '3.8'\nservices:\n  {svc}:\n    image: {img}\n    restart: unless-stopped\n")
            console.print(f"[green]Wrote {out}[/green]")
        else: break
        pause()

# ===== Remover Mode =====
def remover_menu():
    while True:
        choice = inquirer.select(
            message="Remover Mode",
            choices=[
                "Stop containers (disable restart)",
                "Remove containers + volumes",
                "Remove images",
                "Full wipe",
                "Back"
            ]).execute()
        if choice.startswith("Stop"):
            cid = inquirer.text("Container (or 'all')?").execute()
            if cid == "all":
                run("docker update --restart=no $(docker ps -aq); docker stop $(docker ps -aq)", background=True)
            else:
                run(f"docker update --restart=no {cid}; docker stop {cid}", background=True)
        elif choice.startswith("Remove containers"):
            cid = inquirer.text("Container (or 'all')?").execute()
            if cid == "all": run("docker rm -f $(docker ps -aq) --volumes", background=True)
            else: run(f"docker rm -f {cid} --volumes", background=True)
        elif choice.startswith("Remove images"):
            img = inquirer.text("Image (or 'all')?").execute()
            if img == "all": run("docker rmi -f $(docker images -q)", background=True)
            else: run(f"docker rmi -f {img}", background=True)
        elif choice.startswith("Full wipe"):
            confirm = inquirer.text("Type I-AM-SURE").execute()
            if confirm=="I-AM-SURE":
                run("docker system prune -a --volumes -f", background=True)
        else: break
        pause()

# ===== Status Mode =====
def status_menu():
    table = Table(title="Docker Environment")
    table.add_column("Type"); table.add_column("Output")
    table.add_row("Containers", subprocess.getoutput("docker ps -a | head -n 10"))
    table.add_row("Images", subprocess.getoutput("docker images | head -n 10"))
    table.add_row("Volumes", subprocess.getoutput("docker volume ls"))
    table.add_row("Networks", subprocess.getoutput("docker network ls"))
    console.print(table)
    console.print("[yellow]Recent jobs:[/yellow]")
    for d in sorted(JOBS.glob("*"))[-5:]:
        console.print(f"{d.name} -> {(d/'status.txt').read_text() if (d/'status.txt').exists() else 'running'}")
    pause()

# ===== Main =====
def main():
    while True:
        choice = inquirer.select(
            message="[green]C - M G M T   W I Z A R D[/green]",
            choices=["Backup-Tool","Updater","Remover","Status-Report","Exit"]).execute()
        if choice=="Backup-Tool": backup_menu()
        elif choice=="Updater": updater_menu()
        elif choice=="Remover": remover_menu()
        elif choice=="Status-Report": status_menu()
        else: sys.exit(0)

if __name__=="__main__":
    main()
