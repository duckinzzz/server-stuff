#!/bin/bash

BASHRC="$HOME/.bashrc"
MY_HOST="my-server"

START_MARK="# >>> CUSTOM PS1 BLOCK >>>"
END_MARK="# <<< CUSTOM PS1 BLOCK <<<"

read -r -d '' CUSTOM_BLOCK <<EOF
$START_MARK
# Custom PS1
HOST_NAME="$MY_HOST"
PS1="\\[\\e[38;5;208m\\]\\u@\$HOST_NAME\\[\\e[0m\\]:\\[\\e[38;5;75m\\]\\w\\[\\e[0m\\]\\$ "
# Aliases
alias cls="clear"
alias motd='run-parts /etc/update-motd.d/'
$END_MARK
EOF

if grep -q "$START_MARK" "$BASHRC"; then
    # Перезаписываем существующий блок
    sed -i "/$START_MARK/,/$END_MARK/c\\
$CUSTOM_BLOCK
" "$BASHRC"
else
    echo "$CUSTOM_BLOCK" >> "$BASHRC"
fi

source "$BASHRC" 2>/dev/null || true

MOTD_SCRIPT="/etc/update-motd.d/99-docker"

if [ -d /etc/update-motd.d ]; then
    sudo tee "$MOTD_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash

echo "-----------------WELCOME-------------------"
echo
echo "🖥  Host: $(hostname)"
echo "⏱  Uptime: $(uptime -p)"
echo

# Docker status
if command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker containers:"
    echo
    printf "%-2s %-25s %s\n" "" "NAME" "STATUS"
    echo "-------------------------------------------"

    mapfile -t containers < <(docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null)

    if [ ${#containers[@]} -eq 0 ]; then
        echo "🟡 Docker not running"
    else
        for line in "${containers[@]}"; do
            name=$(echo "$line" | cut -f1)
            status=$(echo "$line" | cut -f2-)
            case "$status" in
                Up*)    icon="🟢" ;;
                Exited*) icon="🔴" ;;
                *)       icon="🟡" ;;
            esac
            printf "%-2s %-25s %s\n" "$icon" "$name" "$status"
        done
    fi
else
    echo "🔴 Docker not installed"
fi

echo "-------------------------------------------"
EOF

    sudo chmod +x "$MOTD_SCRIPT"
fi

PROFILE_SCRIPT="/etc/profile.d/99-docker.sh"
if [ ! -d /etc/update-motd.d ] && [ -w /etc/profile.d ]; then
    sudo tee "$PROFILE_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash

echo "-----------------WELCOME-------------------"
echo
echo "🖥  Host: $(hostname)"
echo "⏱  Uptime: $(uptime -p)"
echo

if command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker containers:"
    echo
    printf "%-2s %-25s %s\n" "" "NAME" "STATUS"
    echo "-------------------------------------------"

    mapfile -t containers < <(docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null)

    if [ ${#containers[@]} -eq 0 ]; then
        echo "🟡 Docker not running"
    else
        for line in "${containers[@]}"; do
            name=$(echo "$line" | cut -f1)
            status=$(echo "$line" | cut -f2-)
            case "$status" in
                Up*)    icon="🟢" ;;
                Exited*) icon="🔴" ;;
                *)       icon="🟡" ;;
            esac
            printf "%-2s %-25s %s\n" "$icon" "$name" "$status"
        done
    fi
else
    echo "🔴 Docker not installed"
fi

echo "-------------------------------------------"
EOF

    sudo chmod +x "$PROFILE_SCRIPT"
fi

sudo chmod -x /etc/update-motd.d/[0-9]*
sudo chmod +x /etc/update-motd.d/99-docker

echo "Initial config installed"
