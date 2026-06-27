#!/usr/bin/env bash
set -e

# ── Определяем активный шелл ──────────────────────────────────────────────────
CURRENT_SHELL="$(ps -p $$ -o comm= 2>/dev/null || basename "$SHELL")"
case "$CURRENT_SHELL" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.bashrc" ;;
esac

START_MARK="# >>> CUSTOM PS1 BLOCK >>>"
END_MARK="# <<< CUSTOM PS1 BLOCK <<<"

# ── Функция чистой перезаписи блока ───────────────────────────────────────────
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

# ── Интерактивный ввод ────────────────────────────────────────────────────────
echo ""
echo "=== init-config setup ==="
echo ""
echo "Введи имя сервера (например: prod-01, dev-box):"
read -r HOST_NAME </dev/tty
HOST_NAME="${HOST_NAME:-my-server}"

echo ""
echo "Выбери цвет промпта (для user@host):"
printf "  1) \e[38;5;208muser@${HOST_NAME}\e[0m  (оранжевый)\n"
printf "  2) \e[38;5;82muser@${HOST_NAME}\e[0m  (зелёный)\n"
printf "  3) \e[38;5;75muser@${HOST_NAME}\e[0m  (синий)\n"
printf "  4) \e[38;5;135muser@${HOST_NAME}\e[0m  (фиолетовый)\n"
printf "  5) \e[38;5;196muser@${HOST_NAME}\e[0m  (красный)\n"
printf "  6) \e[38;5;213muser@${HOST_NAME}\e[0m  (розовый)\n"
printf "  7) \e[38;5;255muser@${HOST_NAME}\e[0m  (белый)\n"
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
echo "✅ Шелл:  $CURRENT_SHELL → $RC_FILE"
echo "✅ Хост:  $HOST_NAME"
printf "✅ Цвет:  \e[38;5;${COLOR_CODE}muser@${HOST_NAME}\e[0m\n"
echo ""

# ── Блок конфига ──────────────────────────────────────────────────────────────
if [ "$CURRENT_SHELL" = "zsh" ]; then
    PS1_LINE="PS1=\"%F{$COLOR_CODE}%n@${HOST_NAME}%f:%F{75}%~%f\$ \""
else
    PS1_LINE="PS1=\"\\\\[\\\\e[38;5;${COLOR_CODE}m\\\\]\\\\u@${HOST_NAME}\\\\[\\\\e[0m\\\\]:\\\\[\\\\e[38;5;75m\\\\]\\\\w\\\\[\\\\e[0m\\\\]\\\\$ \""
fi

CUSTOM_BLOCK="
${START_MARK}
HOST_NAME=\"${HOST_NAME}\"
${PS1_LINE}
alias motd='run-parts /etc/update-motd.d/'
${END_MARK}"

# ── Пишем в rc-файл ───────────────────────────────────────────────────────────
remove_block "$RC_FILE"
echo "$CUSTOM_BLOCK" >> "$RC_FILE"

# ── MOTD скрипт ───────────────────────────────────────────────────────────────
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

# ── Применяем в текущую сессию ────────────────────────────────────────────────
# shellcheck disable=SC1090
source "$RC_FILE" 2>/dev/null || true

echo "✅ Initial config installed. Рестартни шелл или запусти: source $RC_FILE"