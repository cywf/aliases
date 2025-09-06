#!/usr/bin/env python3
"""
C-MGMT Wizard (Python Edition)
"""

import os
import sys
import subprocess
import datetime
import logging
from rich.console import Console
from rich.table import Table
from rich.progress import Progress
from InquirerPy import inquirer

console = Console()
logging.basicConfig(filename="/tmp/cmgmt.log",
                    level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s")

def run(cmd, background=False):
    """Run a system command, optionally in background"""
    console.print(f"[cyan]$ {cmd}[/cyan]")
    if background:
        return subprocess.Popen(cmd, shell=True)
    else:
        return subprocess.run(cmd, shell=True, check=False)

# === Backup Mode ===
def backup_menu():
    choice = inquirer.select(
        message="Backup-Tool Mode — choose an action:",
        choices=[
            "Snapshot running containers ➜ images",
            "Backup all volumes",
            "Save images to tar",
            "Build & Push image to registry",
            "Commit & Push Dockerfile to GitHub",
            "Back"
        ],
    ).execute()

    if choice.startswith("Snapshot"):
        run("docker ps")
        cid = inquirer.text(message="Container ID (or 'all')?").execute()
        if cid == "all":
            run("for c in $(docker ps -q); do docker commit $c ${c}-snap; done")
        else:
            run(f"docker commit {cid} {cid}-snap")
    elif choice.startswith("Backup all volumes"):
        run("mkdir -p /tmp/docker-backups")
        run("for v in $(docker volume ls -q); do docker run --rm -v $v:/data -v /tmp/docker-backups:/backup busybox tar czf /backup/${v}.tar.gz /data; done")
    elif choice.startswith("Save images"):
        run("docker images")
        img = inquirer.text(message="Image name (or 'all')?").execute()
        if img == "all":
            run("for i in $(docker images --format '{{.Repository}}:{{.Tag}}'); do docker save -o /tmp/${i//[:\/]/_}.tar $i; done")
        else:
            safe = img.replace("/", "_").replace(":", "_")
            run(f"docker save -o /tmp/{safe}.tar {img}")
    elif choice.startswith("Build & Push"):
        path = inquirer.text(message="Dockerfile directory?").execute()
        ref  = inquirer.text(message="Registry/ref (e.g. user/app:tag)?").execute()
        run(f"docker build -t {ref} {path}")
        run(f"docker push {ref}")
    elif choice.startswith("Commit & Push Dockerfile"):
        repo = inquirer.text(message="Git repo path?").execute()
        msg  = inquirer.text(message="Commit message?").execute()
        run(f"cd {repo} && git add Dockerfile docker-compose.yml && git commit -m '{msg}' && git push")

# === Updater Mode (simplified example) ===
def updater_menu():
    choice = inquirer.select(
        message="Updater Mode — choose an action:",
        choices=[
            "Pull latest image",
            "Apply new policies",
            "Security scan (Trivy/Docker Scout)",
            "Exec interactive shell",
            "Generate/Update Dockerfile",
            "Generate/Update docker-compose.yml",
            "Back"
        ],
    ).execute()

    if choice.startswith("Pull"):
        cid = inquirer.text(message="Container ID?").execute()
        run(f"docker pull $(docker inspect -f '{{{{.Config.Image}}}}' {cid})")
    elif choice.startswith("Apply"):
        cid = inquirer.text(message="Container ID?").execute()
        pol = inquirer.select(message="Restart policy:", choices=["no","on-failure","always","unless-stopped"]).execute()
        run(f"docker update --restart={pol} {cid}")
    elif choice.startswith("Security"):
        img = inquirer.text(message="Image to scan?").execute()
        if shutil.which("trivy"):
            run(f"trivy image {img}")
        else:
            run(f"docker scout cves {img}")
    elif choice.startswith("Exec"):
        cid = inquirer.text(message="Container ID?").execute()
        shl = inquirer.text(message="Shell [/bin/bash]:").execute() or "/bin/bash"
        os.system(f"docker exec -it {cid} {shl}")
    # (Dockerfile and compose generators would write template files)

# === Remover Mode ===
def remover_menu():
    choice = inquirer.select(
        message="Remover Mode — choose:",
        choices=[
            "Stop container(s)",
            "Remove container(s) + volumes",
            "Remove images",
            "Full wipe (nuke)",
            "Back"
        ],
    ).execute()
    if choice.startswith("Stop"):
        run("docker ps -a")
        cid = inquirer.text(message="Container ID (or 'all')?").execute()
        if cid == "all":
            run("docker update --restart=no $(docker ps -aq); docker stop $(docker ps -aq)")
        else:
            run(f"docker update --restart=no {cid}; docker stop {cid}")
    elif choice.startswith("Full wipe"):
        confirm = inquirer.text(message="Type I-AM-SURE:").execute()
        if confirm == "I-AM-SURE":
            run("docker system prune -a --volumes -f")

# === Status Mode ===
def status_menu():
    table = Table(title="Docker Status")
    table.add_column("Type"); table.add_column("Output")
    table.add_row("Containers", subprocess.getoutput("docker ps -a | head -n 10"))
    table.add_row("Images", subprocess.getoutput("docker images | head -n 10"))
    table.add_row("Volumes", subprocess.getoutput("docker volume ls"))
    console.print(table)
    input("Press Enter...")

# === Main Loop ===
def main():
    while True:
        banner = "[green]C - M G M T   W I Z A R D[/green]"
        choice = inquirer.select(
            message=banner,
            choices=[
                "Backup-Tool",
                "Updater",
                "Remover",
                "Status-Report",
                "Exit"
            ],
        ).execute()
        if choice == "Backup-Tool": backup_menu()
        elif choice == "Updater": updater_menu()
        elif choice == "Remover": remover_menu()
        elif choice == "Status-Report": status_menu()
        elif choice == "Exit": sys.exit(0)

if __name__ == "__main__":
    main()
