#!/usr/bin/env python3
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

def generate_icns(source_jpg_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    
    src = Image.open(source_jpg_path)
    
    # 1. Crop the central squircle (612x612 located between 205 and 817)
    squircle_crop = src.crop((205, 205, 817, 817))
    
    # 2. Resize to Apple standard macOS icon size: 824x824 inside a 1024x1024 canvas
    squircle_824 = squircle_crop.resize((824, 824), Image.Resampling.LANCZOS)
    
    # 3. Create anti-aliased squircle mask at 4x supersampling (3296x3296)
    scale = 4
    ss_w, ss_h = 824 * scale, 824 * scale
    mask_hi = Image.new('L', (ss_w, ss_h), 0)
    draw = ImageDraw.Draw(mask_hi)
    radius = int(185 * scale)
    draw.rounded_rectangle([0, 0, ss_w - 1, ss_h - 1], radius=radius, fill=255)
    mask = mask_hi.resize((824, 824), Image.Resampling.LANCZOS)
    
    squircle_rgba = squircle_824.convert('RGBA')
    squircle_rgba.putalpha(mask)
    
    # 4. Canvas (1024x1024) with Apple-style soft drop shadow
    canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    shadow_mask = Image.new('L', (1024, 1024), 0)
    shadow_mask.paste(mask, (100, 114)) # 14px down offset for natural drop shadow
    shadow_blur = shadow_mask.filter(ImageFilter.GaussianBlur(18))
    
    shadow_layer = Image.new('RGBA', (1024, 1024), (20, 25, 45, 0))
    shadow_arr = np.array(shadow_blur, dtype=float) * 0.28
    shadow_layer.putalpha(Image.fromarray(shadow_arr.astype(np.uint8)))
    
    canvas = Image.alpha_composite(canvas, shadow_layer)
    canvas.paste(squircle_rgba, (100, 100), squircle_rgba)
    
    # Save master 1024x1024 PNG
    master_png_path = os.path.join(output_dir, "AppIcon.png")
    canvas.save(master_png_path)
    print(f"✅ Saved master PNG: {master_png_path}")
    
    # 5. Generate Apple .iconset directory
    iconset_dir = os.path.join(output_dir, "AppIcon.iconset")
    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    for sz, name in sizes:
        resized = canvas.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))
        
    print(f"✅ Generated all 10 icon resolutions in {iconset_dir}")
    
    # 6. Compile to .icns using iconutil
    icns_path = os.path.join(output_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"🎉 Successfully created macOS .icns: {icns_path}")
    
    # Clean up iconset folder
    shutil.rmtree(iconset_dir)

if __name__ == "__main__":
    src_img = "/Users/hongyuehao/.gemini/antigravity/brain/039dfb4c-b95f-49d9-a937-166839003627/app_icon_minimal_1788809693299.jpg"
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Resources"))
    generate_icns(src_img, out_dir)
