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

# сначала выводим только стэки (где >1 контейнера)
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

        if [ $i -eq $((count-1)) ]; then
            prefix="└──"
        else
            prefix="├──"
        fi

        printf "%s %s %-22s %s\n" "$prefix" "$icon" "$name" "$status"
    done
done

# потом выводим одиночные контейнеры
for project in "${!projects[@]}"; do
    mapfile -t items <<< "${projects[$project]}"

    filtered=()
    for line in "${items[@]}"; do
        [ -z "$line" ] && continue
        filtered+=("$line")
    done

    count=${#filtered[@]}
    [ "$count" -ne 1 ] && continue

    # вставить пустую строку только один раз перед первым одиночным контейнером
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

echo "Initial config installed"