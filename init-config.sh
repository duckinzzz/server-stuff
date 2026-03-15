#!/usr/bin/env bash

set -e

BASHRC="$HOME/.bashrc"
HOST_NAME="my-server"

START="# >>> CUSTOM PS1 BLOCK >>>"
END="# <<< CUSTOM PS1 BLOCK <<<"

BLOCK=$(cat <<EOF
$START
HOST_NAME="$HOST_NAME"
PS1="\\[\\e[38;5;208m\\]\\u@\$HOST_NAME\\[\\e[0m\\]:\\[\\e[38;5;75m\\]\\w\\[\\e[0m\\]\\$ "
alias cls="clear"
alias motd='run-parts /etc/update-motd.d/'
$END
EOF
)

# удаляем старый блок
sed -i "/$START/,/$END/d" "$BASHRC" 2>/dev/null || true
echo "$BLOCK" >> "$BASHRC"

# MOTD script
sudo tee /etc/update-motd.d/99-docker >/dev/null <<'EOF'
#!/usr/bin/env bash

echo "-----------------WELCOME-------------------"
echo
echo "🖥  Host: $(hostname)"
echo "⏱  Uptime: $(uptime -p)"
echo

if ! command -v docker >/dev/null 2>&1; then
    echo "🔴 Docker not installed"
    exit 0
fi

echo "🐳 Docker compose projects:"
echo

mapfile -t containers < <(
    docker ps -a --format '{{.Label "com.docker.compose.project"}}|{{.Names}}|{{.Status}}'
)

declare -A projects

for line in "${containers[@]}"; do
    project="${line%%|*}"
    rest="${line#*|}"

    name="${rest%%|*}"
    status="${rest#*|}"

    [ -z "$project" ] && project="standalone"

    projects["$project"]+="$name|$status"$'\n'
done

for project in $(printf "%s\n" "${!projects[@]}" | sort); do
    echo "$project"

    mapfile -t items <<< "${projects[$project]}"

    count=0
    for i in "${items[@]}"; do
        [ -n "$i" ] && ((count++))
    done

    index=0
    for line in "${items[@]}"; do
        [ -z "$line" ] && continue

        name="${line%%|*}"
        status="${line#*|}"

        case "$status" in
            Up*) icon="🟢" ;;
            Exited*) icon="🔴" ;;
            *) icon="🟡" ;;
        esac

        ((index++))

        if [ "$index" -eq "$count" ]; then
            prefix="└──"
        else
            prefix="├──"
        fi

        printf "%s %s %-25s %s\n" "$prefix" "$icon" "$name" "$status"
    done

    echo
done

echo "-------------------------------------------"
EOF

sudo chmod +x /etc/update-motd.d/99-docker

# отключаем стандартные MOTD
sudo chmod -x /etc/update-motd.d/[0-9]* 2>/dev/null || true
sudo chmod +x /etc/update-motd.d/99-docker

echo "Initial config installed"