from PIL import Image
import os
import shutil

base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = os.path.join(base_dir, 'assets', 'playstore', 'app_icon_design_01.png')
res_dir = os.path.join(base_dir, 'android', 'app', 'src', 'main', 'res')

img = Image.open(src).convert('RGBA')

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

for folder, size in sizes.items():
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    path = os.path.join(res_dir, folder, 'ic_launcher.png')
    resized.save(path)
    print(f'Saved {path}')

# Also keep app_icon_selected consistent with the chosen design
shutil.copy(src, os.path.join(base_dir, 'assets', 'playstore', 'app_icon_selected.png'))
print('Updated app_icon_selected.png')
