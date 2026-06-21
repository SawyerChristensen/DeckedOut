#!/bin/bash
#
# shrink_enchanted_fronts.sh
#
# Halves the width and height of every enchanted card front PNG and strips
# unneeded metadata to reduce on-disk / app bundle size.
#
# Steps per image:
#   1. sips  -> resize to half width/height (high-quality downscale)
#   2. pngcrush -> recompress + strip ancillary metadata chunks
#
# A timestamped backup of each original is kept alongside the script unless
# DRY_RUN=1 is set.

set -euo pipefail

ASSET_DIR="/Users/sawyerchristensen/Documents/DeckedOut/DeckedOut MessagesExtension/Assets.xcassets/cardFrontsEnchanted"
BACKUP_DIR="/Users/sawyerchristensen/Documents/DeckedOut/cardFrontsEnchanted_backup"
DRY_RUN="${DRY_RUN:-0}"

PNGCRUSH="$(command -v pngcrush || true)"

if [[ ! -d "$ASSET_DIR" ]]; then
    echo "Asset directory not found: $ASSET_DIR" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

total_before=0
total_after=0
count=0

while IFS= read -r -d '' png; do
    count=$((count + 1))
    name="$(basename "$png")"

    # current dimensions
    w=$(sips -g pixelWidth  "$png" | awk '/pixelWidth/  {print $2}')
    h=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ {print $2}')
    new_w=$((w / 2))
    new_h=$((h / 2))

    size_before=$(stat -f%z "$png")
    total_before=$((total_before + size_before))

    echo "[$count] $name  ${w}x${h} -> ${new_w}x${new_h}  ($(numfmt --to=iec $size_before 2>/dev/null || echo ${size_before}B))"

    if [[ "$DRY_RUN" == "1" ]]; then
        continue
    fi

    # backup original (preserve relative imageset path)
    rel="${png#$ASSET_DIR/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp "$png" "$BACKUP_DIR/$rel"

    # 1. resize in place (strips most metadata as a re-encode)
    sips --resampleHeightWidth "$new_h" "$new_w" "$png" >/dev/null

    # 2. recompress + strip ancillary chunks (text, time, etc.) keeping transparency
    if [[ -n "$PNGCRUSH" ]]; then
        tmp="${png}.crush"
        "$PNGCRUSH" -q -rem allb -reduce -brute "$png" "$tmp" >/dev/null 2>&1 && mv "$tmp" "$png"
    fi

    size_after=$(stat -f%z "$png")
    total_after=$((total_after + size_after))
done < <(find "$ASSET_DIR" -name "*.png" -print0)

echo ""
echo "Processed $count images."
if [[ "$DRY_RUN" != "1" ]]; then
    echo "Total before: $(numfmt --to=iec $total_before 2>/dev/null || echo ${total_before}B)"
    echo "Total after:  $(numfmt --to=iec $total_after  2>/dev/null || echo ${total_after}B)"
    echo "Backups saved to: $BACKUP_DIR"
fi
