#!/usr/bin/env bash

set -e

BASHRC="$HOME/.bashrc"
HOST_NAME="my-server"

START_MARK="# >>> CUSTOM PS1 BLOCK >>>"
END_MARK="# <<< CUSTOM PS1 BLOCK <<<"

CUSTOM_BLOCK=$(cat <<EOF
$START_MARK
HOST_NAME="$HOST_NAME"
PS1="\\[\\e[38;5;208m\\]\\u@\$HOST_NAME\\[\\e[0m\\]:\\[\\e[38;5;75m\\]\\w\\[\\e[0m\\]\\$ "
alias cls="clear"
alias motd='run-parts /etc/update-motd.d/'
$END_MARK
EOF
)

# удалить старый блок
sed -i "/$START_MARK/,/$END_MARK/d" "$BASHRC" 2>/dev/null || true

# добавить новый
echo "$CUSTOM_BLOCK" >> "$BASHRC"

# обновить текущую сессию
# shellcheck disable=SC1090
source "$BASHRC" 2>/dev/null || true

MOTD_SCRIPT="/etc/update-motd.d/99-docker"

sudo tee "$MOTD_SCRIPT" >/dev/null <<'EOF'
#!/usr/bin/env bash

echo "-----------------ABOBA-------------------"
echo
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

for project in "${!projects[@]}"; do
    echo "$project"

    mapfile -t items <<< "${projects[$project]}"

    count=${#items[@]}

    for ((i=0;i<count-1;i++)); do
        line=${items[$i]}

        name=$(echo "$line" | cut -d'|' -f1)
        status=$(echo "$line" | cut -d'|' -f2)

        case "$status" in
            Up*) icon="🟢" ;;
            Exited*) icon="🔴" ;;
            *) icon="🟡" ;;
        esac

        if [ $i -eq $((count-2)) ]; then
            prefix="└──"
        else
            prefix="├──"
        fi

        printf "%s %s %-22s %s\n" "$prefix" "$icon" "$name" "$status"
    done

    echo
done

echo "-------------------------------------------"
EOF

sudo chmod +x "$MOTD_SCRIPT"

echo "Initial config installed"