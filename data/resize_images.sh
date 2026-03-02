#!/bin/bash
# Resize all image files to a target size with black padding, centered.
# Skips files already prefixed with n_.
# Usage: ./resize_images.sh [WIDTHxHEIGHT]

SIZE="${1:-1242x2688}"

OUTDIR="outputs"
mkdir -p "$OUTDIR"

if ! command -v magick &>/dev/null; then
    echo "Error: ImageMagick 'magick' command not found."
    echo ""
    echo "Install it with one of:"
    echo "  macOS:   brew install imagemagick"
    echo "  Ubuntu:  sudo apt install imagemagick"
    echo "  Windows: https://imagemagick.org/script/download.php"
    exit 1
fi

count=0
for f in *.{jpg,jpeg,png,gif,bmp,tiff,webp}; do
    [ -f "$f" ] || continue
    basename="$(basename "$f")"
    out="$OUTDIR/${basename}"
    echo "Resizing: $f -> $out ($SIZE)"
    magick "$f" -resize "$SIZE" -background black -gravity center -extent "$SIZE" "$out"
    ((count++))
done

echo "Done. Resized $count image(s) to $SIZE."
