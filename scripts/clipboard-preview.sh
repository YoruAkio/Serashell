#!/bin/sh

set -eu

preview_dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell-clipboard"
mkdir -p "$preview_dir"
chmod 700 "$preview_dir"

cliphist list | while IFS="$(printf '\t')" read -r entry_id entry_label; do
    case "$entry_label" in
        *" png "*|*" jpg "*|*" jpeg "*|*" gif "*|*" bmp "*|*" webp "*)
            preview="$preview_dir/$entry_id.png"
            if [ ! -s "$preview" ]; then
                temporary="$preview.tmp"
                printf '%s' "$entry_id" | cliphist decode > "$temporary"
                mv "$temporary" "$preview"
            fi
            ;;
    esac
done
