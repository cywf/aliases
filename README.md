# My on-the-go toolkit 

## System Administration

alias cl="clear"
alias update="sudo apt-get update"
alias upgrade="sudo apt-get upgrade"
alias goget="sudo apt-get install"
alias clean="sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove"
alias reboot="sudo reboot"
alias shutdown="sudo shutdown -h now"
alias sysinfo="sudo lshw -short"
alias sysctls="sudo systemctl status"
alias sysctlr="sudo systemctl restart"
alias snano="sudo nano"
alias svi="sudo vi"
alias srcbash="source ~/.bashrc"
alias srczsh="source ~/.zshrc"
alias srcprofile="source ~/.profile"
alias srcaliases="source ~/.aliases"
alias ebash="nano ~/.bash_aliases"
alias editbash="nano ~/.bashrc"
alias editzsh="nano ~/.zshrc"
alias editprofile="nano ~/.profile"
alias editaliases="nano ~/.bash_aliases"

## Networking

alias ip="ifconfig"
alias ip4="ifconfig | grep 'inet ' | grep -v 'inet6 '"
alias ip6="ifconfig | grep 'inet6 '"
alias ip4only="ifconfig | grep 'inet ' | grep -v 'inet6 ' | awk '{print $2}'"
alias ip6only="ifconfig | grep 'inet6 ' | awk '{print $2}'"
alias ip4public="curl -s http://ipecho.net/plain; echo"
alias ip6public="curl -s http://ipv6.icanhazip.com; echo"
alias ippublic="curl -s http://ipecho.net/plain; echo"
alias iplocal="ip addr show | grep 'inet ' | grep -v 'inet6 ' | grep -v '"
alias p1="ping 1.1.1.1"
alias tr1="traceroute 1.1.1.1"
alias dg="dig google.com"
alias ns="nslookup google.com"
alias ufw="sudo ufw"
alias ufws="sudo ufw status"
alias ufwa="sudo ufw allow"
alias ufwd="sudo ufw deny"

## Git

alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gcl="git clone"
alias gcm="git commit -m"
alias gca="git commit -a"
alias gcam="git commit -am"
alias gp="git push"
alias gpl="git pull"
alias gplm="git pull origin master"
alias gps="git push origin main"
alias gpsm="git push origin master"

## Docker

alias d="docker"
alias dc="docker-compose"
alias dps="docker ps -a"
alias ds="docker status"

## TMUX

alias t="tmux"
alias ta="tmux attach"
alias tl="tmux ls"
alias tmn="tmux new -s"
alias tma="tmux attach -t"
alias tmd="tmux detach"
alias tmk="tmux kill-session -t"

## ZeroTier

alias zerotier-cli="sudo zerotier-cli"
alias zt="sudo zerotier-cli"
alias zti="sudo zerotier-cli info"
alias ztj="sudo zerotier-cli join"
alias ztp="sudo zerotier-cli peers"
alias ztlp="sudo zerotier-cli listpeers"
alias ztln="sudo zerotier-cli listnetworks"
