#!/usr/bin/env python3
"""
Generate app icons with "ALKHORA ESS" text on blue background
for Android, iOS, Web, and macOS platforms.
"""

import os
from PIL import Image, ImageDraw, ImageFont
import sys

# Blue background color (matching the theme color #0175C2 from manifest.json)
BLUE_COLOR = "#0175C2"
TEXT_COLOR = "#FFFFFF"  # White text

# Text to display
TEXT = "ALKHORA ESS"

def generate_icon(size, output_path, text_size_ratio=0.4):
    """
    Generate an icon with text on blue background.
    
    Args:
        size: Size of the icon (width and height)
        output_path: Path where to save the icon
        text_size_ratio: Ratio of text size to icon size (default 0.4)
    """
    # Create image with blue background
    img = Image.new('RGB', (size, size), color=BLUE_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Try to use a bold font, fallback to default if not available
    try:
        # Try system fonts (macOS)
        font_paths = [
            '/System/Library/Fonts/Helvetica.ttc',
            '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
            '/System/Library/Fonts/HelveticaNeue.ttc',
        ]
        font = None
        font_size = int(size * text_size_ratio)
        
        for font_path in font_paths:
            try:
                if font_path.endswith('.ttc'):
                    # TrueType Collection - try to get font at index 0
                    font = ImageFont.truetype(font_path, font_size, index=0)
                else:
                    font = ImageFont.truetype(font_path, font_size)
                break
            except:
                continue
        
        # If no font found, try default
        if font is None:
            font = ImageFont.load_default()
    except:
        # Fallback to default font
        font = ImageFont.load_default()
        font_size = int(size * 0.3)
    
    # Split text into two lines if it's a long name
    words = TEXT.split()
    if len(words) == 2:
        line1 = words[0]  # "ALKHORA"
        line2 = words[1]  # "ESS"
    else:
        # If it's one word, try to split it or center it
        line1 = TEXT
        line2 = ""
    
    # Calculate text position (centered)
    if line2:
        # Two-line layout
        bbox1 = draw.textbbox((0, 0), line1, font=font)
        bbox2 = draw.textbbox((0, 0), line2, font=font)
        text_width1 = bbox1[2] - bbox1[0]
        text_width2 = bbox2[2] - bbox2[0]
        text_height1 = bbox1[3] - bbox1[1]
        text_height2 = bbox2[3] - bbox2[1]
        total_text_height = text_height1 + text_height2 + int(size * 0.05)  # 5% spacing
        
        x1 = (size - text_width1) // 2
        x2 = (size - text_width2) // 2
        y1 = (size - total_text_height) // 2
        y2 = y1 + text_height1 + int(size * 0.05)
        
        # Draw text
        draw.text((x1, y1), line1, fill=TEXT_COLOR, font=font)
        draw.text((x2, y2), line2, fill=TEXT_COLOR, font=font)
    else:
        # Single-line layout
        bbox = draw.textbbox((0, 0), line1, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        x = (size - text_width) // 2
        y = (size - text_height) // 2
        
        draw.text((x, y), line1, fill=TEXT_COLOR, font=font)
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Save image
    img.save(output_path, 'PNG')
    print(f"Generated: {output_path} ({size}x{size})")

def main():
    """Generate all required icon sizes."""
    
    # Check if PIL is available
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Error: PIL (Pillow) is required. Install it with: pip3 install Pillow")
        sys.exit(1)
    
    print("Generating app icons with 'ALKHORA ESS' on blue background...")
    print(f"Background color: {BLUE_COLOR}")
    print()
    
    # Android icons (mipmap folders)
    print("Generating Android icons...")
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, size in android_sizes.items():
        output_path = f"android/app/src/main/res/{folder}/ic_launcher.png"
        generate_icon(size, output_path)
    
    print()
    
    # iOS icons
    print("Generating iOS icons...")
    ios_icons = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }
    
    for filename, size in ios_icons.items():
        output_path = f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{filename}"
        generate_icon(size, output_path)
    
    print()
    
    # Web icons
    print("Generating Web icons...")
    web_icons = {
        'Icon-192.png': 192,
        'Icon-512.png': 512,
        'Icon-maskable-192.png': 192,
        'Icon-maskable-512.png': 512,
    }
    
    for filename, size in web_icons.items():
        output_path = f"web/icons/{filename}"
        generate_icon(size, output_path)
    
    print()
    
    # macOS icons
    print("Generating macOS icons...")
    macos_icons = {
        'app_icon_16.png': 16,
        'app_icon_32.png': 32,
        'app_icon_64.png': 64,
        'app_icon_128.png': 128,
        'app_icon_256.png': 256,
        'app_icon_512.png': 512,
        'app_icon_1024.png': 1024,
    }
    
    for filename, size in macos_icons.items():
        output_path = f"macos/Runner/Assets.xcassets/AppIcon.appiconset/{filename}"
        generate_icon(size, output_path)
    
    print()
    print("✓ All app icons generated successfully!")
    print("You may need to run 'flutter clean' and rebuild the app to see the changes.")

if __name__ == '__main__':
    main()
