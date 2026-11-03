from PIL import Image, ImageDraw, ImageFilter
import math
import os

base = r'C:\Users\PC11-SL01\Music\mindstack_appdev'
res_dirs = {
    'mipmap-hdpi': 72,
    'mipmap-mdpi': 48,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

for y in range(size):
    t = y / size
    r = int(22 + (91 - 22) * t)
    g = int(56 + (136 - 56) * t)
    b = int(130 + (255 - 130) * t)
    draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

mask = Image.new('L', (size, size), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle((60, 60, size - 60, size - 60), radius=220, fill=255)
img.putalpha(mask)

note = Image.new('RGBA', (size, size), (0, 0, 0, 0))
nd = ImageDraw.Draw(note)
nd.rounded_rectangle((200, 220, 824, 820), radius=110, fill=(255, 255, 255, 240))
nd.rounded_rectangle((200, 220, 824, 350), radius=90, fill=(255, 255, 255, 255))
nd.polygon([(645, 220), (824, 220), (824, 390)], fill=(233, 236, 255, 255))
for y in range(430, 760, 90):
    nd.line((300, y, 724, y), fill=(205, 216, 240, 255), width=20)

pencil = Image.new('RGBA', (300, 300), (0, 0, 0, 0))
pd = ImageDraw.Draw(pencil)
pd.rounded_rectangle((0, 0, 220, 90), radius=40, fill=(255, 184, 76, 255))
pd.polygon([(220, 18), (275, 68), (198, 140), (145, 88)], fill=(255, 184, 76, 255))
pd.rounded_rectangle((90, 80, 170, 190), radius=30, fill=(255, 184, 76, 255))
pencil = pencil.rotate(32, expand=True)

star = Image.new('RGBA', (280, 280), (0, 0, 0, 0))
sd = ImageDraw.Draw(star)
cx, cy = 140, 140
outer, inner = 110, 45
points = []
for i in range(10):
    angle = -math.pi / 2 + i * 36 * (math.pi / 180)
    radius = outer if i % 2 == 0 else inner
    x = cx + radius * math.cos(angle)
    y = cy + radius * math.sin(angle)
    points.append((x, y))
sd.polygon(points, fill=(255, 210, 120, 255))
star = star.filter(ImageFilter.GaussianBlur(2))

img = Image.alpha_composite(img, note)
img = Image.alpha_composite(img, pencil)
img = Image.alpha_composite(img, star)
img.save(os.path.join(base, 'mindstack_icon.png'))

for folder, size_px in res_dirs.items():
    out_dir = os.path.join(base, 'android', 'app', 'src', 'main', 'res', folder)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'ic_launcher.png')
    img.resize((size_px, size_px), Image.Resampling.LANCZOS).save(out_path)

print('Created custom launcher icons.')
