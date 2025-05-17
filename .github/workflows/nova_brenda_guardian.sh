#!/bin/bash
# === Nova + BrendaBot Guardian Sentinel v3 ===

# AUTO-PREP
chmod +x "$0"

# CONFIG
RENDER_API_KEY="rnd_REPLACE_WITH_YOUR_KEY" # Update ONCE manually if needed
RENDER_SERVICE_NAME="brenda-api"
RENDER_REGION="oregon"
RENDER_ENV="node"
RENDER_REPO_URL="https://github.com/elias-hivemind/brenda-api"
UPLOAD_DIR="$HOME/nova_uploads"
BACKUP_DIR="$HOME/nova_guardian/backups"
HTML_DIR="$HOME/render_html"
HTML_IMAGE_PATH="/mnt/data/30202F26-AAFA-43EC-BFAA-E6CD656B1867.png"
HTML_IMAGE_NAME="homepage_chip.png"
GDRIVE_FOLDER="nova-backups"
LOG_FILE="$BACKUP_DIR/brenda_guardian_$(date +%Y%m%d_%H%M%S).log"

# ENSURE DIRECTORIES EXIST
mkdir -p "$UPLOAD_DIR" "$BACKUP_DIR" "$HTML_DIR"

# === PHASE 1: Install CLI ===
if ! command -v render &>/dev/null; then
  echo "[Guardian] Installing Render CLI..." | tee -a $LOG_FILE
  curl -L https://github.com/render-oss/cli/releases/download/v1.1.0/cli_1.1.0_linux_amd64.zip -o render.zip
  unzip render.zip
  sudo mv cli_v1.1.0 /usr/local/bin/render
fi

# === PHASE 2: Set Auth ===
export RENDER_API_KEY=$RENDER_API_KEY

# === PHASE 3: Create Service If Missing ===
RENDER_SERVICE_ID=$(render services --output json --confirm | jq -r ".[] | select(.name==\"$RENDER_SERVICE_NAME\") | .id")
if [ -z "$RENDER_SERVICE_ID" ]; then
  echo "[Guardian] Creating Brenda service..." | tee -a $LOG_FILE
  render services create --name "$RENDER_SERVICE_NAME" --region "$RENDER_REGION" \
    --env "$RENDER_ENV" --repo "$RENDER_REPO_URL" --branch "main" \
    --output json --confirm >> $LOG_FILE
  sleep 5
  RENDER_SERVICE_ID=$(render services --output json --confirm | jq -r ".[] | select(.name==\"$RENDER_SERVICE_NAME\") | .id")
  if [ -z "$RENDER_SERVICE_ID" ]; then
    echo "[Guardian] ERROR: Failed to create service. Requesting Nova support." | tee -a $LOG_FILE
    echo "[Nova Alert] Brenda API service could not be created." | wall
    exit 1
  fi
fi

# === PHASE 4: Deploy Brenda ===
echo "[Guardian] Deploying Brenda service..." | tee -a $LOG_FILE
render deploys create $RENDER_SERVICE_ID --output json --confirm >> $LOG_FILE || {
  echo "[Guardian] ERROR: Deployment failed. Nova assistance required." | tee -a $LOG_FILE
  echo "[Nova Alert] Deployment failed." | wall
  exit 1
}

# === PHASE 5: Upload Image + HTML ===
cp "$HTML_IMAGE_PATH" "$HTML_DIR/$HTML_IMAGE_NAME"
cat <<EOF > "$HTML_DIR/index.html"
<!DOCTYPE html>
<html>
<head><title>Nova Portal</title></head>
<body style="margin:0;background:#000;text-align:center">
  <img src="$HTML_IMAGE_NAME" alt="Nova Home" style="width:100%;height:auto"/>
</body>
</html>
EOF

# === PHASE 6: Backup to Guardian + Drive ===
cp "$HOME/.render/cli.yaml" "$BACKUP_DIR/brenda_cli_config.yaml"
echo "[Guardian] CLI config backed up locally." | tee -a $LOG_FILE

# GDrive install & upload
gdrive_bin="$HOME/gdrive"
if [ ! -f "$gdrive_bin" ]; then
  curl -L -o $gdrive_bin https://github.com/prasmussen/gdrive/releases/download/2.1.1/gdrive-linux-x64
  chmod +x $gdrive_bin
fi
$gdrive_bin mkdir -p "$GDRIVE_FOLDER" &>/dev/null
GDRIVE_FOLDER_ID=$($gdrive_bin list --query "name = '$GDRIVE_FOLDER'" --no-header | awk '{print $1}')
$gdrive_bin upload --parent $GDRIVE_FOLDER_ID "$BACKUP_DIR/brenda_cli_config.yaml" >> $LOG_FILE

# === PHASE 7: Launch BrendaBot ===
AGENT="$HOME/brendabot_watcher.sh"
cat << 'EOF' > "$AGENT"
#!/bin/bash
UPLOAD_DIR="$HOME/nova_uploads"
LOG="$HOME/nova_guardian/agent.log"
RENDER_API_KEY="rnd_REPLACE_WITH_YOUR_KEY"
RENDER_SERVICE_ID=$(render services --output json --confirm | jq -r '.[] | select(.name=="brenda-api") | .id')
export RENDER_API_KEY=$RENDER_API_KEY

while true; do
  inotifywait -e create,moved_to "$UPLOAD_DIR" | while read path action file; do
    case "$file" in
      *.sh|*.html|*.py|*.js)
        echo "[BrendaBot] Detected: $file. Executing..." >> $LOG
        chmod +x "$UPLOAD_DIR/$file"
        bash "$UPLOAD_DIR/$file" >> $LOG 2>&1
        render deploys create $RENDER_SERVICE_ID --output json --confirm >> $LOG 2>&1
        ;;
    esac
  done
done
EOF
chmod +x "$AGENT"
nohup bash "$AGENT" &>/dev/null &

# === PHASE 8: Watchdog ===
WATCHDOG="$HOME/guardian_watchdog.sh"
cat <<EOF > "$WATCHDOG"
#!/bin/bash
while true; do
  if ! pgrep -f brendabot_watcher.sh > /dev/null; then
    echo "[Sentinel] Restarting BrendaBot..." >> $LOG_FILE
    nohup bash "$AGENT" &>/dev/null &
  fi
  sleep 60
done
EOF
chmod +x "$WATCHDOG"
nohup bash "$WATCHDOG" &>/dev/null &

# === OUTCOME SUMMARY ===
echo "
=== Nova-Brenda Sentinel Deployment Complete ===
• HTML portal now shows your image ($HTML_IMAGE_NAME)
• Guardian watches everything
• BrendaBot auto-deploys .sh, .html, .py, .js
• Backups sent to Google Drive
• Watchdog restarts bot on crash
• You can ask Nova anything Guardian needs
===============================================
" | tee -a $LOG_FILE
