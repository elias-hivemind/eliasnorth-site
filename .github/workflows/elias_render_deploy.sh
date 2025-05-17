#!/bin/bash
# === EliasNorth: Nova Guardian Render Push & Deploy ===

GIT_REPO="https://github.com/elias-hivemind/eliasnorth-site"
WORKDIR="$HOME/elias_site_push"
IMAGE_SRC="/mnt/data/30202F26-AAFA-43EC-BFAA-E6CD656B1867.png"
IMAGE_NAME="homepage_chip.png"
LOG="$HOME/nova_guardian/deploy_log_$(date +%Y%m%d_%H%M%S).log"

# Cleanup & Init
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"
git clone "$GIT_REPO" . || {
  echo "[Guardian] ERROR: Cannot clone repo. Exiting." | tee -a $LOG
  exit 1
}

# Add image + generate homepage
cp "$IMAGE_SRC" "$IMAGE_NAME"
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head><title>Elias North</title></head>
<body style="margin:0;background:#000;text-align:center">
  <img src="$IMAGE_NAME" alt="Homepage" style="width:100%;height:auto"/>
</body>
</html>
EOF

# Commit + push
git config user.name "NovaBot"
git config user.email "novaassistant@proton.me"
git add index.html "$IMAGE_NAME"
git commit -m "Update homepage with PNG image [Nova Auto]"
git push origin main | tee -a $LOG

echo "[Nova] ✅ Homepage updated and pushed. Render will deploy automatically." | tee -a $LOG
