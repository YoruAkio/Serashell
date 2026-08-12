#!/bin/bash
# Screenshot script for Hyprland
# Dual monitor: eDP-1 (main), HDMI-A-2 (secondary)
# Fix: auto-kills lingering hyprpicker to prevent stuck + cursor after ESC

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

# ─── Monitor config ────────────────────────────────────────────────────────────
MONITOR_MAIN="eDP-1"
MONITOR_SECOND="HDMI-A-2"

# ─── Paths ─────────────────────────────────────────────────────────────────────
MODE="${1:-region}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_${TIMESTAMP}.png"
SCREENSHOT_PATH="$SCREENSHOT_DIR/$FILENAME"

# ─── Freeze cleanup ────────────────────────────────────────────────────────────
# @fix: After ESC or cancel, hyprpicker may linger and lock the cursor as a + crosshair.
#       We kill it immediately after every hyprshot call and also on trap for safety.
cleanup_freeze() {
    pkill -x hyprpicker 2>/dev/null || true
    pkill -x slurp     2>/dev/null || true
}

# Catches: normal exit, Ctrl+C, SIGTERM, terminal close
trap 'cleanup_freeze' EXIT INT TERM HUP

# ─── Clipboard ─────────────────────────────────────────────────────────────────
copy_to_clipboard() {
    local path="$1"
    # Paste as image in apps that support image/png (e.g. Discord, Telegram)
    wl-copy --type image/png < "$path"
    # Middle-click paste gives the file:// URI
    printf '%s' "file://$path" | wl-copy --primary
}

# ─── Notifications ─────────────────────────────────────────────────────────────
notify_success() {
    local path="$1"
    local extra_msg="${2:-}"
    local body
    body="$(basename "$path")"
    [[ -n "$extra_msg" ]] && body="$body\n$extra_msg"
    notify-send \
        --icon="$path" \
        --app-name="Screenshot" \
        --urgency=low \
        --expire-time=4000 \
        "📸 Screenshot Saved" \
        "$body"
}

notify_failure() {
    local reason="${1:-Could not capture screenshot}"
    notify-send \
        --icon="dialog-error" \
        --app-name="Screenshot" \
        --urgency=normal \
        --expire-time=3000 \
        "Screenshot Failed" \
        "$reason"
}

# ─── Capture helpers ───────────────────────────────────────────────────────────
# All hyprshot calls go through here so cleanup_freeze always runs after.
run_hyprshot() {
    hyprshot "$@" --silent --output-folder "$SCREENSHOT_DIR" --filename "$FILENAME"
    local code=$?
    cleanup_freeze   # <-- immediate cleanup; doesn't wait for EXIT trap
    return "$code"
}

# Capture a named monitor (pass monitor name as $1)
capture_monitor() {
    local monitor="$1"
    # hyprshot -m output -m <MONITOR_NAME> selects a specific output directly
    run_hyprshot -m output -m "$monitor" --freeze
}

# ─── Mode dispatch ─────────────────────────────────────────────────────────────
case "$MODE" in
    "region")
        run_hyprshot -m region --freeze
        ;;

    "window")
        run_hyprshot -m window --freeze
        ;;

    # Active (focused) monitor — no monitor name needed
    "output" | "monitor-active")
        run_hyprshot -m output -m active --freeze
        ;;

    # Named monitors
    "monitor-main")
        capture_monitor "$MONITOR_MAIN"
        ;;

    "monitor-second")
        capture_monitor "$MONITOR_SECOND"
        ;;

    # Capture both monitors as separate files in one call
    "monitor-all")
        TS=$(date +"%Y-%m-%d_%H-%M-%S")
        F_MAIN="screenshot_${TS}_main.png"
        F_SECOND="screenshot_${TS}_second.png"

        hyprshot -m output -m "$MONITOR_MAIN" \
            --silent --output-folder "$SCREENSHOT_DIR" --filename "$F_MAIN"
        hyprshot -m output -m "$MONITOR_SECOND" \
            --silent --output-folder "$SCREENSHOT_DIR" --filename "$F_SECOND"

        cleanup_freeze

        [[ -f "$SCREENSHOT_DIR/$F_MAIN" ]]   && notify_success "$SCREENSHOT_DIR/$F_MAIN"   "Main ($MONITOR_MAIN)"
        [[ -f "$SCREENSHOT_DIR/$F_SECOND" ]] && notify_success "$SCREENSHOT_DIR/$F_SECOND" "Second ($MONITOR_SECOND)"
        exit 0
        ;;

    # Region capture + copy image binary to clipboard
    "region-clipboard" | "region-copy")
        run_hyprshot -m region --freeze

        if [[ -f "$SCREENSHOT_PATH" ]]; then
            copy_to_clipboard "$SCREENSHOT_PATH"
            notify_success "$SCREENSHOT_PATH" "Image copied to clipboard"
        else
            notify_failure "Region capture cancelled or failed"
        fi
        exit 0
        ;;

    *)
        cat <<USAGE
Usage: $(basename "$0") <mode>

Modes:
  region            Select a region with crosshair
  window            Capture the focused window
  output            Capture the active (focused) monitor
  monitor-main      Capture $MONITOR_MAIN (main monitor)
  monitor-second    Capture $MONITOR_SECOND (second monitor)
  monitor-all       Capture both monitors as separate files
  region-clipboard  Select region → save + copy image to clipboard

Env:
  HYPRSHOT_DIR      Override screenshot save path (default: ~/Pictures/Screenshots)
USAGE
        exit 1
        ;;
esac

# ─── Post-capture notification (non-early-exit modes) ──────────────────────────
if [[ -f "$SCREENSHOT_PATH" ]]; then
    notify_success "$SCREENSHOT_PATH"
else
    notify_failure
fi
