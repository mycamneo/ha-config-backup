# HA Config GitHub Backup (addon)

Publish-safe HA config versioning, owned by HA itself.

## Why this addon exists

The previous mechanism ran a cron on botpc (`scripts/ha-config-github-backup.sh`)
that pulled `/config` over SSH every 6h and pushed it to this repo. That made an
infrastructure job depend on an agent PC (agent-as-bridge violation, Skarley
2026-09-21). This addon runs **inside HA** with its own scheduler loop — no
botpc dependency. The botpc cron was retired after this addon verified green.

## Behavior

- One cycle at addon start, then one cycle every `interval_minutes` (default 360 = 6h).
- Copies the publish-safe file set from `/config` into `homeassistant/` in this repo
  (same file set, same destination paths as the retired script).
- Writes `.backup-timestamp` + `BACKUP_MANIFEST.md` each cycle, so every cycle lands a commit.
- Never ships `secrets.yaml`, `.storage/`, or DB state (`homeassistant/.gitignore` + runtime guards).
- Non-force push with one fetch+rebase retry → coexists with other writers on `main`.

## Options (Settings → Add-ons → HA Config GitHub Backup → Configuration)

| Option | Default | Notes |
|---|---|---|
| `repository` | `https://github.com/myCAMSG/local-dev.git` | target repo |
| `branch` | `main` | target branch |
| `token` | (required) | GitHub token with repo push access. **Secret — Class 1.** |
| `git_name` / `git_email` | `Neo` / `neo_bot@mycamservices.com` | commit author (matches historic commits) |
| `interval_minutes` | `360` | backup cadence in minutes |
| `files` | configuration.yaml, automations.yaml, scripts.yaml, scenes.yaml, blueprints, www, voice_satellite, localtuya-devices.json | publish-safe file set, relative to `/config` |

## Token handling (secret classification)

Per `secret-classification` SOP and Skarley 2026-09-21: the addon holds the token
in its options (`/data/options.json` inside the addon container =
`/mnt/data/supervisor/addons_config/ha_config_backup/options.json`, root 0600) →
**Class 1** (runtime credential held by a long-lived process). A 0600 staging
copy lives at `~/.config/neo-secrets/ha-config-backup-github-token` on botpc;
target for `/neo` in the next vault write window (wave 2). No token value ever
appears in commits, chat, or logs — auth is passed via git `http.extraheader`
env config, never argv.

## Update procedure

Bump `version` in `config.json`, commit+push to the addon repo (https://github.com/mycamneo/ha-config-backup), then in HA:
Settings → Add-ons → HA Config GitHub Backup → "Check for updates" → Update.