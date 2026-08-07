### Initial config for clean machine

```bash
. <(curl -fsSL https://raw.githubusercontent.com/duckinzzz/server-stuff/main/init-config.sh)
```

Idempotent setup script. First run installs everything; later runs only update hostname/prompt color.

**What it sets up:**
- zsh (default shell) + history persistence, completion, zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions
- zoxide (dir jumping) + fzf
- Custom PS1 (hostname + color)
- Optional Docker install (prompt, default yes)
- MOTD showing docker containers

**Re-run:** `./init-config.sh` — updates name/color only.
**Force full reinstall:** `rm ~/.init-config.done && ./init-config.sh`

#### MOTD:
```text
-----------------WELCOME-------------------

🖥  Host: Duck-PC
⏱  Uptime: up 5 hours, 47 minutes

🐳 Docker containers:

   NAME                      STATUS
-------------------------------------------
🟢 my-wireguard              Up About an hour
🔴 old-db                    Exited (1) 2 hours ago
🟡 cache-service             Restarting (3) 5 minutes ago
-------------------------------------------
```
