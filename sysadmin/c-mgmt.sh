#!/usr/bin/env bash
# c-mgmt.sh — Container Management Wizard (C-MGMT)
# Modes: Backup-Tool, Updater, Remover, Status-Report
# Logs & jobs: /tmp/cmgmt/jobs/<JOB_ID>/{log.txt,status.txt,status_code}

set -Eeuo pipefail

# ===== UI / Colors =====
GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'

banner() {
  clear
  echo -e "${GREEN}"
  echo "   C - M G M T   W I Z A R D"
  echo -e "${NC}"
}

say()  { printf "${GREEN}[cmgmt]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }
err()  { printf "${RED}[error]${NC} %s\n" "$*"; }

pause() { read -rp "Press Enter to return to menu..."; }

progress_bar() {
  local duration=${1:-3} i=0 steps=40
  while (( i<=steps )); do
    printf "\r["
    for j in $(seq 0 $steps); do
      if (( j<=i )); then printf "#"; else printf " "; fi
    done
    printf "] %3d%%" $(( i*100/steps ))
    sleep $(( duration/steps > 0 ? duration/steps : 1 ))
    ((i++))
  done
  echo
}

# ===== Runtime / Jobs =====
ROOT="/tmp/cmgmt"; JOBS_DIR="$ROOT/jobs"
mkdir -p "$JOBS_DIR"

bg_run() {
  # bg_run "Job Name" "command string"
  local name="$1"; shift
  local cmd="$*"
  local id; id="$(date +%s%3N)-$RANDOM"
  local dir="$JOBS_DIR/$id"; mkdir -p "$dir"
  local log="$dir/log.txt" status="$dir/status.txt" code="$dir/status_code"

  echo "running" >"$status"
  (
    echo "== C-MGMT JOB: $name =="
    echo "== START: $(date -Is) =="
    set +Eeuo pipefail
    bash -lc "$cmd"
    ec=$?
    echo "$ec" >"$code"
    echo "== END: $(date -Is) (exit $ec) =="
    exit $ec
  ) >"$log" 2>&1 &
  local pid=$!
  echo "$pid" > "$dir/pid"

  say "Started: ${name} (job-id: $id, pid: $pid)"
  # watcher to flip status -> finished when PID exits
  ( while kill -0 "$pid" 2>/dev/null; do sleep 1; done; echo "finished" >"$status" ) >/dev/null 2>&1 &
}

job_list() {
  printf "%-18s  %-8s  %-6s  %s\n" "JOB_ID" "STATUS" "CODE" "NAME/LOG"
  for d in "$JOBS_DIR"/*; do
    [[ -d "$d" ]] || continue
    local id pid status code name
    id="$(basename "$d")"
    pid="$(cat "$d/pid" 2>/dev/null || echo '-')"
    status="$(cat "$d/status.txt" 2>/dev/null || echo 'unknown')"
    code="$(cat "$d/status_code" 2>/dev/null || echo '-')"
    name="$(head -n1 "$d/log.txt" 2>/dev/null | sed 's/^== C-MGMT JOB: //')"
    printf "%-18s  %-8s  %-6s  %s (%s/log.txt)\n" "$id" "$status" "$code" "${name:-unnamed}" "$d"
  done
}

tail_job() {
  local id="$1"; local dir="$JOBS_DIR/$id"
  [[ -f "$dir/log.txt" ]] || { err "No such job id: $id"; return 1; }
  less +F "$dir/log.txt"
}

export_report() {
  local out="$ROOT/report-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "C-MGMT Report — $(date -Is)"
    echo
    job_list
    echo
    for d in "$JOBS_DIR"/*; do
      [[ -d "$d" ]] || continue
      echo "===== $(basename "$d") ====="
      cat "$d/log.txt"
      echo
    done
  } >"$out"
  say "Report written: $out"
}

# ===== Dependencies =====
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; return 1; }
}

# Prefer docker compose v2, fall back to docker-compose
compose_cmd() {
  if docker compose version >/dev/null 2>&1; then echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"
  else echo ""; fi
}

# ===== Menus =====
# --- Backup Mode ---
backup_menu() {
  banner
  say ">>> Backup-Tool Mode"
  cat <<EOF
1) Snapshot running container(s) to images (docker commit)
2) Backup all volumes to tar.gz
3) Save images to tar (docker save)
4) Build & Push image (Dockerfile ➜ Docker Hub/GHCR)
5) Git commit & push Dockerfile to GitHub
6) Back
EOF
  read -rp "Choose [1-6]: " c
  case "$c" in
    1) backup_snapshot_containers ;;
    2) backup_volumes ;;
    3) backup_save_images ;;
    4) backup_build_and_push ;;
    5) backup_git_push_dockerfile ;;
    6) return ;;
    *) warn "Invalid."; sleep 1 ;;
  esac
}

backup_snapshot_containers() {
  banner
  say "Snapshot containers ➜ images"
  docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'
  read -rp "Container ID/Name to snapshot (or 'all'): " target
  if [[ "$target" == "all" ]]; then
    mapfile -t list < <(docker ps -q)
  else
    list=("$target")
  fi
  for c in "${list[@]}"; do
    name="$(docker inspect -f '{{.Name}}' "$c" | tr -d '/')" || { warn "Skip $c"; continue; }
    tag="${name}-snapshot:$(date +%Y%m%d%H%M%S)"
    bg_run "commit $name -> $tag" "docker commit \"$c\" \"$tag\" && docker images \"$tag\""
  done
  pause
}

backup_volumes() {
  banner
  say "Backup volumes ➜ /tmp/docker-backups"
  mkdir -p /tmp/docker-backups
  bg_run "backup volumes" '
    for v in $(docker volume ls -q); do
      echo "Backing up volume: $v"
      docker run --rm -v "$v":/data -v /tmp/docker-backups:/backup busybox \
        sh -c "tar czf /backup/${v}.tar.gz -C /data ."
    done
  '
  pause
}

backup_save_images() {
  banner
  say "Save images to tar (registry-agnostic)"
  read -rp "Image ref (e.g., nginx:latest or 'all'): " img
  if [[ "$img" == "all" ]]; then
    bg_run "save all images" '
      mkdir -p /tmp/docker-images
      for i in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "^<none>:<none>$"); do
        safe=$(echo "$i" | tr "/:" "__")
        echo "Saving $i -> /tmp/docker-images/$safe.tar"
        docker save -o "/tmp/docker-images/$safe.tar" "$i"
      done
    '
  else
    safe=$(echo "$img" | tr "/:" "__")
    bg_run "save $img" "docker save -o \"/tmp/docker-images/$safe.tar\" \"$img\""
  fi
  pause
}

backup_build_and_push() {
  banner
  say "Build & Push image"
  read -rp "Path to Dockerfile directory: " path
  read -rp "Registry (docker.io|ghcr.io|other fqdn): " registry
  read -rp "Image name (e.g., user/app): " iname
  read -rp "Tag (e.g., v$(date +%Y%m%d)): " tag
  ref="${registry}/${iname}:${tag}"
  warn "You may be prompted to login to ${registry}."
  bg_run "build+push $ref" "
    docker login '${registry}'
    docker build -t '${ref}' '${path}'
    docker push '${ref}'
  "
  pause
}

backup_git_push_dockerfile() {
  banner
  say "Git push Dockerfile to GitHub"
  read -rp "Local repo path: " repo
  read -rp "Commit message: " msg
  bg_run "git push Dockerfile" "
    cd '${repo}'
    git add Dockerfile docker-compose.yml || true
    git commit -m '${msg}'
    git push
  "
  pause
}

# --- Updater Mode ---
updater_menu() {
  banner
  say ">>> Updater Mode"
  cat <<EOF
1) Pull latest image for a container
2) Apply/update policies (restart, CPU, memory)
3) Security scan image (Trivy or Docker Scout)
4) Exec interactive shell into container
5) Generate/Update Dockerfile (menu builder)
6) Generate/Update docker-compose.yml (menu builder)
7) Recreate compose project (pull/build + up -d)
8) Back
EOF
  read -rp "Choose [1-8]: " c
  case "$c" in
    1) updater_pull_image ;;
    2) updater_policies ;;
    3) updater_security_scan ;;
    4) updater_exec_shell ;;
    5) templater_dockerfile ;;
    6) templater_compose ;;
    7) updater_compose_recreate ;;
    8) return ;;
    *) warn "Invalid."; sleep 1 ;;
  esac
}

updater_pull_image() {
  banner
  docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}'
  read -rp "Container ID/Name: " c
  img="$(docker inspect -f '{{.Config.Image}}' "$c")"
  bg_run "pull $img" "docker pull \"$img\""
  pause
}

updater_policies() {
  banner
  docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
  read -rp "Container ID/Name: " c
  read -rp "Restart policy (no|on-failure|always|unless-stopped): " rp
  read -rp "CPU limit (e.g., 1.0 or blank to skip): " cpu
  read -rp "Memory limit (e.g., 512m or blank to skip): " mem
  cmd="docker update --restart=${rp}"
  [[ -n "${cpu}" ]] && cmd+=" --cpus=${cpu}"
  [[ -n "${mem}" ]] && cmd+=" --memory=${mem}"
  cmd+=" \"$c\""
  bg_run "update policies $c" "$cmd"
  pause
}

updater_security_scan() {
  banner
  read -rp "Image ref to scan (e.g., nginx:latest): " img
  if command -v trivy >/dev/null 2>&1; then
    bg_run "trivy scan $img" "trivy image --quiet --severity HIGH,CRITICAL \"$img\""
  elif command -v docker >/dev/null 2>&1 && docker scout version >/dev/null 2>&1; then
    bg_run "scout scan $img" "docker scout cves \"$img\""
  else
    warn "Neither Trivy nor Docker Scout found. Install Trivy: https://aquasecurity.github.io/trivy/ or enable Docker Scout."
  fi
  pause
}

updater_exec_shell() {
  banner
  docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}'
  read -rp "Container ID/Name: " c
  read -rp "Shell (/bin/bash or /bin/sh) [default /bin/bash]: " shl
  shl="${shl:-/bin/bash}"
  echo -e "${CYAN}Dropping you into the container. Exit with 'exit'.${NC}"
  docker exec -it "$c" "$shl" || true
}

templater_dockerfile() {
  banner
  say "Dockerfile generator"
  cat <<EOF
Base OS:
  1) Debian (bookworm-slim)
  2) Ubuntu (22.04)
  3) Alpine (3.20)
Preset:
  a) server-min
  b) dev-env (git,curl,build-essential)
EOF
  read -rp "Choose base [1/2/3]: " b; read -rp "Choose preset [a/b]: " p
  read -rp "Output path (e.g., ./Dockerfile): " out
  case "$b" in
    1) base="debian:bookworm-slim" ;;
    2) base="ubuntu:22.04" ;;
    3) base="alpine:3.20" ;;
    *) base="debian:bookworm-slim" ;;
  esac
  case "$p" in
    a) body=$'RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*' ;;
    b) body=$'RUN apt-get update && apt-get install -y git curl build-essential ca-certificates && rm -rf /var/lib/apt/lists/*' ;;
    *) body=$'RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*' ;;
  esac
  if [[ "$base" == alpine* ]]; then
    body=${body/apt-get/apk}; body=${body/install -y/install}; body=${body/&& rm -rf \/var\/lib\/apt\/lists\/*/}
    body=${body/update/update}
  fi
  cat > "$out" <<DOCK
FROM $base
$body
WORKDIR /app
COPY . /app
CMD ["bash","-lc","echo C-MGMT image ready; sleep infinity"]
DOCK
  say "Wrote Dockerfile to: $out"
  pause
}

templater_compose() {
  banner
  say "docker-compose.yml generator"
  read -rp "Service name: " svc
  read -rp "Image (e.g., nginx:latest): " img
  read -rp "Host port -> container port (e.g., 8080:80, blank for none): " port
  read -rp "Add volume? (host:container, blank for none): " vol
  read -rp "Output path (e.g., ./docker-compose.yml): " out
  cat > "$out" <<YML
version: "3.8"
services:
  $svc:
    image: $img
    restart: unless-stopped
$( [[ -n "$port" ]] && printf "    ports:\n      - \"%s\"\n" "$port")
$( [[ -n "$vol"  ]] && printf "    volumes:\n      - \"%s\"\n" "$vol")
YML
  say "Wrote compose file to: $out"
  pause
}

updater_compose_recreate() {
  banner
  local C; C="$(compose_cmd)"
  if [[ -z "$C" ]]; then err "docker compose not found."; pause; return; fi
  read -rp "Compose project directory: " dir
  bg_run "compose recreate in $dir" "cd \"$dir\" && $C pull && $C build && $C up -d --remove-orphans"
  pause
}

# --- Remover Mode ---
remover_menu() {
  banner
  say ">>> Remover Mode"
  cat <<EOF
1) Stop container(s) (force + disable restart)
2) Remove container(s) (optional: remove volumes)
3) Remove images by name/pattern
4) FULL WIPE (containers, images, volumes, networks) — Danger
5) Back
EOF
  read -rp "Choose [1-5]: " c
  case "$c" in
    1) remover_stop ;;
    2) remover_rm ;;
    3) remover_rmi ;;
    4) remover_full ;;
    5) return ;;
    *) warn "Invalid."; sleep 1 ;;
  esac
}

remover_stop() {
  banner
  docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
  read -rp "Container ID/Name (or 'all'): " target
  if [[ "$target" == "all" ]]; then
    bg_run "stop all (disable restart)" '
      for c in $(docker ps -aq); do
        docker update --restart=no "$c" || true
      done
      docker stop $(docker ps -aq) || true
    '
  else
    bg_run "stop $target" "docker update --restart=no \"$target\" && docker stop \"$target\""
  fi
  pause
}

remover_rm() {
  banner
  docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
  read -rp "Container ID/Name (or 'all'): " target
  read -rp "Also remove volumes? (yes/NO): " vol
  local rmv=""; [[ "$vol" == "yes" ]] && rmv="--volumes"
  if [[ "$target" == "all" ]]; then
    bg_run "rm all containers" "docker rm -f \$(docker ps -aq) $rmv || true"
  else
    bg_run "rm $target" "docker rm -f $rmv \"$target\" || true"
  fi
  pause
}

remover_rmi() {
  banner
  read -rp "Image ref/pattern (e.g., 'repo/*' or 'all'): " p
  if [[ "$p" == "all" ]]; then
    bg_run "rmi all" "docker rmi -f \$(docker images -q) || true"
  else
    # expand pattern to specific ids
    bg_run "rmi $p" "
      ids=\$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk '{print \$1\" \"\$2}' | grep -E \"^$p \" | awk '{print \$2}')
      [ -n \"\$ids\" ] && docker rmi -f \$ids || true
    "
  fi
  pause
}

remover_full() {
  banner
  echo -e "${RED}This will nuke containers, images, volumes, custom networks.${NC}"
  read -rp "Type 'I-AM-SURE' to continue: " confirm
  [[ "$confirm" == "I-AM-SURE" ]] || { warn "Aborted."; pause; return; }
  bg_run "FULL WIPE" '
    docker ps -aq | xargs -r docker update --restart=no
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    docker rmi -f $(docker images -q) 2>/dev/null || true
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    for n in $(docker network ls --format "{{.Name}}" | grep -vE "^(bridge|host|none)$"); do docker network rm "$n" || true; done
    docker system prune -a --volumes -f
  '
  pause
}

# --- Status Mode ---
status_menu() {
  banner
  say ">>> Status-Report Mode"
  cat <<EOF
1) Show running/finished jobs
2) Tail a job's log (live)
3) Export full report
4) Docker environment snapshot
5) Back
EOF
  read -rp "Choose [1-5]: " c
  case "$c" in
    1) banner; job_list; pause ;;
    2) read -rp "Job ID: " id; tail_job "$id" ;;
    3) export_report; pause ;;
    4) docker_snapshot; pause ;;
    5) return ;;
    *) warn "Invalid."; sleep 1 ;;
  esac
}

docker_snapshot() {
  banner
  echo "Containers:"
  docker ps -a
  echo
  echo "Images:"
  docker images
  echo
  echo "Volumes:"
  docker volume ls
  echo
  echo "Networks:"
  docker network ls
}

# ===== Main =====
main_menu() {
  require_cmd docker || { err "Docker is required."; exit 1; }
  while true; do
    banner
    echo "Choose a mode:"
    echo "  1) Backup-Tool"
    echo "  2) Updater"
    echo "  3) Remover"
    echo "  4) Status-Report"
    echo "  5) Exit"
    echo
    read -rp "Enter choice [1-5]: " choice
    case "$choice" in
      1) backup_menu ;;
      2) updater_menu ;;
      3) remover_menu ;;
      4) status_menu ;;
      5) exit 0 ;;
      *) warn "Invalid choice"; sleep 1 ;;
    esac
  done
}

main_menu
