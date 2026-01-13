#!/bin/bash

# ps1 coloring
echo 'PS1="\[\e[38;5;208m\]\u@myserver\[\e[0m\]:\[\e[38;5;75m\]\w\[\e[0m\]$ "' >> ~/.bashrc

echo 'alias cls="clear"' >> ~/.bashrc

source ~/.bashrc

sudo tee /etc/update-motd.d/99-docker > /dev/null <<'EOF'
#!/bin/bash

echo "-----------------WELCOME-------------------"
echo
echo "🖥  Host: $(hostname)"
echo "⏱  Uptime: $(uptime -p)"
echo

if command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker containers:"
    echo
    
    # Заголовок таблицы
    printf "%-2s %-25s %s\n" "" "NAME" "STATUS"
    echo "-------------------------------------------"

    # Список контейнеров
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

sudo chmod +x /etc/update-motd.d/99-docker

echo "Config installed"
