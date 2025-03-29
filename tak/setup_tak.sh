#!/bin/bash
# setup_tak.sh
# Example script that sets up dependencies, then splits tmux into 4 panes.

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

spinner() {
  local pid=$1
  local delay=0.15
  local spin='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    for i in {0..3}; do
      printf "\r[%s] " "${spin:$i:1}"
      sleep $delay
    done
  done
  printf "\r"
}

echo -e "${BLUE}┌───────────────────────────────────────────────┐"
echo -e "│        TAK (Team Awareness Kit) Setup       │"
echo -e "└───────────────────────────────────────────────┘${NC}\n"

echo -e "${GREEN}[INFO]${NC} Checking dependencies..."

# 1) Check for tmux; install if missing
if ! command -v tmux &>/dev/null; then
  echo -e "${YELLOW}[WARN] tmux not found. Installing...${NC}"
  {
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -y && sudo apt-get install -y tmux
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y tmux
    else
      echo -e "${RED}[ERROR] Unsupported package manager. Please install tmux manually.${NC}"
      exit 1
    fi
  } &
  SPIN_PID=$!
  spinner $SPIN_PID
  wait $SPIN_PID
  echo -e "${GREEN}[INFO] tmux installed successfully.${NC}"
else
  echo -e "${GREEN}[INFO] tmux is already installed.${NC}"
fi

# 2) Check for Docker; install if missing
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}[WARN] Docker not found. Installing Docker...${NC}"
  {
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -y && sudo apt-get install -y docker.io
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y docker
    else
      echo -e "${RED}[ERROR] Could not install Docker automatically. Please install manually.${NC}"
      exit 1
    fi
  } &
  SPIN_PID=$!
  spinner $SPIN_PID
  wait $SPIN_PID
  echo -e "${GREEN}[INFO] Docker installed successfully.${NC}"
else
  echo -e "${GREEN}[INFO] Docker is already installed.${NC}"
fi

# 3) Ensure Docker is running
if ! sudo systemctl is-active --quiet docker; then
  echo -e "${YELLOW}[WARN] Docker service is not active. Starting Docker...${NC}"
  sudo systemctl start docker
fi

# 4) Launch a new tmux session and split into four panes
echo -e "\n${GREEN}[INFO] Launching tmux session in a 2×2 grid...${NC}"

# Create a new session with pane 0.0 running a shell
tmux new-session -d -s tak_setup "/bin/bash"

# Split the original pane horizontally (now we have 0.0 on left, 0.1 on right)
tmux split-window -h -t tak_setup:0.0

# Split the left pane (0.0) vertically (now 0.2 is below 0.0)
tmux split-window -v -t tak_setup:0.0

# Split the right pane (0.1) vertically (now 0.3 is below 0.1)
tmux split-window -v -t tak_setup:0.1

# Send commands to each new pane
tmux send-keys -t tak_setup:0.1 'htop' C-m
tmux send-keys -t tak_setup:0.2 'btop' C-m
tmux send-keys -t tak_setup:0.3 'tail -f /var/log/syslog' C-m

# Attach so the user sees the 2×2 layout
tmux attach-session -t tak_setup

# Script continues after user detaches (Ctrl+B, then D)
echo -e "${GREEN}[INFO] TAK setup script finished.${NC}"
exit 0
