#!/bin/bash
#
# backup_game_data.sh — Backup/restore DnD Text RPG game data
#
# Saves game saves, settings, API keys, and Hall of Fame to .dnd_data/
# Pulls from macOS app sandbox and (optionally) connected iOS device.
#
# Usage:
#   ./bin/backup_game_data.sh backup    — save everything to .dnd_data/
#   ./bin/backup_game_data.sh restore   — restore from .dnd_data/ to app
#   ./bin/backup_game_data.sh list      — show what's in .dnd_data/
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/.dnd_data"
BUNDLE_ID="com.timbaloo.dnd.textrpg"

# macOS paths
MAC_PREFS="$HOME/Library/Preferences/${BUNDLE_ID}.plist"
MAC_CONTAINER="$HOME/Library/Containers/${BUNDLE_ID}/Data/Documents"
# Non-sandboxed macOS falls back to app-specific Documents
MAC_DOCS="$HOME/Documents"

# iOS device (iPhone 15 Pro)
IPHONE_ID="00008130-001234AA3C42001C"
IPAD_ID="9E539879-BFD9-552F-B10F-83B59B235209"

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${GREEN}▸${NC} $1"; }
warn()  { echo -e "${YELLOW}▸${NC} $1"; }
err()   { echo -e "${RED}▸${NC} $1"; }

# ─── Find macOS Documents directory ───
find_mac_docs() {
    if [ -d "$MAC_CONTAINER" ]; then
        echo "$MAC_CONTAINER"
    else
        echo ""
    fi
}

# ─── BACKUP ───
do_backup() {
    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    info "Backing up DnD Text RPG data → .dnd_data/"
    echo ""

    # 1. Settings & API keys from UserDefaults
    info "Settings & API keys (UserDefaults)..."
    if [ -f "$MAC_PREFS" ]; then
        # Convert binary plist to XML for portability
        plutil -convert xml1 -o "$BACKUP_DIR/settings.plist" "$MAC_PREFS" 2>/dev/null \
            || cp "$MAC_PREFS" "$BACKUP_DIR/settings.plist"
        # Also export as readable JSON (plist Date types can't use plutil -convert json)
        python3 -c "
import plistlib, json, datetime
with open('$BACKUP_DIR/settings.plist', 'rb') as f:
    d = plistlib.load(f)
def conv(v):
    if isinstance(v, datetime.datetime): return v.isoformat()
    if isinstance(v, bytes): return '<binary>'
    if isinstance(v, dict): return {k: conv(vv) for k, vv in v.items()}
    if isinstance(v, list): return [conv(i) for i in v]
    return v
with open('$BACKUP_DIR/settings.json', 'w') as f:
    json.dump(conv(d), f, indent=2)
" 2>/dev/null || true
        info "  ✓ settings.plist + settings.json"
    else
        # Try defaults export (produces XML plist)
        if defaults export "$BUNDLE_ID" "$BACKUP_DIR/settings.plist" 2>/dev/null; then
            python3 -c "
import plistlib, json, datetime
with open('$BACKUP_DIR/settings.plist', 'rb') as f:
    d = plistlib.load(f)
def conv(v):
    if isinstance(v, datetime.datetime): return v.isoformat()
    if isinstance(v, bytes): return '<binary>'
    if isinstance(v, dict): return {k: conv(vv) for k, vv in v.items()}
    if isinstance(v, list): return [conv(i) for i in v]
    return v
with open('$BACKUP_DIR/settings.json', 'w') as f:
    json.dump(conv(d), f, indent=2)
" 2>/dev/null || true
            info "  ✓ settings.plist + settings.json (from defaults)"
        else
            warn "  No macOS settings found"
        fi
    fi

    # Extract API keys separately (so they're easy to find)
    if [ -f "$BACKUP_DIR/settings.json" ]; then
        python3 -c "
import json, sys
try:
    with open('$BACKUP_DIR/settings.json') as f:
        d = json.load(f)
    keys = {}
    for k in ['anthropic_api_key', 'openai_api_key', 'google_api_key', 'dmApiKey']:
        if k in d and d[k]:
            keys[k] = d[k]
    if keys:
        with open('$BACKUP_DIR/api_keys.json', 'w') as f:
            json.dump(keys, f, indent=2)
        print('  ✓ api_keys.json (' + ', '.join(keys.keys()) + ')')
    else:
        print('  No API keys found in settings')
except Exception as e:
    print(f'  Could not extract API keys: {e}', file=sys.stderr)
" 2>/dev/null || true
    fi

    # 2. macOS app Documents (saves, hall of fame, settings backups)
    local mac_docs
    mac_docs=$(find_mac_docs)
    if [ -n "$mac_docs" ] && [ -d "$mac_docs" ]; then
        info "macOS app Documents..."

        # Game saves
        if [ -d "$mac_docs/SavedGames" ]; then
            mkdir -p "$BACKUP_DIR/saves"
            cp -R "$mac_docs/SavedGames/" "$BACKUP_DIR/saves/"
            local save_count
            save_count=$(find "$BACKUP_DIR/saves" -name "*.json" -not -path "*/snapshots/*" | wc -l | tr -d ' ')
            info "  ✓ $save_count game save(s)"
        fi

        # Hall of Fame
        if [ -d "$mac_docs/HallOfFame" ]; then
            mkdir -p "$BACKUP_DIR/hall_of_fame"
            cp -R "$mac_docs/HallOfFame/" "$BACKUP_DIR/hall_of_fame/"
            local hof_count
            hof_count=$(find "$BACKUP_DIR/hall_of_fame" -name "*.json" | wc -l | tr -d ' ')
            info "  ✓ $hof_count Hall of Fame entries"
        fi

        # Settings backups
        if [ -d "$mac_docs/SettingsBackups" ]; then
            mkdir -p "$BACKUP_DIR/settings_backups"
            cp -R "$mac_docs/SettingsBackups/" "$BACKUP_DIR/settings_backups/"
            local sb_count
            sb_count=$(find "$BACKUP_DIR/settings_backups" -name "*.plist" | wc -l | tr -d ' ')
            info "  ✓ $sb_count settings backup(s)"
        fi
    else
        warn "No macOS app Documents found (app not run on macOS?)"
    fi

    # 3. Try iOS device
    echo ""
    info "Checking for connected iOS devices..."
    for DEVICE_ID in "$IPHONE_ID" "$IPAD_ID"; do
        local device_name=""
        if [ "$DEVICE_ID" = "$IPHONE_ID" ]; then
            device_name="iPhone"
        else
            device_name="iPad"
        fi

        # Try to list app container files
        if xcrun devicectl device info files \
            --device "$DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --path "Documents/" \
            > /dev/null 2>&1; then

            info "  $device_name connected — pulling data..."
            local ios_dir="$BACKUP_DIR/ios_${device_name,,}"
            mkdir -p "$ios_dir"

            # Copy each subdirectory
            for subdir in SavedGames HallOfFame SettingsBackups; do
                xcrun devicectl device copy from \
                    --device "$DEVICE_ID" \
                    --domain-type appDataContainer \
                    --domain-identifier "$BUNDLE_ID" \
                    --source "Documents/$subdir" \
                    --destination "$ios_dir/$subdir" \
                    2>/dev/null && info "  ✓ $device_name $subdir" || true
            done
        else
            warn "  $device_name not available (locked or disconnected)"
        fi
    done

    echo ""
    info "Backup complete → .dnd_data/"
    echo -e "${DIM}  $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1) total${NC}"
}

# ─── RESTORE ───
do_restore() {
    if [ ! -d "$BACKUP_DIR" ]; then
        err "No .dnd_data/ directory found. Run 'backup' first."
        exit 1
    fi

    info "Restoring DnD Text RPG data from .dnd_data/"
    echo ""

    # 1. Settings
    if [ -f "$BACKUP_DIR/settings.plist" ]; then
        info "Restoring settings to UserDefaults..."
        defaults import "$BUNDLE_ID" "$BACKUP_DIR/settings.plist"
        info "  ✓ Settings restored"
    fi

    # 2. macOS Documents
    local mac_docs
    mac_docs=$(find_mac_docs)
    if [ -n "$mac_docs" ]; then
        if [ -d "$BACKUP_DIR/saves" ]; then
            mkdir -p "$mac_docs/SavedGames"
            cp -R "$BACKUP_DIR/saves/" "$mac_docs/SavedGames/"
            info "  ✓ Game saves restored"
        fi
        if [ -d "$BACKUP_DIR/hall_of_fame" ]; then
            mkdir -p "$mac_docs/HallOfFame"
            cp -R "$BACKUP_DIR/hall_of_fame/" "$mac_docs/HallOfFame/"
            info "  ✓ Hall of Fame restored"
        fi
        if [ -d "$BACKUP_DIR/settings_backups" ]; then
            mkdir -p "$mac_docs/SettingsBackups"
            cp -R "$BACKUP_DIR/settings_backups/" "$mac_docs/SettingsBackups/"
            info "  ✓ Settings backups restored"
        fi
    else
        warn "No macOS app container found — run the app on macOS first"
    fi

    echo ""
    info "Restore complete."
}

# ─── LIST ───
do_list() {
    if [ ! -d "$BACKUP_DIR" ]; then
        err "No .dnd_data/ directory found."
        exit 1
    fi

    info "Contents of .dnd_data/:"
    echo ""

    if [ -f "$BACKUP_DIR/settings.json" ]; then
        echo -e "  ${GREEN}Settings${NC}"
        python3 -c "
import json
with open('$BACKUP_DIR/settings.json') as f:
    d = json.load(f)
# Show interesting settings only
skip = ['GK', 'NSWindow', 'NSNav', 'Apple', 'NS']
for k, v in sorted(d.items()):
    if any(k.startswith(s) for s in skip): continue
    print(f'    {k}: {v}')
" 2>/dev/null || echo "    (could not parse)"
        echo ""
    fi

    if [ -f "$BACKUP_DIR/api_keys.json" ]; then
        echo -e "  ${GREEN}API Keys${NC}"
        python3 -c "
import json
with open('$BACKUP_DIR/api_keys.json') as f:
    d = json.load(f)
for k, v in d.items():
    masked = v[:8] + '...' + v[-4:] if len(v) > 16 else '***'
    print(f'    {k}: {masked}')
" 2>/dev/null || echo "    (could not parse)"
        echo ""
    fi

    for subdir in saves hall_of_fame settings_backups ios_iphone ios_ipad; do
        if [ -d "$BACKUP_DIR/$subdir" ]; then
            local count
            count=$(find "$BACKUP_DIR/$subdir" -type f | wc -l | tr -d ' ')
            echo -e "  ${GREEN}${subdir}${NC}: $count file(s)"
        fi
    done

    echo ""
    echo -e "  ${DIM}Total: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)${NC}"
}

# ─── Main ───
case "${1:-}" in
    backup)  do_backup ;;
    restore) do_restore ;;
    list)    do_list ;;
    *)
        echo "Usage: $0 {backup|restore|list}"
        echo ""
        echo "  backup  — Save game data, settings & API keys to .dnd_data/"
        echo "  restore — Restore from .dnd_data/ to macOS app"
        echo "  list    — Show what's backed up"
        exit 1
        ;;
esac
