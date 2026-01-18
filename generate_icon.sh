#!/bin/bash

# Generate app icons with employee icon and "ALKHORA" text on gradient blue background
# Uses ImageMagick's convert command

# Colors - matching check-in circle gradient
BLUE_DARK="#1C4CA5"   # Check-in gradient start color
BLUE_LIGHT="#3B6FD8"  # Check-in gradient end color
WHITE="#FFFFFF"

echo "Generating app icons with employee icon and 'ALKHORA' on gradient background..."
echo "Gradient: $BLUE_DARK → $BLUE_LIGHT"
echo ""

# Function to generate an icon with text
generate_icon() {
    local size=$1
    local output=$2
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$output")"
    
    # For very small icons, use smaller proportions
    if [ "$size" -lt 60 ]; then
        local icon_size=$((size * 35 / 100))  # Smaller icon for small sizes
        local text_size=$((size * 11 / 100))  # Smaller text
        local icon_offset=$((size * 12 / 100))  # Less offset
        local text_offset=$((size * 35 / 100))  # Text closer to center
    else
        local icon_size=$((size * 40 / 100))  # Employee icon is 40% of icon size
        local text_size=$((size * 13 / 100))  # Text is 13% of icon size
        local icon_offset=$((size / 8))  # Icon positioned above center
        local text_offset=$((size * 42 / 100))  # Text closer to center, not too low
    fi
    
    # Calculate employee icon dimensions - ensure they fit within bounds
    local head_radius=$((icon_size * 15 / 100))
    local head_center_y=$((size / 2 - icon_offset))
    local head_center_x=$((size / 2))
    local body_top=$((head_center_y + head_radius + icon_size * 5 / 100))
    # Ensure body bottom doesn't go too low - limit to 70% of icon height
    local body_bottom_max=$((size * 70 / 100))
    local body_bottom_calc=$((size / 2 + icon_size * 25 / 100))
    local body_bottom=$((body_bottom_calc > body_bottom_max ? body_bottom_max : body_bottom_calc))
    local body_top_width=$((icon_size * 35 / 100))
    local body_bottom_width=$((icon_size * 45 / 100))
    
    # Calculate text position - ensure it fits within bounds (bottom 75% max)
    local text_y_pos=$((size / 2 + text_offset))
    local text_y_max=$((size * 75 / 100))
    if [ "$text_y_pos" -gt "$text_y_max" ]; then
        text_offset=$((text_y_max - size / 2))
    fi
    
    # Create icon with gradient background, employee icon, and text
    convert -size "${size}x${size}" gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        -fill "$WHITE" \
        -draw "circle $head_center_x,$head_center_y $head_center_x,$((head_center_y + head_radius))" \
        -draw "polygon $((head_center_x - body_top_width/2)),$body_top $((head_center_x + body_top_width/2)),$body_top $((head_center_x + body_bottom_width/2)),$body_bottom $((head_center_x - body_bottom_width/2)),$body_bottom" \
        -gravity center \
        -pointsize "$text_size" \
        -font Helvetica-Bold \
        -fill "$WHITE" \
        -annotate +0+$text_offset "ALKHORA" \
        "$output" 2>/dev/null || \
    convert -size "${size}x${size}" gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        -gravity center \
        -fill "$WHITE" \
        -pointsize "$icon_size" \
        -font Helvetica-Bold \
        -annotate +0-$icon_offset "👤" \
        -pointsize "$text_size" \
        -font Helvetica-Bold \
        -annotate +0+$text_offset "ALKHORA" \
        "$output" 2>/dev/null || \
    convert -size "${size}x${size}" gradient:"$BLUE_DARK-$BLUE_LIGHT" \
        -gravity center \
        -pointsize "$text_size" \
        -fill "$WHITE" \
        -font Helvetica-Bold \
        -annotate +0+$text_offset "ALKHORA" \
        "$output"
    
    if [ -f "$output" ]; then
        echo "Generated: $output (${size}x${size})"
    else
        echo "Failed: $output"
    fi
}

# Android icons
echo "Generating Android icons..."
generate_icon 48 "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
generate_icon 72 "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
generate_icon 96 "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
generate_icon 144 "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
generate_icon 192 "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

echo ""
echo "Generating iOS icons..."
generate_icon 20 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"
generate_icon 40 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"
generate_icon 60 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"
generate_icon 29 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"
generate_icon 58 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"
generate_icon 87 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"
generate_icon 40 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"
generate_icon 80 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"
generate_icon 120 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"
generate_icon 120 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"
generate_icon 180 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"
generate_icon 76 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"
generate_icon 152 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"
generate_icon 167 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"
generate_icon 1024 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"

echo ""
echo "Generating Web icons..."
generate_icon 192 "web/icons/Icon-192.png"
generate_icon 512 "web/icons/Icon-512.png"
generate_icon 192 "web/icons/Icon-maskable-192.png"
generate_icon 512 "web/icons/Icon-maskable-512.png"

echo ""
echo "Generating macOS icons..."
generate_icon 16 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
generate_icon 32 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
generate_icon 64 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
generate_icon 128 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
generate_icon 256 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
generate_icon 512 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
generate_icon 1024 "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"

echo ""
echo "✓ All app icons generated successfully!"
echo "You may need to run 'flutter clean' and rebuild the app to see the changes."
