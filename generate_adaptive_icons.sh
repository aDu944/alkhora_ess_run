#!/bin/bash

# Generate Android adaptive icons with gradient background, employee icon, and ALKHORA text
# Android adaptive icons require separate foreground and background images
# with safe zones to prevent clipping

# Colors - matching check-in circle gradient
BLUE_DARK="#1C4CA5"   # Check-in gradient start color
BLUE_LIGHT="#3B6FD8"  # Check-in gradient end color
WHITE="#FFFFFF"

echo "Generating Android adaptive icons with gradient and employee icon..."
echo "Gradient: $BLUE_DARK → $BLUE_LIGHT"
echo ""

# Android adaptive icon sizes (108dp canvas with 72dp safe zone)
# Background: full 108dp gradient square
# Foreground: transparent with employee icon and ALKHORA text
android_sizes=(
    "mdpi:108"
    "hdpi:162"
    "xhdpi:216"
    "xxhdpi:324"
    "xxxhdpi:432"
)

# Function to generate adaptive icon layers
generate_adaptive_icon() {
    local density=$1
    local size=$2
    local safe_zone=$((size * 72 / 108))  # 72dp safe zone in 108dp canvas
    
    local mipmap_dir="android/app/src/main/res/mipmap-${density}"
    mkdir -p "$mipmap_dir"
    
    # Background layer: Gradient from dark blue to light blue (diagonal gradient)
    # Create gradient using ImageMagick - vertical gradient from top to bottom
    convert -size "${size}x${size}" \
        gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        "${mipmap_dir}/ic_launcher_background.png"
    echo "Generated: ${mipmap_dir}/ic_launcher_background.png (${size}x${size})"
    
    # Foreground layer: Transparent background with employee icon and text
    # Employee icon size: 50% of safe zone
    # Text size: 12% of safe zone (just for "ALKHORA")
    local icon_size=$((safe_zone * 50 / 100))
    local text_size=$((safe_zone * 12 / 100))
    local icon_offset=$((size / 10))  # Icon positioned above center
    local text_offset=$((safe_zone * 60 / 100))  # Text below icon
    
    # Create transparent canvas with employee icon and text
    # Draw employee icon (person silhouette): head (circle) + body (trapezoid/rounded)
    local head_radius=$((icon_size * 15 / 100))  # Head is 15% of icon size
    local head_center_y=$((size / 2 - icon_offset))
    local head_center_x=$((size / 2))
    local body_top=$((head_center_y + head_radius + icon_size * 5 / 100))
    local body_bottom=$((size / 2 + icon_size * 25 / 100))
    local body_top_width=$((icon_size * 35 / 100))
    local body_bottom_width=$((icon_size * 45 / 100))
    
    # Create foreground with employee icon and text
    convert -size "${size}x${size}" xc:transparent \
        -fill "$WHITE" \
        -draw "circle $head_center_x,$head_center_y $head_center_x,$((head_center_y + head_radius))" \
        -draw "polygon $((head_center_x - body_top_width/2)),$body_top $((head_center_x + body_top_width/2)),$body_top $((head_center_x + body_bottom_width/2)),$body_bottom $((head_center_x - body_bottom_width/2)),$body_bottom" \
        -gravity center \
        -pointsize "$text_size" \
        -font Helvetica-Bold \
        -fill "$WHITE" \
        -annotate +0+$text_offset "ALKHORA" \
        "${mipmap_dir}/ic_launcher_foreground.png" 2>/dev/null || \
    convert -size "${size}x${size}" xc:transparent \
        -gravity center \
        -pointsize "$icon_size" \
        -fill "$WHITE" \
        -font Helvetica-Bold \
        -annotate +0-$icon_offset "👤" \
        -pointsize "$text_size" \
        -font Helvetica-Bold \
        -annotate +0+$text_offset "ALKHORA" \
        "${mipmap_dir}/ic_launcher_foreground.png"
    echo "Generated: ${mipmap_dir}/ic_launcher_foreground.png (${size}x${size}, icon: ${icon_size}, text: ${text_size})"
    
    # Also update the regular ic_launcher.png for older Android versions
    local padding=$((size * 22 / 108))  # 22dp padding
    local padded_size=$((size - padding * 2))
    local regular_icon_size=$((padded_size * 45 / 100))
    local regular_text_size=$((padded_size * 13 / 100))
    local regular_icon_offset=$((padded_size / 8))
    local regular_text_offset=$((padded_size * 55 / 100))
    
    # Create gradient background with employee icon and text
    local regular_head_radius=$((regular_icon_size * 15 / 100))
    local regular_head_center_y=$((size / 2 - regular_icon_offset))
    local regular_head_center_x=$((size / 2))
    local regular_body_top=$((regular_head_center_y + regular_head_radius + regular_icon_size * 5 / 100))
    local regular_body_bottom=$((size / 2 + regular_icon_size * 25 / 100))
    local regular_body_top_width=$((regular_icon_size * 35 / 100))
    local regular_body_bottom_width=$((regular_icon_size * 45 / 100))
    
    convert -size "${size}x${size}" gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        -fill "$WHITE" \
        -draw "circle $regular_head_center_x,$regular_head_center_y $regular_head_center_x,$((regular_head_center_y + regular_head_radius))" \
        -draw "polygon $((regular_head_center_x - regular_body_top_width/2)),$regular_body_top $((regular_head_center_x + regular_body_top_width/2)),$regular_body_top $((regular_head_center_x + regular_body_bottom_width/2)),$regular_body_bottom $((regular_head_center_x - regular_body_bottom_width/2)),$regular_body_bottom" \
        -gravity center \
        -pointsize "$regular_text_size" \
        -font Helvetica-Bold \
        -fill "$WHITE" \
        -annotate +0+$regular_text_offset "ALKHORA" \
        "${mipmap_dir}/ic_launcher.png" 2>/dev/null || \
    convert -size "${size}x${size}" gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        -gravity center \
        -fill "$WHITE" \
        -pointsize "$regular_icon_size" \
        -font Helvetica-Bold \
        -annotate +0-$regular_icon_offset "👤" \
        -pointsize "$regular_text_size" \
        -font Helvetica-Bold \
        -annotate +0+$regular_text_offset "ALKHORA" \
        "${mipmap_dir}/ic_launcher.png"
    echo "Updated: ${mipmap_dir}/ic_launcher.png (${size}x${size})"
}

# Generate adaptive icon layers for each density
for size_info in "${android_sizes[@]}"; do
    density="${size_info%%:*}"
    size="${size_info##*:}"
    echo "Processing ${density} (${size}x${size})..."
    generate_adaptive_icon "$density" "$size"
    echo ""
done

echo "Creating adaptive icon XML configuration..."

# Create xml directory for adaptive icon config
mkdir -p android/app/src/main/res/mipmap-anydpi-v26

# Create adaptive_icon.xml
cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

# Also create round version
cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

echo "Generated: android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
echo "Generated: android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"
echo ""
echo "✓ Android adaptive icons generated successfully!"
echo ""
echo "Android 8.0+ (API 26+) will use adaptive icons (foreground + background layers)"
echo "Older Android versions will use ic_launcher.png"
echo ""
echo "To see the changes:"
echo "  1. Run 'flutter clean'"
echo "  2. Rebuild and reinstall the app: 'flutter run'"
