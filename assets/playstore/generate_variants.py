from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for font_path in ["arial.ttf", "Arial.ttf"]:
        try:
            return ImageFont.truetype(font_path, size)
        except Exception:
            pass
    return ImageFont.load_default()

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

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def gradient_bg(img, c1, c2, direction='vertical'):
    c1 = hex_to_rgb(c1)
    c2 = hex_to_rgb(c2)
    w, h = img.size
    if direction == 'vertical':
        for y in range(h):
            r = int(c1[0] + (c2[0]-c1[0])*y/h)
            g = int(c1[1] + (c2[1]-c1[1])*y/h)
            b = int(c1[2] + (c2[2]-c1[2])*y/h)
            draw = ImageDraw.Draw(img)
            draw.line([(0,y),(w,y)], fill=(r,g,b))
    else:
        for x in range(w):
            r = int(c1[0] + (c2[0]-c1[0])*x/w)
            g = int(c1[1] + (c2[1]-c1[1])*x/w)
            b = int(c1[2] + (c2[2]-c1[2])*x/w)
            draw = ImageDraw.Draw(img)
            draw.line([(x,0),(x,h)], fill=(r,g,b))

board_positions = [(0,0,'x'), (1,1,'o'), (2,0,'x'), (0,2,'o'), (2,2,'x')]

def create_icon(filename, bg_hex, accent_hex, board_color, x_color, o_color, gradient=False, dark=False):
    img = Image.new('RGB', (512,512), hex_to_rgb(bg_hex))
    if gradient:
        c1, c2 = bg_hex.split('|')
        gradient_bg(img, c1, c2)
    draw = ImageDraw.Draw(img)
    bg = img.copy()
    bg.putalpha(255)
    # decorative glow
    draw.ellipse([350, -60, 600, 180], fill=hex_to_rgb(accent_hex) + (0,))
    # board
    board_size = 260
    bx = (512 - board_size)//2
    by = (512 - board_size)//2 + 10
    draw.rounded_rectangle([bx-24, by-24, bx+board_size+24, by+board_size+24], radius=32, fill=hex_to_rgb(accent_hex) + (0,), outline=(255,255,255,100), width=3)
    draw_grid(draw, bx, by, board_size, board_color, width=6)
    cell = board_size // 3
    for col, row, mark in board_positions:
        cx = bx + col*cell + cell//2
        cy = by + row*cell + cell//2
        if mark == 'x':
            draw_x(draw, cx, cy, cell//3 - 10, x_color, width=10)
        else:
            draw_o(draw, cx, cy, cell//3 - 10, o_color, width=10)
    img.save(os.path.join(OUT_DIR, filename))
    print(f"Saved {filename}")

def create_feature(filename, bg_hex, accent_hex, title_color, sub_color, board=True, title="Tic Tac Toe", subtitle="Multiplayer · Chat · Tournaments", gradient=False):
    img = Image.new('RGB', (1024,500), hex_to_rgb(bg_hex))
    if gradient:
        c1, c2 = bg_hex.split('|')
        gradient_bg(img, c1, c2, direction='horizontal')
    draw = ImageDraw.Draw(img)
    # decorative shapes
    draw.ellipse([700, -80, 1100, 240], fill=hex_to_rgb(accent_hex) + (0,))
    draw.ellipse([900, 250, 1200, 550], fill=hex_to_rgb(accent_hex) + (0,))
    # text
    font_title = get_font(64)
    font_sub = get_font(30)
    draw.text((60, 140), title, fill=title_color, font=font_title)
    draw.text((60, 220), subtitle, fill=sub_color, font=font_sub)
    if board:
        mini = 180
        mx, my = 730, 160
        draw.rounded_rectangle([mx-20, my-20, mx+mini+20, my+mini+20], radius=24, fill=(255,255,255,20))
        draw_grid(draw, mx, my, mini, (255,255,255,200), width=5)
        cell = mini // 3
        for col, row, mark in board_positions:
            cx = mx + col*cell + cell//2
            cy = my + row*cell + cell//2
            if mark == 'x':
                draw_x(draw, cx, cy, cell//3 - 8, '#F59E0B', width=8)
            else:
                draw_o(draw, cx, cy, cell//3 - 8, '#10B981', width=8)
    img.save(os.path.join(OUT_DIR, filename))
    print(f"Saved {filename}")

# App icons variants
create_icon('app_icon_v1_512.png', '#1E1040', '#6D28D9', '#FFFFFF', '#F59E0B', '#10B981')
create_icon('app_icon_v2_512.png', '#064E3B', '#10B981', '#FFFFFF', '#FCD34D', '#34D399')
create_icon('app_icon_v3_512.png', '#1E3A8A', '#3B82F6', '#FFFFFF', '#F472B6', '#60A5FA')
create_icon('app_icon_v4_512.png', '#0F172A', '#8B5CF6', '#A78BFA', '#FBBF24', '#34D399', dark=True)

# Feature graphics variants
create_feature('feature_graphic_v1_1024.png', '#1E1040', '#6D28D9', '#FFFFFF', '#E9D5FF')
create_feature('feature_graphic_v2_1024.png', '#064E3B', '#10B981', '#FFFFFF', '#D1FAE5', title='Tic Tac Toe Online')
create_feature('feature_graphic_v3_1024.png', '#0F172A', '#8B5CF6', '#FFFFFF', '#C4B5FD', board=False, subtitle='Play. Chat. Win.')
create_feature('feature_graphic_v4_1024.png', '#1E3A8A', '#3B82F6', '#FFFFFF', '#BFDBFE', title='Tic Tac Toe Pro')
