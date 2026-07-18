from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def draw_grid(draw, x, y, size, color, width=4):
    step = size // 3
    for i in range(1, 3):
        draw.line([(x + i*step, y), (x + i*step, y + size)], fill=color, width=width)
        draw.line([(x, y + i*step), (x + size, y + i*step)], fill=color, width=width)

def draw_x(draw, cx, cy, s, color, width=6):
    draw.line([(cx-s, cy-s), (cx+s, cy+s)], fill=color, width=width)
    draw.line([(cx+s, cy-s), (cx-s, cy+s)], fill=color, width=width)

def draw_o(draw, cx, cy, r, color, width=6):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=color, width=width)

# App icon 512x512
icon = Image.new('RGB', (512, 512), (41, 23, 90))
draw = ImageDraw.Draw(icon)

# Gradient-ish background circles for decoration
for i in range(4):
    draw.ellipse([512 - 120 - i*40, -40 - i*40, 512 + 80 - i*40, 120 - i*40], fill=(109, 40, 217, 0))

# Main board
board_size = 260
bx = (512 - board_size) // 2
by = (512 - board_size) // 2 + 10

draw.rounded_rectangle([bx-24, by-24, bx+board_size+24, by+board_size+24], radius=32, fill=(109, 40, 217, 80))
draw.rounded_rectangle([bx-24, by-24, bx+board_size+24, by+board_size+24], radius=32, outline=(255, 255, 255, 100), width=3)

draw_grid(draw, bx, by, board_size, (255, 255, 255, 180), width=6)

# Place X and O
cell = board_size // 3
positions = [
    (0, 0, 'x'),
    (1, 1, 'o'),
    (2, 0, 'x'),
    (0, 2, 'o'),
    (2, 2, 'x'),
]
for col, row, mark in positions:
    cx = bx + col*cell + cell//2
    cy = by + row*cell + cell//2
    if mark == 'x':
        draw_x(draw, cx, cy, cell//3 - 10, '#F59E0B', width=10)
    else:
        draw_o(draw, cx, cy, cell//3 - 10, '#10B981', width=10)

icon.save(os.path.join(OUT_DIR, 'app_icon_512.png'))
print('Saved app_icon_512.png')

# Feature graphic 1024x500
fg = Image.new('RGB', (1024, 500), (41, 23, 90))
draw = ImageDraw.Draw(fg)

# Decorative background
draw.ellipse([700, -80, 1100, 240], fill=(109, 40, 217, 80))
draw.ellipse([900, 250, 1200, 550], fill=(109, 40, 217, 40))

# Title
font_large = ImageFont.truetype("arial.ttf", 64) if os.path.exists("arial.ttf") else ImageFont.load_default()
font_small = ImageFont.truetype("arial.ttf", 30) if os.path.exists("arial.ttf") else ImageFont.load_default()

draw.text((60, 140), "Tic Tac Toe", fill=(255, 255, 255), font=font_large)
draw.text((60, 220), "Multiplayer · Chat · Tournaments", fill=(255, 255, 255, 200), font=font_small)

# Mini board
mini = 180
mx = 730
my = 160
draw.rounded_rectangle([mx-20, my-20, mx+mini+20, my+mini+20], radius=24, fill=(255, 255, 255, 20))
draw_grid(draw, mx, my, mini, (255, 255, 255, 200), width=5)
cell = mini // 3
poses = [(0,0,'x'), (1,1,'o'), (2,0,'x'), (0,2,'o'), (2,2,'x')]
for col, row, mark in poses:
    cx = mx + col*cell + cell//2
    cy = my + row*cell + cell//2
    if mark == 'x':
        draw_x(draw, cx, cy, cell//3 - 8, '#F59E0B', width=8)
    else:
        draw_o(draw, cx, cy, cell//3 - 8, '#10B981', width=8)

fg.save(os.path.join(OUT_DIR, 'feature_graphic_1024.png'))
print('Saved feature_graphic_1024.png')
