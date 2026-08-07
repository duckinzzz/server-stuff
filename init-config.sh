#!/usr/bin/env bash
set -e

RC_FILE="$HOME/.zshrc"
START_MARK="# >>> CUSTOM ZSH BLOCK >>>"
END_MARK="# <<< CUSTOM ZSH BLOCK <<<"

# Sentinel flag for "already installed". Until it exists, the install runs.
# Subsequent runs only change the hostname and prompt color.
SENTINEL="$HOME/.init-config.done"
FRESH_INSTALL=0

# ── Clean block rewrite helper ─────────────────────────────────────────────────
remove_block() {
    local file="$1"
    if grep -q "$START_MARK" "$file" 2>/dev/null; then
        local start_line
        start_line=$(grep -n "$START_MARK" "$file" | head -1 | cut -d: -f1)
        local prev=$((start_line - 1))
        local prev_content
        prev_content=$(sed -n "${prev}p" "$file")
        if [ -z "$prev_content" ] && [ "$prev" -gt 0 ]; then
            start_line=$prev
        fi
        local end_line
        end_line=$(grep -n "$END_MARK" "$file" | head -1 | cut -d: -f1)
        sed -i "${start_line},${end_line}d" "$file"
    fi
}

# ═══ 1. INSTALL (one-time) ═════════════════════════════════════════════════════
if [ ! -f "$SENTINEL" ]; then
    echo "=== Installing zsh and plugins ==="

    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo is required for installation." >&2
        exit 1
    fi

    sudo apt update
    sudo apt install -y \
        zsh \
        git curl \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        zoxide \
        fzf

    # zsh-completions is not in apt — clone from GitHub
    if [ ! -d "$HOME/.zsh-completions" ]; then
        echo "=== Cloning zsh-completions ==="
        git clone --depth 1 https://github.com/zsh-users/zsh-completions "$HOME/.zsh-completions"
    fi

    # Make zsh the default login shell
    if [ "$(basename "$SHELL")" != "zsh" ]; then
        echo "=== Setting zsh as default shell ==="
        sudo chsh -s "$(command -v zsh)" "$USER"
    fi

    touch "$SENTINEL"
    FRESH_INSTALL=1
fi

# ═══ 2. INTERACTIVE (at the end) ═══════════════════════════════════════════════
echo ""
echo "=== init-config setup ==="
echo ""
echo "Enter server name (e.g. prod-01, dev-box):"
read -r HOST_NAME </dev/tty
HOST_NAME="${HOST_NAME:-my-server}"

echo ""
echo "Choose prompt color (for user@host):"
printf "  1) \e[38;5;208muser@${HOST_NAME}\e[0m  (orange)\n"
printf "  2) \e[38;5;82muser@${HOST_NAME}\e[0m  (green)\n"
printf "  3) \e[38;5;75muser@${HOST_NAME}\e[0m  (blue)\n"
printf "  4) \e[38;5;135muser@${HOST_NAME}\e[0m  (purple)\n"
printf "  5) \e[38;5;196muser@${HOST_NAME}\e[0m  (red)\n"
printf "  6) \e[38;5;213muser@${HOST_NAME}\e[0m  (pink)\n"
printf "  7) \e[38;5;255muser@${HOST_NAME}\e[0m  (white)\n"
read -r COLOR_CHOICE </dev/tty

case "$COLOR_CHOICE" in
    1) COLOR_CODE=208 ;;
    2) COLOR_CODE=82  ;;
    3) COLOR_CODE=75  ;;
    4) COLOR_CODE=135 ;;
    5) COLOR_CODE=196 ;;
    6) COLOR_CODE=213 ;;
    7) COLOR_CODE=255 ;;
    *) COLOR_CODE=208 ;;
esac

echo ""
echo "Install Docker? (Y/n):"
read -r DOCKER_ANSWER </dev/tty
case "$DOCKER_ANSWER" in
    [Nn]|[Nn][Oo]) DOCKER_INSTALL=0 ;;
    *) DOCKER_INSTALL=1 ;;
esac

echo ""
echo "✅ Shell:  zsh (default)"
echo "✅ Host:   $HOST_NAME"
printf "✅ Color:  \e[38;5;${COLOR_CODE}muser@${HOST_NAME}\e[0m\n"
if [ "$DOCKER_INSTALL" -eq 1 ]; then
    echo "✅ Docker: install"
else
    echo "✅ Docker: skip"
fi
echo ""

# ═══ 3. ~/.zshrc CONFIG ═══════════════════════════════════════════════════════
PS1_LINE="PS1=\"%F{$COLOR_CODE}%n@${HOST_NAME}%f:%F{75}%~%f\$ \""

CUSTOM_BLOCK="
${START_MARK}
# --- History (persists across reconnects / disconnects) ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# --- Completion ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# --- Plugins ---
fpath+=~/.zsh-completions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Directory jumping (zoxide) ---
eval \"\$(zoxide init zsh)\"

# --- PS1 ---
HOST_NAME=\"${HOST_NAME}\"
${PS1_LINE}
alias motd='run-parts /etc/update-motd.d/'
${END_MARK}"

remove_block "$RC_FILE"
echo "$CUSTOM_BLOCK" >> "$RC_FILE"

# ═══ 4. MOTD script ═══════════════════════════════════════════════════════════
MOTD_SCRIPT="/etc/update-motd.d/99-docker"
sudo tee "$MOTD_SCRIPT" >/dev/null <<'EOF'
#!/usr/bin/env bash
IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
echo "-----------------ABOBA-------------------"
echo
echo "🌐 IP: $IP"
echo "🖥  Host: $(hostname)"
echo "⏱  Uptime: $(uptime -p)"
echo
if ! command -v docker >/dev/null 2>&1; then
    echo "🔴 Docker not installed"
    echo "-------------------------------------------"
    exit
fi
echo "🐳 Docker compose projects:"
echo
mapfile -t containers < <(
docker ps -a \
--format '{{.Names}}|{{.Status}}|{{.Label "com.docker.compose.project"}}'
)
if [ ${#containers[@]} -eq 0 ]; then
    echo "🟡 No containers"
    exit
fi
declare -A projects
for line in "${containers[@]}"; do
    name=$(echo "$line" | cut -d'|' -f1)
    status=$(echo "$line" | cut -d'|' -f2)
    project=$(echo "$line" | cut -d'|' -f3)
    [ -z "$project" ] && project="standalone"
    projects["$project"]+="$name|$status"$'\n'
done
printed_stacks=0
printed_single_header=0
for project in "${!projects[@]}"; do
    mapfile -t items <<< "${projects[$project]}"
    filtered=()
    for line in "${items[@]}"; do
        [ -z "$line" ] && continue
        filtered+=("$line")
    done
    count=${#filtered[@]}
    [ "$count" -le 1 ] && continue
    printed_stacks=1
    echo "$project"
    for ((i=0; i<count; i++)); do
        line=${filtered[$i]}
        name=$(echo "$line" | cut -d'|' -f1)
        status=$(echo "$line" | cut -d'|' -f2)
        case "$status" in
            Up*) icon="🟢" ;;
            Exited*) icon="🔴" ;;
            *) icon="🟡" ;;
        esac
        [ $i -eq $((count-1)) ] && prefix="└──" || prefix="├──"
        printf "%s %s %-22s %s\n" "$prefix" "$icon" "$name" "$status"
    done
done
for project in "${!projects[@]}"; do
    mapfile -t items <<< "${projects[$project]}"
    filtered=()
    for line in "${items[@]}"; do
        [ -z "$line" ] && continue
        filtered+=("$line")
    done
    count=${#filtered[@]}
    [ "$count" -ne 1 ] && continue
    if [ "$printed_stacks" -eq 1 ] && [ "$printed_single_header" -eq 0 ]; then
        echo
        printed_single_header=1
    fi
    line=${filtered[0]}
    name=$(echo "$line" | cut -d'|' -f1)
    status=$(echo "$line" | cut -d'|' -f2)
    case "$status" in
        Up*) icon="🟢" ;;
        Exited*) icon="🔴" ;;
        *) icon="🟡" ;;
    esac
    printf " ── %s %-22s %s\n" "$icon" "$name" "$status"
done
echo "-------------------------------------------"
EOF

sudo chmod +x "$MOTD_SCRIPT"

# ═══ 5. Docker (optional) ══════════════════════════════════════════════════════
if [ "$DOCKER_INSTALL" -eq 1 ]; then
    if command -v docker >/dev/null 2>&1; then
        echo "🐳 Docker already installed — skipping."
    else
        echo "=== Installing Docker ==="
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker "$USER"
        echo "🐳 Docker installed. Log back in to apply the docker group."
    fi
fi

# ═══ 6. Apply ═════════════════════════════════════════════════════════════════
# shellcheck disable=SC1090
source "$RC_FILE" 2>/dev/null || true

echo ""
if [ -f "$SENTINEL" ] && [ "$FRESH_INSTALL" -eq 0 ]; then
    echo "🔄 Config updated: host '$HOST_NAME', color '$COLOR_CODE'."
    echo "   (packages already installed previously)"
else
    echo "✅ Installed: zsh + plugins + zoxide + fzf."
    echo "✅ zsh is now the default shell (log out or run: exec zsh)"
fi
echo "✅ Config written to $RC_FILE"
