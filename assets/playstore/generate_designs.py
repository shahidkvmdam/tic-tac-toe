from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for f in ["arial.ttf", "Arial.ttf", "C:\\Windows\\Fonts\\arial.ttf"]:
        try:
            return ImageFont.truetype(f, size)
        except Exception:
            pass
    return ImageFont.load_default()

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def draw_x(draw, cx, cy, s, color, width=6):
    draw.line([(cx-s, cy-s), (cx+s, cy+s)], fill=color, width=width)
    draw.line([(cx+s, cy-s), (cx-s, cy+s)], fill=color, width=width)

def draw_o(draw, cx, cy, r, color, width=6):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=color, width=width)

def draw_grid(draw, x, y, size, color, width=4):
    step = size // 3
    for i in range(1, 3):
        draw.line([(x + i*step, y), (x + i*step, y + size)], fill=color, width=width)
        draw.line([(x, y + i*step), (x + size, y + i*step)], fill=color, width=width)

def gradient_bg(img, c1, c2):
    c1 = hex_to_rgb(c1)
    c2 = hex_to_rgb(c2)
    w, h = img.size
    for y in range(h):
        r = int(c1[0] + (c2[0]-c1[0])*y/h)
        g = int(c1[1] + (c2[1]-c1[1])*y/h)
        b = int(c1[2] + (c2[2]-c1[2])*y/h)
        draw = ImageDraw.Draw(img)
        draw.line([(0,y),(w,y)], fill=(r,g,b))

# ── App icons ────────────────────────────────────────────────

def icon_split_xo():
    img = Image.new('RGB', (512,512), '#1E1040')
    draw = ImageDraw.Draw(img)
    # diagonal split background
    draw.polygon([(0,0),(512,0),(0,512)], fill=hex_to_rgb('#6D28D9'))
    draw.polygon([(512,0),(512,512),(0,512)], fill=hex_to_rgb('#1E1040'))
    draw_x(draw, 170, 256, 90, '#FFFFFF', 22)
    draw_o(draw, 342, 256, 95, '#FBBF24', 22)
    img.save(os.path.join(OUT_DIR, 'app_icon_design_01.png'))

def icon_round_board():
    img = Image.new('RGB', (512,512), '#0F172A')
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([60,60,452,452], radius=80, fill='#1E293B', outline='#38BDF8', width=8)
    draw_grid(draw, 126, 126, 260, '#FFFFFF', width=8)
    draw_x(draw, 190, 190, 35, '#F472B6', 12)
    draw_o(draw, 322, 190, 38, '#34D399', 12)
    draw_x(draw, 190, 322, 35, '#F472B6', 12)
    draw_o(draw, 322, 322, 38, '#34D399', 12)
    img.save(os.path.join(OUT_DIR, 'app_icon_design_02.png'))

def icon_big_x_shadow():
    img = Image.new('RGB', (512,512), '#064E3B')
    draw = ImageDraw.Draw(img)
    # shadow
    draw_x(draw, 270, 270, 160, '#000000', 45)
    draw_x(draw, 256, 256, 160, '#FCD34D', 45)
    draw_o(draw, 256, 256, 80, '#10B981', 20)
    img.save(os.path.join(OUT_DIR, 'app_icon_design_03.png'))

def icon_neon_glow():
    img = Image.new('RGB', (512,512), '#0F0F23')
    draw = ImageDraw.Draw(img)
    # glow effect by drawing multiple
    for w in range(20, 6, -4):
        draw_x(draw, 200, 256, 110, '#A78BFA', w)
        draw_o(draw, 312, 256, 110, '#60A5FA', w)
    draw_x(draw, 200, 256, 110, '#FFFFFF', 10)
    draw_o(draw, 312, 256, 110, '#FFFFFF', 10)
    img.save(os.path.join(OUT_DIR, 'app_icon_design_04.png'))

def icon_trophy_board():
    img = Image.new('RGB', (512,512), '#312E81')
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([80,120,432,432], radius=40, fill='#4338CA')
    draw_grid(draw, 146, 186, 220, '#FFFFFF', width=8)
    draw_x(draw, 210, 250, 32, '#FBBF24', 10)
    draw_o(draw, 300, 250, 35, '#34D399', 10)
    draw_x(draw, 300, 336, 32, '#FBBF24', 10)
    # trophy shape simplified
    draw.polygon([(236,60),(276,60),(276,100),(296,100),(276,120),(276,140),(236,140),(236,120),(216,100),(236,100)], fill='#FBBF24')
    img.save(os.path.join(OUT_DIR, 'app_icon_design_05.png'))

# ── Feature graphics ─────────────────────────────────────────

def feature_split_players():
    img = Image.new('RGB', (1024,500), '#0F172A')
    draw = ImageDraw.Draw(img)
    # left purple side
    draw.polygon([(0,0),(550,0),(350,500),(0,500)], fill=hex_to_rgb('#6D28D9'))
    # big X and O
    draw_x(draw, 220, 250, 120, '#FFFFFF', 35)
    draw_o(draw, 420, 250, 130, '#FBBF24', 35)
    font_title = get_font(72)
    font_sub = get_font(30)
    draw.text((520, 150), 'Tic Tac Toe', fill='#FFFFFF', font=font_title)
    draw.text((520, 250), 'Multiplayer · Chat · Tournaments', fill='#CBD5E1', font=font_sub)
    img.save(os.path.join(OUT_DIR, 'feature_design_01.png'))

def feature_board_title():
    img = Image.new('RGB', (1024,500), '#1E1040')
    draw = ImageDraw.Draw(img)
    gradient_bg(img, '#1E1040', '#312E81')
    draw.rounded_rectangle([60,60,460,440], radius=40, fill='#4338CA', outline='#818CF8', width=4)
    draw_grid(draw, 90, 90, 340, '#FFFFFF', width=12)
    draw_x(draw, 170, 170, 45, '#FBBF24', 14)
    draw_o(draw, 345, 170, 50, '#34D399', 14)
    draw_x(draw, 170, 345, 45, '#FBBF24', 14)
    draw_o(draw, 345, 345, 50, '#34D399', 14)
    font_title = get_font(70)
    font_sub = get_font(30)
    draw.text((520, 160), 'Play & Win', fill='#FFFFFF', font=font_title)
    draw.text((520, 270), 'Friends, AI, Tournaments', fill='#E9D5FF', font=font_sub)
    img.save(os.path.join(OUT_DIR, 'feature_design_02.png'))

def feature_chat_theme():
    img = Image.new('RGB', (1024,500), '#111827')
    draw = ImageDraw.Draw(img)
    # chat bubbles
    draw.rounded_rectangle([60,120,360,220], radius=24, fill='#374151')
    draw.text((90,150), 'Play now?', fill='#FFFFFF', font=get_font(28))
    draw.rounded_rectangle([620,260,920,360], radius=24, fill='#6D28D9')
    draw.text((650,290), 'Game on!', fill='#FFFFFF', font=get_font(28))
    # X O in center
    draw_x(draw, 512, 250, 100, '#FBBF24', 28)
    draw_o(draw, 512, 250, 60, '#34D399', 18)
    font_title = get_font(60)
    draw.text((300, 400), 'Chat & Challenge Friends', fill='#FFFFFF', font=font_title)
    img.save(os.path.join(OUT_DIR, 'feature_design_03.png'))

def feature_tournament_bracket():
    img = Image.new('RGB', (1024,500), '#0F172A')
    draw = ImageDraw.Draw(img)
    # bracket lines
    lines = [
        (120,140,250,140), (120,340,250,340), (250,140,250,340),
        (250,240,380,240), (620,140,750,140), (620,340,750,340), (750,140,750,340),
        (750,240,880,240), (380,240,620,240)
    ]
    for line in lines:
        draw.line(line, fill='#38BDF8', width=8)
    # player dots
    for x,y in [(120,140),(120,340),(620,140),(620,340),(880,240)]:
        draw.ellipse([x-16,y-16,x+16,y+16], fill='#FBBF24')
    font_title = get_font(60)
    draw.text((180, 380), 'Tournaments with up to 8 Players', fill='#FFFFFF', font=font_title)
    img.save(os.path.join(OUT_DIR, 'feature_design_04.png'))

def feature_minimal_text():
    img = Image.new('RGB', (1024,500), '#312E81')
    draw = ImageDraw.Draw(img)
    # large faint grid in background
    draw_grid(draw, 100, 50, 400, '#FFFFFF', width=2)
    draw_x(draw, 220, 170, 50, '#FBBF24', 16)
    draw_o(draw, 410, 170, 55, '#34D399', 16)
    font_title = get_font(90)
    font_sub = get_font(36)
    draw.text((560, 120), 'Tic Tac Toe', fill='#FFFFFF', font=font_title)
    draw.text((560, 230), 'Online Multiplayer', fill='#C4B5FD', font=font_sub)
    draw.text((560, 300), 'Chat · Tournaments · AI', fill='#C4B5FD', font=font_sub)
    img.save(os.path.join(OUT_DIR, 'feature_design_05.png'))

icon_split_xo()
icon_round_board()
icon_big_x_shadow()
icon_neon_glow()
icon_trophy_board()

feature_split_players()
feature_board_title()
feature_chat_theme()
feature_tournament_bracket()
feature_minimal_text()

print('Done: 5 app icons + 5 feature graphics created.')
