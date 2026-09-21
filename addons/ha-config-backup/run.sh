#!/usr/bin/env bash
# HA Config GitHub Backup - scheduler loop.
# Self-contained: runs one backup cycle at addon start, then sleeps
# interval_minutes between cycles. No external cron / agent dependency.
set -uo pipefail

log() { echo "[$(date -u +%FT%TZ)] $*"; }

log "HA Config GitHub Backup addon starting (pid $$)"

while true; do
  /backup.sh
  rc=$?
  interval_minutes=$(jq -r '.interval_minutes // 360' /data/options.json 2>/dev/null || echo 360)
  if [ "$rc" -ne 0 ]; then
    log "backup cycle finished with rc=${rc}; retrying in ${interval_minutes}m"
  else
    log "backup cycle complete; next run in ${interval_minutes}m"
  fi
  sleep $((interval_minutes * 60))
done