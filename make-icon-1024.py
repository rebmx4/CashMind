"""Make App Store 1024x1024 icon from /tmp/icon-512.png (no alpha, dark BG)."""
from PIL import Image
src = Image.open('/tmp/icon-512.png')
if src.mode in ('RGBA', 'LA'):
    bg = Image.new('RGB', src.size, (23, 23, 23))
    bg.paste(src, mask=src.split()[-1])
    src = bg
out = src.resize((1024, 1024), Image.LANCZOS)
out.save('D:/cashmind-ios/app-icon-1024.png', 'PNG', optimize=True)
print('Saved: D:/cashmind-ios/app-icon-1024.png')
