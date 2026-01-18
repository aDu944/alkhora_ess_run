#!/bin/bash
# Helper script to create employee icon SVG/PNG for use in icon generation

# This creates a simple employee icon (person silhouette)
# Head: circle
# Body: rounded rectangle (torso)

SIZE=$1
OUTPUT=$2

if [ -z "$SIZE" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 <size> <output.png>"
    exit 1
fi

# Create employee icon using ImageMagick
# Head: circle at top 1/3
# Body: rounded rectangle/trapezoid at bottom 2/3
convert -size "${SIZE}x${SIZE}" xc:transparent \
    -fill white \
    -draw "circle $((SIZE/2)),$((SIZE/3)) $((SIZE/2)),$((SIZE/5))" \
    -draw "polygon $((SIZE*2/5)),$((SIZE*2/5)) $((SIZE*3/5)),$((SIZE*2/5)) $((SIZE*11/20)),$((SIZE*4/5)) $((SIZE*9/20)),$((SIZE*4/5))" \
    "$OUTPUT"
