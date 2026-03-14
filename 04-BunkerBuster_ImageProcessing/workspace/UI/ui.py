# 프로토콜 (S: 모양, C: 색상, P: 좌표)
#     모드 전환: 0xDD (1101_1101)
#     사용자 타격 완료: 0x7E (0111_1110)
#     벙커: 1100_PPPP (0xC_)
#     타켓: 1111_PPPP (0xF_)
#     힌트: SSCC_PPPP
#         모양: 01(세모), 10(원)
#         색: 00(빨강), 01(초록), 10(파랑)
import threading
import serial
import pygame
import os
import sys
import random

pygame.init()
pygame.mixer.init()
pygame.font.init()

# UART 설정
SERIAL_PORT = 'COM4'
BAUD_RATE = 9600
ser = None

# 모드 설정
CMD_MODE_TOGGLE = 0xDD
MODE_AUTO = 0
MODE_GAME = 1
current_mode = MODE_AUTO

auto_mode_end = False
fade_alpha = 0
total_strikes = 0
user_strikes = 0

# 해상도 설정
info = pygame.display.Info()
SCREEN_WIDTH, SCREEN_HEIGHT = 2560, 1440

screen = pygame.display.set_mode(
    (SCREEN_WIDTH, SCREEN_HEIGHT), pygame.FULLSCREEN | pygame.DOUBLEBUF | pygame.HWSURFACE)

# 폰트 설정
try:
    if os.path.exists("./font/DaysOne-Regular.ttf"):
        FONT_MODE_LABEL = pygame.font.Font("./font/DaysOne-Regular.ttf", 60)
    else:
        print(f"폰트 파일을 찾을 수 없음: DaysOne-Regular.ttf")
        FONT_MODE_LABEL = pygame.font.SysFont("arial", 60, bold=True)
    if os.path.exists("./font/Micro5-Regular.ttf"):
        FONT_SYS_LARGE = pygame.font.Font("./font/Micro5-Regular.ttf", 150)
        FONT_SYS_MEDIUM = pygame.font.Font("./font/Micro5-Regular.ttf", 80)
        FONT_SYS_SMALL = pygame.font.Font("./font/Micro5-Regular.ttf", 40)
    else:
        print(f"폰트 파일을 찾을 수 없음: Micro5-Regular.ttf")
        FONT_SYS_LARGE = pygame.font.SysFont("arial", 150, bold=True)
        FONT_SYS_MEDIUM = pygame.font.SysFont("arial", 80, bold=True)
        FONT_SYS_SMALL = pygame.font.Font("arial", 40)
except Exception as e:
    print(f"폰트 로딩 오류: {e}")
    FONT_MODE_LABEL = pygame.font.SysFont("airal", 60, bold=True)
    FONT_SYS_LARGE = pygame.font.SysFont("arial", 150, bold=True)
    FONT_SYS_MEDIUM = pygame.font.SysFont("arial", 80, bold=True)
    FONT_SYS_SMALL = pygame.font.Font("arial", 40)

# 5x3 격자 설정
ROWS = 3
COLS = 5

# 색상 정의
GRAY_BEZEL            = (60, 60, 60)
GRAY_FRAME            = (40, 40, 45)
GRAY_GROUND_PARTITION = (128, 128, 128)
BROWN_GROUND_0        = (219, 151, 85)
BROWN_GROUND_1        = (166, 108, 65)
BROWN_GROUND_2        = (140, 85, 48)
RED_TARGET            = (237, 28, 36)
WHITE_TEXT            = (195, 195, 195)
GOLD_TEXT             = (255, 186, 2)

# STM32 명령 코드
CMD_UP     = 0x10
CMD_DOWN   = 0x11
CMD_CENTER = 0x12
CMD_RIGHT  = 0x13
CMD_LEFT   = 0x14
CONTROL_CMDS = {CMD_UP, CMD_DOWN, CMD_CENTER, CMD_RIGHT, CMD_LEFT}

# 사용자 조준점
aim_row = 1
aim_col = 2

# 컴퓨터 화면용 데이터
com_grid_data = [{
    "hint": None,
    "is_target": False,
    "explosion_frame": -1,
    "explosion_timer": 0,
    "is_destroyed": False,
    "hit_count": 0,
    "is_bunker": False
    } for _ in range(15)]

# 게임 모드 사용자 화면용 데이터
game_state = {
    "bunker_pos": None,
    "hints": {},                 # {pos: {"shape_idx": s, "color_idx": c, "rotation": r}}
    "pending_hint_pos": None,
    "revealed_bunker": False,
    "is_win": False,
    "is_lose": False
}

user_grid_data = [{
    "hint": None,
    "is_target": False,
    "explosion_frame": -1,
    "explosion_timer": 0,
    "is_destroyed": False,
    "hit_count": 0,
    "is_bunker": False
    } for _ in range(15)]

data_lock = threading.Lock()

try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)
    print(f"{SERIAL_PORT} 연결됨")
except Exception as e:
    print(f"시리얼 포트 연결 실패: {e}")
    print("시뮬레이션 모드 실행")

# UART 데이터 수신
def data_receiver():
    global ser
    while True:
        if ser and ser.is_open:
            try:
                if ser.in_waiting > 0:
                    raw_data = ser.read(1)[0]
                    result = decode_data(raw_data)

                    if raw_data == CMD_MODE_TOGGLE:
                        toggle_mode()
                        continue
                    if raw_data in CONTROL_CMDS:
                        user_cmd(raw_data)
                        continue
                    if result:
                        update_grid_data(result)

            except Exception as e:
                print(f"데이터 수신 실패: {e}")
                break

# 모드 전환
def toggle_mode():
    global current_mode, auto_mode_end, fade_alpha, total_strikes, user_strikes
    with data_lock:
        current_mode = MODE_GAME if current_mode == MODE_AUTO else MODE_AUTO
        auto_mode_end = False
        fade_alpha = 0
        total_strikes = 0
        user_strikes = 0
        if current_mode == MODE_GAME:
            game_setup()

# 화면 레이아웃
def get_layout_params(mode):
    layouts = {}
    padding = 20

    # 자동 모드
    if mode == MODE_AUTO:
        auto_w = int(SCREEN_WIDTH * 0.8)
        auto_h = int(auto_w * (3/5))
        auto_x = (SCREEN_WIDTH - auto_w) // 2
        auto_y = 50
        layouts['main'] = {'x': auto_x, 'y': auto_y, 'w': auto_w, 'h': auto_h, 'p': padding}
    # 게임 모드
    else:
        # 사용자 화면
        user_w = int(SCREEN_WIDTH * 0.62)
        user_h = int(user_w * (3/5))
        user_x = 80
        user_y = (SCREEN_HEIGHT - user_h) // 2 - 40
        layouts['user'] = {'x': user_x, 'y': user_y, 'w': user_w, 'h': user_h, 'p': padding}

        # 컴퓨터 화면
        com_w = int(SCREEN_WIDTH * 0.22)
        com_h = int(com_w * (3/5))
        com_x = SCREEN_WIDTH - com_w - 100
        com_y = (user_y + user_h) - com_h
        layouts['com'] = {'x': com_x, 'y': com_y, 'w': com_w, 'h': com_h, 'p': 8}

    return layouts

# UART 데이터 디코딩
def decode_data(data_byte):
    upper_4 = (data_byte >> 4) & 0x0F
    lower_4 = data_byte & 0x0F
    
    if lower_4 >= 15: return None

    # 타겟 (1111_PPPP)
    if upper_4 == 0x0F:
        return {"type": "TARGET", "position": lower_4}
    
    # 벙커 (1100_PPPP)
    elif upper_4 == 0x0C:
        return {"type": "BUNKER", "position": lower_4}
    
    # 힌트 (SSCC_PPPP)
    else:
        shape_code = (upper_4 >> 2) & 0x03
        color_code = upper_4 & 0x03
        return {
            "type": "HINT",
            "position": lower_4,
            "shape_idx": shape_code,             # 1: 세모, 2: 원
            "color_idx": color_code,             # 1: 초록, 2: 파랑, 0: 빨강
            "rotation": random.randint(0, 359)
        }

# 사용자 입력
def user_cmd(data_byte):
    global aim_row, aim_col, user_strikes

    with data_lock:
        if data_byte == CMD_UP:
            if aim_row > 0:
                aim_row -= 1

        elif data_byte == CMD_DOWN:
            if aim_row < ROWS - 1:
                aim_row += 1

        elif data_byte == CMD_LEFT:
            if aim_col > 0:
                aim_col -= 1

        elif data_byte == CMD_RIGHT:
            if aim_col < COLS - 1:
                aim_col += 1

        elif data_byte == CMD_CENTER:
            pos = aim_row * COLS + aim_col
            if game_state["is_win"] or game_state["is_lose"] or auto_mode_end: return
            user_grid_data[pos]["is_target"] = True
            user_grid_data[pos]["explosion_timer"] = 30
            user_grid_data[pos]["explosion_frame"] = -1
            if current_mode == MODE_GAME:
                user_strikes += 1
                game_state["pending_hint_pos"] = pos

# 격자 및 데이터 랜더링
def render_view(rect_params, data_source, is_interactive=False, label=None):
    p = rect_params.get('p', 0)
    rx, ry, rw, rh = rect_params['x'], rect_params['y'], rect_params['w'], rect_params['h']
    ox, oy, gw, gh = rx + p, ry + p, rw - (p * 2), rh - (p * 2)
    cw, ch = gw // COLS, gh // ROWS

    frame_margin = 30
    frame_rect = pygame.Rect(rx - frame_margin, ry - frame_margin, rw + frame_margin * 2, rh + frame_margin * 2 + 60)

    # 게임 모드 외각 프레임 및 라벨
    if label:
        pygame.draw.rect(screen, (100, 100, 100), frame_rect, 2, border_radius=20)
        label_surf = FONT_MODE_LABEL.render(label, True, WHITE_TEXT)
        label_rect = label_surf.get_rect(midbottom=(frame_rect.centerx, frame_rect.bottom - 15))
        screen.blit(label_surf, label_rect)

        if label == "USER" and current_mode == MODE_GAME:
            strike_text = f"STRIKES: {user_strikes}"
            strike_surf = FONT_SYS_MEDIUM.render(strike_text, True, GOLD_TEXT)
            strike_rect = strike_surf.get_rect(midtop=(frame_rect.centerx, frame_rect.top - 110))
            screen.blit(strike_surf, strike_rect)

    # 배경 (기본색)
    pygame.draw.rect(screen, BROWN_GROUND_0, (ox, oy, gw, gh))

    # 폭격 흔적
    radius = min(cw, ch) // 2
    # 1회 타격시
    for i in range(15):
        if not data_source[i]["is_destroyed"]: continue

        r, c = i // COLS, i % COLS
        cx, cy = (c * cw + cw // 2) + ox, (r * ch + ch // 2) + oy

        # 가로 인접 체크
        if c < COLS - 1 and data_source[i+1]["is_destroyed"]:
            if not (data_source[i]["hit_count"] >= 2 and data_source[i+1]["hit_count"] >= 2):
                ellipse_w = cw + (radius * 2)
                ellipse_rect = pygame.Rect(cx - radius, cy - radius, ellipse_w, radius * 2)
                pygame.draw.ellipse(screen, BROWN_GROUND_1, ellipse_rect)
        # 세로 인접 체크
        if r < ROWS - 1 and data_source[i+COLS]["is_destroyed"]:
            if not (data_source[i]["hit_count"] >= 2 and data_source[i+COLS]["hit_count"] >= 2):
                ellipse_h = ch + (radius * 2)
                ellipse_rect = pygame.Rect(cx - radius, cy - radius, radius * 2, ellipse_h)
                pygame.draw.ellipse(screen, BROWN_GROUND_1, ellipse_rect)

    # 2회 타격시
    for i in range(15):
        if not data_source[i]["is_destroyed"]: continue

        r, c = i // COLS, i % COLS
        cx, cy = (c * cw + cw // 2) + ox, (r * ch + ch // 2) + oy

        # 가로 인접 체크
        if c < COLS - 1 and data_source[i+1]["is_destroyed"]:
            if data_source[i]["hit_count"] >= 2 and data_source[i+1]["hit_count"] >= 2:
                ellipse_w = cw + (radius * 2)
                ellipse_rect = pygame.Rect(cx - radius, cy - radius, ellipse_w, radius * 2)
                pygame.draw.ellipse(screen, BROWN_GROUND_2, ellipse_rect)
        # 세로 인접 체크
        if r < ROWS - 1 and data_source[i+COLS]["is_destroyed"]:
            if data_source[i]["hit_count"] >= 2 and data_source[i+COLS]["hit_count"] >= 2:
                ellipse_h = ch + (radius * 2)
                ellipse_rect = pygame.Rect(cx - radius, cy - radius, radius * 2, ellipse_h)
                pygame.draw.ellipse(screen, BROWN_GROUND_2, ellipse_rect)

    # 각 칸의 기본 1x1 원
    for i in range(15):
        if data_source[i]["is_destroyed"]:
            r, c = i // COLS, i % COLS
            cx, cy = (c * cw + cw // 2) + ox, (r * ch + ch // 2) + oy
            color = BROWN_GROUND_2 if data_source[i]["hit_count"] >= 2 else BROWN_GROUND_1
            pygame.draw.circle(screen, color, (cx, cy), radius)

    # 구분선
    for r in range(1, ROWS):
        draw_dashed_line(screen, GRAY_GROUND_PARTITION, (0, r*ch), (gw, r*ch), (ox, oy), 2, 8)
    for c in range(1, COLS):
        draw_dashed_line(screen, GRAY_GROUND_PARTITION, (c*cw, 0), (c*cw, gh), (ox, oy), 2, 8)

    target_pos = -1

    # 객체
    for i in range(15):
        node = data_source[i]
        r, c = i // COLS, i % COLS
        cx, cy = (c * cw) + (cw // 2) + ox, (r * ch) + (ch // 2) + oy

        # 폭발
        if node["explosion_frame"] >= 0:
            exp_list = assets.get("EXPLOSION", [])
            if node["explosion_frame"] < len(exp_list):
                img = pygame.transform.scale(exp_list[node["explosion_frame"]], (int(cw*0.9), int(ch*0.9)))
                screen.blit(img, img.get_rect(center=(cx, cy)))
            continue

        if node["is_target"] and node ["explosion_timer"] > 0:
            target_pos = i

        # 벙커 및 힌트
        icon_key = None
        hint_rotation = 0
        if current_mode == MODE_GAME and is_interactive:    # 게임 모드
            # 벙커
            if i == game_state["bunker_pos"] and data_source[i]["hit_count"] >= 2 and not game_state["is_win"]:
                if "BUNKER" in assets:
                    img = pygame.transform.scale(assets["BUNKER"], (int(cw*0.7), int(ch*0.7)))
                    screen.blit(img, img.get_rect(center=(cx, cy)))
                icon_key = None
            # 힌트
            elif i in game_state["hints"]:
                if not (i == game_state["bunker_pos"] and data_source[i]["hit_count"] >= 2):
                    h = game_state["hints"][i]
                    icon_key = f"{'TRIANGLE' if h['shape_idx'] == 1 else 'CIRCLE'}_{h['color_idx']}"
                    hint_rotation = h.get("rotation", 0)
        else:                                               # 자동 모드
            # 벙커
            if node["is_bunker"]:
                if "BUNKER" in assets:
                    img = pygame.transform.scale(assets["BUNKER"], (int(cw*0.7), int(ch*0.7)))
                    screen.blit(img, img.get_rect(center=(cx, cy)))
            # 힌트
            if node["hint"]:
                h = node["hint"]
                icon_key = f"{'TRIANGLE' if h['shape_idx'] == 1 else 'CIRCLE'}_{h['color_idx']}"
                hint_rotation = h.get("rotation", 0)
                
        if icon_key and icon_key in assets:
            if icon_key == "CIRCLE_0":
                orig_w, orig_h = 783, 279
                target_w = int(cw * 0.8)
                target_h = int(target_w * (orig_h / orig_w))
                img = pygame.transform.scale(assets[icon_key], (target_w, target_h))
                img = pygame.transform.rotate(img, hint_rotation)
            else:
                img = pygame.transform.scale(assets[icon_key], (int(cw*0.6), int(ch*0.6)))
            screen.blit(img, img.get_rect(center=(cx, cy)))

    # 조준점
    draw_aim = False
    ax, ay = 0, 0

    if current_mode == MODE_AUTO:
        if target_pos != -1:
            draw_aim = True
            ar, ac = target_pos // COLS, target_pos % COLS
            ax, ay = (ac * cw + cw // 2) + ox, (ar * ch + ch // 2) + oy
    else:
        if is_interactive:
            draw_aim = True
            ax, ay = (aim_col * cw + cw // 2) + ox, (aim_row * ch + ch // 2) + oy

    if draw_aim:
        ts = int(ch // 5)
        pygame.draw.circle(screen, RED_TARGET, (ax, ay), ts, 7)
        pygame.draw.line(screen, RED_TARGET, (ax-ts-12, ay), (ax+ts+12, ay), 7)
        pygame.draw.line(screen, RED_TARGET, (ax, ay-ts-12), (ax, ay+ts+12), 7)
        pygame.draw.circle(screen, RED_TARGET, (ax, ay), 10)

    # 베젤
    draw_bezel(rect_params)

    return frame_rect.top

# 점선
def draw_dashed_line(surf, color, start_pos, end_pos, offset, width=1, dash_length=10):
    x1, y1 = start_pos[0] + offset[0], start_pos[1] + offset[1]
    x2, y2 = end_pos[0] + offset[0], end_pos[1] + offset[1]
    dl = dash_length

    if x1 == x2:      # 수직선
        for y in range(y1, y2, dl * 2):
            pygame.draw.line(surf, color, (x1, y), (x1, min(y + dl, y2)), width)
    elif y1 == y2:    # 수평선
        for x in range(x1, x2, dl * 2):
            pygame.draw.line(surf, color, (x, y1), (min(x + dl, x2), y1), width)

# 카메라 베젤
def draw_bezel(rect_params):
    x, y, w, h = rect_params['x'], rect_params['y'], rect_params['w'], rect_params['h']
    inner_rect = pygame.Rect(x, y, w, h)
    is_mini = w < SCREEN_WIDTH * 0.3
    bz_thick = 12 if is_mini else 25
    bz_inflate = 6 if is_mini else 10

    pygame.draw.rect(screen, GRAY_BEZEL, inner_rect.inflate(bz_inflate, bz_inflate), bz_thick, border_radius=15 if not is_mini else 8)
    pygame.draw.rect(screen, (100, 100, 100), inner_rect.inflate(-bz_thick, -bz_thick), 2)

    mode_str = "AUTO MODE" if current_mode == MODE_AUTO else "GAME MODE"
    text_surf = FONT_MODE_LABEL.render(mode_str, True, WHITE_TEXT)
    text_rect = text_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 650))
    screen.blit(text_surf, text_rect)

# 힌트 가이드 랜더링
def render_hint_guide(x, align_y, w):
    title_surf = FONT_SYS_MEDIUM.render("HINT GUIDE", True, GOLD_TEXT)
    screen.blit(title_surf, (x, align_y))

    guide_rect = pygame.Rect(x - 15, align_y + 90, w + 60, 480)
    pygame.draw.rect(screen, GRAY_BEZEL, guide_rect, border_radius=15)
    middle_y = guide_rect.centery
    draw_dashed_line(screen, (100, 100, 100), (18, middle_y - (align_y + 90)), (guide_rect.width - 18, middle_y - (align_y + 90)), (guide_rect.x, align_y + 90), 2, 10)

    upper_hints = [
        ("CIRCLE_1", "Within 1 block"),          # 환풍구
        ("CIRCLE_2", "Within 3 blocks"),         # 배럴
        ("CIRCLE_0", "Within 4 blocks"),         # 타이어 자국
    ]
    lower_hints = [
        ("TRIANGLE_1", "Over 2 blocks away"),    # 상자
        ("TRIANGLE_2", "Over 4 blocks away"),    # 돌
        ("TRIANGLE_0", "Over 5 blocks away")     # 나무
    ]

    icon_size = 55
    margin_x = 25
    line_height = 70
    
    start_y_upper = guide_rect.top + 30
    for i, (key, desc) in enumerate(upper_hints):
        item_y = start_y_upper + (i * line_height)
        if key in assets:
            img = pygame.transform.scale(assets[key], (icon_size, icon_size))
            screen.blit(img, img.get_rect(midleft=(x + margin_x, item_y + 25)))
        desc_surf = FONT_SYS_SMALL.render(desc, True, WHITE_TEXT)
        screen.blit(desc_surf, (x + margin_x + icon_size + 30, item_y + 5))

    start_y_lower = middle_y + 30
    for i, (key, desc) in enumerate(lower_hints):
        item_y = start_y_lower + (i * line_height)
        if key in assets:
            img = pygame.transform.scale(assets[key], (icon_size, icon_size))
            screen.blit(img, img.get_rect(midleft=(x + margin_x, item_y + 25)))
        desc_surf = FONT_SYS_SMALL.render(desc, True, WHITE_TEXT)
        screen.blit(desc_surf, (x + margin_x + icon_size + 30, item_y + 5))

# 컴퓨터 데이터 업데이트
def update_grid_data(result):
    global total_strikes
    pos = result["position"]
    with data_lock:
        if result["type"] == "TARGET":
            if auto_mode_end: return
            com_grid_data[pos]["is_target"] = True
            com_grid_data[pos]["explosion_timer"] = 30
            com_grid_data[pos]["explosion_frame"] = -1
            total_strikes += 1
        elif result["type"] == "BUNKER":
            com_grid_data[pos]["is_bunker"] = True
        else:
            com_grid_data[pos]["hint"] = result

# 이미지 및 사운드 로딩
def load_assets():
    base_path = os.path.dirname(__file__) if "__file__" in locals() else "."
    assets_dir = os.path.join(base_path, "assets")
    asset_files = {
        "CIRCLE_1": "vent.png",           # 초록 원: 환풍구
        "TRIANGLE_1": "crate.png",         # 초록 삼각형: 상자
        "CIRCLE_2": "barrels.png",        # 파란 원: 배럴
        "TRIANGLE_2": "rock.png",         # 파란 삼각형: 돌
        "CIRCLE_0": "tire_tracks.png",    # 빨간 원: 타이어 자국
        "TRIANGLE_0": "tree.png"         # 빨간 삼각형: 나무
    }
    scaled_assets = {}

    # 힌트
    scaled_assets = {}
    for key, filename in asset_files.items():
        try:
            full_path = os.path.join(assets_dir, filename)
            if os.path.exists(full_path):
                scaled_assets[key] = pygame.image.load(full_path).convert_alpha()
            else:
                print(f"힌트 이미지 파일을 찾을 수 없음: {full_path}")
        except Exception as e:
            print(f"힌트 이미지 로드 실패 ({filename}): {e}")

    # 폭발 이미지
    explosion_assets = []
    for i in range(7):
        try:
            exp_path = os.path.join(assets_dir, f"explosion_{i}.png")
            if os.path.exists(exp_path):
                explosion_assets.append(pygame.image.load(exp_path).convert_alpha())
            else:
                print(f"폭발 이미지 파일을 찾을 수 없음: {exp_path}")
        except Exception as e:
            print(f"폭발 이미지 로드 실패: {e}")
    scaled_assets["EXPLOSION"] = explosion_assets

    # 폭발 사운드
    try:
        sound_path = os.path.join(assets_dir, "explosion.mp3")
        if os.path.exists(sound_path):
            scaled_assets["SOUND_EXPLOSION"] = pygame.mixer.Sound(sound_path)
        else:
            print("폭발 사운드 파일을 찾을 수 없음: explosion.mp3")
            scaled_assets["SOUND_EXPLOSION"] = None
    except Exception as e:
        print(f"폭발 사운드 로드 실패: {e}")
        scaled_assets["SOUND_EXPLOSION"] = None

    # 벙커
    try:
        bunker_path = os.path.join(assets_dir, "bunker.png")
        if os.path.exists(bunker_path):
            scaled_assets["BUNKER"] = pygame.image.load(bunker_path).convert_alpha()
    except Exception as e:
            print(f"벙커 이미지 로드 실패: {e}")

    # 트로피
    try:
        trophy_path = os.path.join(assets_dir, "trophy.png")
        if os.path.exists(trophy_path):
            scaled_assets["TROPHY"] = pygame.image.load(trophy_path).convert_alpha()
        else:
            print("트로피 이미지 파일을 찾을 수 없음: trophy.png")
    except Exception as e:
        print(f"트로피 이미지 로드 실패: {e}")

    return scaled_assets

assets = load_assets()

# 게임 모드 시작 시 벙커 및 초기 힌트 생성
def game_setup():
    game_state["bunker_pos"] = random.randint(0, 14)
    game_state["hints"].clear()
    game_state["is_win"] = False
    game_state["is_lose"] = False

    positions = list(range(15))
    random.shuffle(positions)
    for pos in positions[:3]:
        game_state["hints"][pos] = make_hint(pos)

# 힌트 생성
def make_hint(pos):
    dist = get_distance(pos, game_state["bunker_pos"])
    s_idx, c_idx = choose_hint_type(dist)
    return {"shape_idx": s_idx, "color_idx": c_idx, "rotation": random.randint(0, 359)}

# 두 좌표 간 맨해튼 거리 계산
def get_distance(pos1, pos2):
    r1, c1 = pos1 // COLS, pos1 % COLS
    r2, c2 = pos2 // COLS, pos2 % COLS
    return abs(r1 - r2) + abs(c1 - c2)

# 거리에 따라 힌트 종류 결정
def choose_hint_type(dist):
    candidates = []
    if dist <= 1: candidates.append((2, 1, 25))    # 초록 원
    else:         candidates.append((1, 1, 20))    # 초록 삼각형
    if dist <= 3: candidates.append((2, 2, 50))    # 파란 원
    else:         candidates.append((1, 2, 45))    # 파란 삼각형
    if dist <= 4: candidates.append((2, 0, 40))    # 빨간 원
    else:         candidates.append((2, 0, 35))    # 빨간 삼각형

    weights = [c[2] for c in candidates]
    picked = random.choices(candidates, weights=weights, k=1)[0]
    return picked[0], picked[1]    # shape_idx, color_idx

# 인접 영역 계산
def get_cross_positions(center_pos):
    r, c = center_pos // COLS, center_pos % COLS
    offsets = [(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0)]
    positions = []
    for dr, dc in offsets:
        nr, nc = r + dr, c + dc
        if 0 <= nr < ROWS and 0 <= nc < COLS:
            positions.append(nr * COLS + nc)
    return positions

def main():
    global auto_mode_end, fade_alpha, total_strikes, user_strikes
    thread = threading.Thread(target=data_receiver, daemon=True)
    thread.start()
    clock = pygame.time.Clock()

    fade_surface = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
    fade_surface.fill((0, 0, 0))

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit(); sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit(); sys.exit()
                if event.key == pygame.K_TAB:
                    toggle_mode()
                if (auto_mode_end or game_state["is_win"] or game_state["is_lose"]) and fade_alpha >= 200:
                    if event.key == pygame.K_RETURN:
                        with data_lock:
                            for i in range(15):
                                com_grid_data[i].update({"is_destroyed": False, "hit_count": 0, "is_bunker": False, "hint": None, "is_target": False, "explosion_timer": 0, "explosion_frame": -1})
                                user_grid_data[i].update({"is_destroyed": False, "hit_count": 0, "is_bunker": False, "hint": None, "is_target": False, "explosion_timer": 0, "explosion_frame": -1})
                            auto_mode_end = False
                            fade_alpha = 0
                            total_strikes = 0
                            user_strikes = 0
                            if current_mode == MODE_GAME:
                                game_setup()
            
            # 시뮬레이션용 키보드 입력
            if event.type == pygame.KEYDOWN:
                dummy_byte = 0
                if   event.key == pygame.K_1: dummy_byte = 0x91    # 원, 초록, 1번 칸 (10_01_0001)
                elif event.key == pygame.K_2: dummy_byte = 0x62    # 세모, 파랑, 2번 칸 (01_10_0010)
                elif event.key == pygame.K_3: dummy_byte = 0x83    # 원, 빨강, 3번 칸 (10_00_0011)
                elif event.key == pygame.K_4: dummy_byte = 0xF3    # 타겟, 3번 칸 (1111_0011)
                elif event.key == pygame.K_5: dummy_byte = 0x53    # 세모, 초록, 3번 칸 (01_01_0011)
                elif event.key == pygame.K_6: dummy_byte = 0xF4    # 타겟, 4번 칸 (1111_0100)
                elif event.key == pygame.K_7: dummy_byte = 0xF8    # 타겟, 8번 칸 (1111_1000)
                elif event.key == pygame.K_8: dummy_byte = 0xF9    # 타겟, 9번 칸 (1111_1001)
                elif event.key == pygame.K_9: dummy_byte = 0xCB    # 벙커, 11번 칸 (1100_1011)
                elif event.key == pygame.K_0: dummy_byte = 0xFB    # 타겟, 11번 칸 (1111_1011)

                elif event.key == pygame.K_UP:    dummy_byte = CMD_UP
                elif event.key == pygame.K_DOWN:  dummy_byte = CMD_DOWN
                elif event.key == pygame.K_LEFT:  dummy_byte = CMD_LEFT
                elif event.key == pygame.K_RIGHT: dummy_byte = CMD_RIGHT
                elif event.key == pygame.K_SPACE: dummy_byte = CMD_CENTER
                
                if dummy_byte != 0:
                    if dummy_byte in CONTROL_CMDS:
                        user_cmd(dummy_byte)
                    else:
                        update_grid_data(decode_data(dummy_byte))

        # 애니메이션 및 게임 로직 업데이트
        with data_lock:
            for source in [com_grid_data, user_grid_data]:
                for i in range(15):
                    if source[i]["is_target"]:
                        if source[i]["explosion_timer"] > 0:
                            source[i]["explosion_timer"] -= 1
                            if source[i]["explosion_timer"] == 0:
                                source[i]["explosion_frame"] = 0
                                if assets["SOUND_EXPLOSION"]: assets["SOUND_EXPLOSION"].play()
                        elif source[i]["explosion_frame"] >= 0:
                            if pygame.time.get_ticks() % 3 == 0:
                                source[i]["explosion_frame"] += 1
                                if source[i]["explosion_frame"] >= 7:
                                    is_bunker_destruction = source[i]["is_bunker"]
                                    source[i].update({"is_target": False, "explosion_frame": -1, "hint": None, "is_bunker": False, "is_destroyed": True})
                                    source[i]["hit_count"] += 1
                                    if current_mode == MODE_AUTO and is_bunker_destruction:
                                        auto_mode_end = True

                                    if current_mode == MODE_GAME and source is com_grid_data:
                                        if is_bunker_destruction:
                                            game_state["is_lose"] = True
                                    if source is user_grid_data and current_mode == MODE_GAME:
                                        if ser and ser.is_open:
                                            try: ser.write(bytes([0x7E]))
                                            except Exception as e: print(f"타격 완료 신호 송신 오류: {e}")
                                        pending_pos = game_state["pending_hint_pos"]
                                        if pending_pos is not None:
                                            is_bunker_pos = (pending_pos == game_state["bunker_pos"])
                                            if is_bunker_pos:
                                                if user_grid_data[pending_pos]["hit_count"] == 2:
                                                    game_state["revealed_bunker"] = True
                                                elif user_grid_data[pending_pos]["hit_count"] >= 3:
                                                    game_state["is_win"] = True
                                            else:
                                                candidates = get_cross_positions(pending_pos)
                                                random.shuffle(candidates)
                                                hint_count = random.randint(1, min(3, len(candidates)))
                                                for h_idx in range(hint_count):
                                                    h_pos = candidates[h_idx]
                                                    if h_pos == game_state["bunker_pos"] and user_grid_data[h_pos]["hit_count"] >= 2: continue
                                                    game_state["hints"][h_pos] = make_hint(h_pos)
                                            game_state["pending_hint_pos"] = None

        # 랜더링
        screen.fill((10, 10, 15))
        layouts = get_layout_params(current_mode)
        if current_mode == MODE_AUTO:
            render_view(layouts['main'], com_grid_data, is_interactive=True)
        else:
            u_top = render_view(layouts['user'], user_grid_data, is_interactive=True, label="USER")
            render_view(layouts['com'], com_grid_data, is_interactive=False, label="PC")
            render_hint_guide(layouts['com']['x'] - 20, u_top, layouts['com']['w'])

        # 결과 화면
        if auto_mode_end or game_state["is_win"] or game_state["is_lose"]:
            if fade_alpha < 220:
                fade_alpha += 5
            fade_surface.set_alpha(fade_alpha)
            screen.blit(fade_surface, (0, 0))
            if fade_alpha > 100:
                if game_state["is_win"] and "TROPHY" in assets:
                    trophy_img = pygame.transform.scale(assets["TROPHY"], (130, 130))
                    trophy_rect = trophy_img.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 230))
                    screen.blit(trophy_img, trophy_rect)
                if game_state["is_win"]:
                    title_str = "YOU WIN!"
                    count_str = f"Total Strikes: {user_strikes}"
                elif game_state["is_lose"]:
                    title_str = "YOU LOSE!"
                    count_str = f"PC Total Strikes: {total_strikes}"
                else:
                    title_str = "AUTO BUNKER SEARCH ENDS"
                    count_str = f"Total Strikes: {total_strikes}"
                end_text = FONT_SYS_LARGE.render(title_str, True, WHITE_TEXT)
                text_rect = end_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 100))
                screen.blit(end_text, text_rect)
                strike_text = FONT_SYS_MEDIUM.render(count_str, True, GOLD_TEXT)
                strike_rect = strike_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 100))
                screen.blit(strike_text, strike_rect)
                sub_text = FONT_SYS_SMALL.render("Press ENTER to restart", True, WHITE_TEXT)
                sub_rect = sub_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 500))
                if (pygame.time.get_ticks() // 500) % 2 == 0:
                    screen.blit(sub_text, sub_rect)

        pygame.display.flip()
        clock.tick(30)

if __name__ == "__main__":
    main()
