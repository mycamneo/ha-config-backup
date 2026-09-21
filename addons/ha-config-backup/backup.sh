#!/usr/bin/env bash
# HA Config GitHub Backup - one cycle.
# Copies the publish-safe file set from /config into <repo>/homeassistant/,
# stamps .backup-timestamp + BACKUP_MANIFEST.md (so every cycle lands a commit),
# and pushes to origin. Non-force push with one fetch+rebase retry, so it
# coexists with any other writer on the same branch.
set -uo pipefail
unset GIT_DIR
OPT=/data/options.json

REPO_URL=$(jq -r '.repository' "$OPT")
BRANCH=$(jq -r '.branch' "$OPT")
TOKEN=$(jq -r '.token // ""' "$OPT")
GIT_NAME=$(jq -r '.git_name // "Neo"' "$OPT")
GIT_EMAIL=$(jq -r '.git_email // "neo_bot@mycamservices.com"' "$OPT")
mapfile -t FILES < <(jq -r '.files[]?' "$OPT")
if [ "${#FILES[@]}" -eq 0 ]; then
  FILES=(configuration.yaml automations.yaml scripts.yaml scenes.yaml blueprints www voice_satellite localtuya-devices.json)
fi

# Git identity + push auth via environment (never argv): token stays out of ps.
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=http.extraheader
export GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$TOKEN" | base64 -w0)"
export GIT_CONFIG_KEY_1=user.name
export GIT_CONFIG_VALUE_1="$GIT_NAME"
export GIT_CONFIG_KEY_2=user.email
export GIT_CONFIG_VALUE_2="$GIT_EMAIL"

WORK=/data/work
REPO="$WORK/repo"
DEST="$REPO/homeassistant"
mkdir -p "$WORK" "$DEST"

if [ ! -d "$REPO/.git" ]; then
  git clone -q --branch "$BRANCH" --single-branch "$REPO_URL" "$REPO" || { echo "clone failed" >&2; exit 2; }
else
  ( cd "$REPO" && git fetch -q origin "$BRANCH" ) || true
  ( cd "$REPO" && git checkout -q -B "$BRANCH" "origin/$BRANCH" ) || true
fi
cd "$REPO" || exit 3

# Publish-safe copy (same file set the retired botpc script used)
for f in "${FILES[@]}"; do
  [ -e "/config/$f" ] && cp -a "/config/$f" "$DEST/" 2>/dev/null
done
# Belt-and-suspenders: never ship secrets/state even if listed or delivered
rm -f "$DEST/secrets.yaml" "$DEST/home-assistant_v2.db" "$DEST/*.db-wal" "$DEST/*.db-shm"
rm -rf "$DEST/.storage"

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$DEST/.backup-timestamp"
{
  echo "# HA config backup manifest"
  echo "- source: /config on HA VM 192.168.68.205"
  echo "- method: HA addon ha_config_backup (in-HA scheduler); publish-safe file set"
  echo "- updated: $(date -u)"
  echo "- secrets/state excluded; see README.md"
} > "$DEST/BACKUP_MANIFEST.md"

if [ -n "$(git status --porcelain -- homeassistant)" ]; then
  git add -- homeassistant
  git commit -q -m "chore(ha): sync HA config backup $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if git push -q origin "$BRANCH"; then
    echo "pushed: $(git rev-parse --short HEAD)"
  else
    git pull -q --rebase origin "$BRANCH" 2>/dev/null || true
    if git push -q origin "$BRANCH"; then
      echo "pushed (after rebase): $(git rev-parse --short HEAD)"
    else
      echo "PUSH FAILED" >&2
      exit 1
    fi
  fi
else
  echo "no changes"
fi