# 프로토콜 (C: 색상, P: 좌표)
#     모드 전환: 0xDD (1101_1101)
#     사용자 타격 완료: 0x7E (0111_1110)
#     게임 종료: 0001_0000 (0x10)
#     벙커: 0100_PPPP (0x4_)
#     타켓: 1111_PPPP (0xF_)
#     힌트: CCCC_PPPP
#         색: 0101(초록), 1000(파랑)
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
BAUD_RATE = 9600
PORT_FPGA = 'COM4'
PORT_STM32 = 'COM12'
ser_fpga = None
ser_stm32 = None

HINT_GREEN = 0x05
HINT_BLUE  = 0x08

# 모드 설정
CMD_MODE_TOGGLE = 0xDD
MODE_AUTO = 0
MODE_GAME = 1
current_mode = MODE_AUTO

# 게임 모드 세부 상태
STATE_INTRO = 0
STATE_NAME_INPUT = 1
STATE_RETRY_CHECK = 2
STATE_PLAYING = 3
game_sub_state = STATE_INTRO

# 사용자 닉네임 및 랭킹
current_user_name = ""
user_records = {}         # {"닉네임": 최저_타격_횟수}
retry_selection = True

game_intro_active = False
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
        FONT_SYS_SMALL = pygame.font.SysFont("arial", 40)
except Exception as e:
    print(f"폰트 로딩 오류: {e}")
    FONT_MODE_LABEL = pygame.font.SysFont("arial", 60, bold=True)
    FONT_SYS_LARGE = pygame.font.SysFont("arial", 150, bold=True)
    FONT_SYS_MEDIUM = pygame.font.SysFont("arial", 80, bold=True)
    FONT_SYS_SMALL = pygame.font.SysFont("arial", 40)

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
    "is_bunker": False,
    "bunker_received_count": 0
    } for _ in range(15)]

# 게임 모드 사용자 화면용 데이터
game_state = {
    "bunker_pos": None,
    "hints": {},                 # {pos: {"color_idx": c}}
    "pending_hint_pos": None,
    "revealed_bunker": False,
    "is_win": False,
    "is_lose": False,
    "record_updated": False
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

# 포트 초기화
try:
    ser_fpga = serial.Serial(PORT_FPGA, BAUD_RATE, timeout=0.1)
    print(f"FPGA ({PORT_FPGA}) 연결됨")
except Exception as e:
    print(f"FPGA 연결 실패: {e}")

try:
    ser_stm32 = serial.Serial(PORT_STM32, BAUD_RATE, timeout=0.1)
    print(f"STM32 ({PORT_STM32}) 연결됨")
except Exception as e:
    ser_stm32 = None
    print(f"STM32 연결 실패: {e}")

# FPGA 수신
def fpga_receiver():
    global ser_fpga
    while True:
        if ser_fpga and ser_fpga.is_open:
            try:
                if ser_fpga.in_waiting > 0:
                    raw_data = ser_fpga.read(1)[0]
                    if raw_data == CMD_MODE_TOGGLE:
                        toggle_mode()
                    else:
                        result = decode_data(raw_data)
                        if result: update_grid_data(result)
            except: break

# STM32 수신
def stm32_receiver():
    global ser_stm32
    while True:
        if ser_stm32 and ser_stm32.is_open:
            try:
                if ser_stm32.in_waiting > 0:
                    raw_data = ser_stm32.read(1)[0]
                    if raw_data in CONTROL_CMDS:
                        user_cmd(raw_data)
            except: break
        else:
            pygame.time.wait(100)

# UART 데이터 송신
def send_data(device_ser, data_byte):
    if device_ser and device_ser.is_open:
        try:
            device_ser.write(bytes([data_byte]))
        except Exception as e:
            print(f"송신 실패: {e}")

# UART 데이터 디코딩
def decode_data(data_byte):
    upper_4 = (data_byte >> 4) & 0x0F
    lower_4 = data_byte & 0x0F
    
    if lower_4 >= 15: return None

    # 타겟 (1111_PPPP)
    if upper_4 == 0x0F:
        return {"type": "TARGET", "position": lower_4}
    
    # 벙커 (0100_PPPP)
    elif upper_4 == 0x04:
        return {"type": "BUNKER", "position": lower_4}
    
    # 힌트 (CCCC_PPPP)
    else:
        color_code = upper_4
        return {
            "type": "HINT",
            "position": lower_4,
            "color_idx": color_code,              # 5: 초록, 8: 파랑
        }

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
            com_grid_data[pos]["bunker_received_count"] += 1
            if com_grid_data[pos]["bunker_received_count"] >= 2:
                com_grid_data[pos]["is_bunker"] = True
        else:
            com_grid_data[pos]["hint"] = result

# 모드 전환
def toggle_mode():
    global current_mode, game_sub_state, game_intro_active, current_user_name, auto_mode_end, fade_alpha, total_strikes, user_strikes
    with data_lock:
        if current_mode == MODE_AUTO:
            current_mode = MODE_GAME
            game_sub_state = STATE_INTRO
            game_intro_active = True
            current_user_name = ""
        else:
            current_mode = MODE_AUTO
            game_intro_active = False
        auto_mode_end = False
        fade_alpha = 0
        total_strikes = 0
        user_strikes = 0

# 사용자 입력
def user_cmd(data_byte):
    global game_intro_active, game_sub_state, retry_selection, aim_row, aim_col, user_strikes

    with data_lock:
        if game_intro_active:
            if game_sub_state == STATE_INTRO:
                if data_byte == CMD_CENTER:
                    game_sub_state = STATE_NAME_INPUT
            elif game_sub_state == STATE_RETRY_CHECK:
                if   data_byte == CMD_LEFT:  retry_selection = True
                elif data_byte == CMD_RIGHT: retry_selection = False
                elif data_byte == CMD_CENTER:
                    if retry_selection: start_game()
                    else: game_sub_state = STATE_NAME_INPUT
            return
        
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
                user_grid_data[pos]["pending_logic"] = True

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

        if is_interactive and current_mode == MODE_GAME:
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
        if current_mode == MODE_GAME and is_interactive:    # 게임 모드
            # 벙커
            if i == game_state["bunker_pos"] and data_source[i]["hit_count"] >= 2 and not game_state["is_win"]:
                if "BUNKER" in assets:
                    img = pygame.transform.scale(assets["BUNKER"], (int(cw*0.7), int(ch*0.7)))
                    screen.blit(img, img.get_rect(center=(cx, cy)))
            # 힌트
            elif i in game_state["hints"]:
                if not (i == game_state["bunker_pos"] and data_source[i]["hit_count"] >= 2):
                    h = game_state["hints"][i]
                    icon_key = "VENT" if h['color_idx'] == 0x05 else "TREE"
        else:                                               # 자동 모드
            # 벙커
            if node["is_bunker"]:
                if "BUNKER" in assets:
                    img = pygame.transform.scale(assets["BUNKER"], (int(cw*0.7), int(ch*0.7)))
                    screen.blit(img, img.get_rect(center=(cx, cy)))
            # 힌트
            if node["hint"]:
                h = node["hint"]
                icon_key = "VENT" if h['color_idx'] == 0x05 else "TREE"
                
        if icon_key and icon_key in assets:
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

# 힌트 가이드
def render_hint_guide(x, align_y, w):
    title_surf = FONT_SYS_MEDIUM.render("HINT GUIDE", True, GOLD_TEXT)
    screen.blit(title_surf, (x, align_y))

    guide_rect = pygame.Rect(x - 15, align_y + 90, w + 60, 180)
    pygame.draw.rect(screen, GRAY_BEZEL, guide_rect, border_radius=15)
    
    hints = [
        ("VENT", "Within 2 block"),
        ("TREE", "Over 3 blocks away"),
    ]
    icon_size = 55
    margin_x = 25
    line_height = 70
    start_y_upper = guide_rect.top + 30
    
    for i, (key, desc) in enumerate(hints):
        item_y = start_y_upper + (i * line_height)
        if key in assets:
            img = pygame.transform.scale(assets[key], (icon_size, icon_size))
            screen.blit(img, img.get_rect(midleft=(x + margin_x, item_y + 25)))
        desc_surf = FONT_SYS_SMALL.render(desc, True, WHITE_TEXT)
        screen.blit(desc_surf, (x + margin_x + icon_size + 30, item_y + 5))

# 랭커 출력
def render_ranker(x, align_y, w):
    title_surf = FONT_SYS_MEDIUM.render("RANKERS", True, GOLD_TEXT)
    screen.blit(title_surf, (x, align_y))

    rank_rect = pygame.Rect(x - 15, align_y + 90, w + 60, 180)
    pygame.draw.rect(screen, GRAY_BEZEL, rank_rect, border_radius=15)

    if not user_records:
        empty_surf = FONT_SYS_SMALL.render("No records yet", True, (100, 100, 100))
        screen.blit(empty_surf, empty_surf.get_rect(center=rank_rect.center))
        return
    
    sorted_items = sorted(user_records.items(), key=lambda item: item[1])

    icon_size = 40
    line_height = 40
    current_draw_y = rank_rect.top + 30
    max_draw_count = 3
    draw_count = 0

    unique_scores = sorted(list(set(user_records.values())))
    
    for username, score in sorted_items:
        if draw_count >= max_draw_count: break

        try:
            rank_idx = unique_scores.index(score) + 1
        except ValueError:
            rank_idx = 99

        trophy_key = f"TROPHY_{rank_idx}"
        if rank_idx <= 3 and trophy_key in assets:
            img = pygame.transform.scale(assets[trophy_key], (icon_size, icon_size))
            screen.blit(img, (x + 25, current_draw_y))

        display_name = (username[:10] + "..") if len(username) > 10 else username
        name_surf = FONT_SYS_SMALL.render(f"{display_name}", True, WHITE_TEXT)
        score_surf = FONT_SYS_SMALL.render(f"{score} Hits", True, GOLD_TEXT)
        
        screen.blit(name_surf, (x + 25 + icon_size + 25, current_draw_y))
        screen.blit(score_surf, (x + w - 70, current_draw_y))

        current_draw_y += line_height
        draw_count += 1

# 이미지 및 사운드 로딩
def load_assets():
    base_path = os.path.dirname(__file__) if "__file__" in locals() else "."
    assets_dir = os.path.join(base_path, "assets")
    asset_files = {
        "VENT": "vent.png",    # 초록: 환풍구
        "TREE": "tree.png"     # 파랑: 나무
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
    for i in range(1, 4):
        try:
            trophy_path = os.path.join(assets_dir, f"trophy_{i}.png")
            if os.path.exists(trophy_path):
                scaled_assets[f"TROPHY_{i}"] = pygame.image.load(trophy_path).convert_alpha()
            else:
                print("트로피 이미지 파일을 찾을 수 없음: trophy_1.png")
        except Exception as e:
            print(f"트로피 이미지 로드 실패: {e}")

    return scaled_assets

assets = load_assets()

# 게임 모드 인트로 화면
def render_game_intro():
    screen.fill((0, 0, 0))

    if "BUNKER" in assets:
        bunker_img = pygame.transform.scale(assets["BUNKER"], (400, 400))
        bunker_rect = bunker_img.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 150))
        screen.blit(bunker_img, bunker_rect)

    title_surf = FONT_SYS_LARGE.render("BUNKER BUSTER", True, WHITE_TEXT)
    title_rect = title_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 180))
    screen.blit(title_surf, title_rect)

    if (pygame.time.get_ticks() // 600) % 2 == 0:
        sub_surf = FONT_SYS_SMALL.render("PRESS ENTER TO START", True, WHITE_TEXT)
        sub_rect = sub_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 400))
        screen.blit(sub_surf, sub_rect)

# 닉네임 입력 화면
def render_name_input():
    screen.fill((0, 0, 0))

    if "BUNKER" in assets:
        bunker_img = pygame.transform.scale(assets["BUNKER"], (400, 400))
        bunker_rect = bunker_img.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 150))
        screen.blit(bunker_img, bunker_rect)

    title_surf = FONT_SYS_MEDIUM.render("Enter Your Name", True, GOLD_TEXT)
    title_rect = title_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 180))
    screen.blit(title_surf, title_rect)

    name_surf = FONT_SYS_SMALL.render(current_user_name + ("_" if (pygame.time.get_ticks() // 400) % 2 == 0 else ""), True, WHITE_TEXT)
    name_rect = name_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 320))
    screen.blit(name_surf, name_rect)

# 재도전 확인 화면
def render_retry_check():
    screen.fill((0, 0, 0))

    if "BUNKER" in assets:
        bunker_img = pygame.transform.scale(assets["BUNKER"], (400, 400))
        bunker_rect = bunker_img.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 150))
        screen.blit(bunker_img, bunker_rect)

    msg_surf = FONT_SYS_MEDIUM.render(f"Welcome back, {current_user_name}!", True, GOLD_TEXT)
    msg_rect = msg_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 100))
    screen.blit(msg_surf, msg_rect)

    check_surf = FONT_SYS_MEDIUM.render("Wanna retry?", True, WHITE_TEXT)
    check_rect = check_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 250))
    screen.blit(check_surf, check_rect)

    # YES/NO 선택
    yes_color = GOLD_TEXT if retry_selection else GRAY_GROUND_PARTITION
    no_color = GOLD_TEXT if not retry_selection else GRAY_GROUND_PARTITION
    yes_surf = FONT_SYS_MEDIUM.render("YES", True, yes_color)
    no_surf = FONT_SYS_MEDIUM.render("NO", True, no_color)
    yes_rect = yes_surf.get_rect(center=(SCREEN_WIDTH // 2 - 200, SCREEN_HEIGHT // 2 + 450))
    no_rect = no_surf.get_rect(center=(SCREEN_WIDTH // 2 + 200, SCREEN_HEIGHT // 2 + 450))
    screen.blit(yes_surf, yes_rect)
    screen.blit(no_surf, no_rect)

    # 선택 표시 화살표
    sel_x = yes_rect.centerx if retry_selection else no_rect.centerx
    pygame.draw.polygon(screen, GOLD_TEXT, [(sel_x - 20, yes_rect.top - 20), (sel_x + 20, yes_rect.top - 20), (sel_x, yes_rect.top - 5)])

# 게임 플레이 시작
def start_game():
    global game_sub_state, game_intro_active, current_user_name
    game_sub_state = STATE_PLAYING
    game_intro_active = False

    for i in range(15):
        user_grid_data[i].update({"is_destroyed": False, "hit_count": 0, "is_bunker": False, "hint": None, "is_target": False, "explosion_timer": 0, "explostion_frame": -1})
    game_setup()

# 게임 모드 초기화 및 벙커 랜덤 생성
def game_setup():
    game_state["bunker_pos"] = random.randint(0, 14)
    game_state["hints"].clear()
    game_state["is_win"] = False
    game_state["is_lose"] = False
    generate_initial_hints()

# 초기 힌트 생성
def generate_initial_hints():
    global game_state
    game_state["hints"].clear()
    bp = game_state["bunker_pos"]
    if bp is None: return

    all_pos = list(range(ROWS * COLS))
    near = [p for p in all_pos if get_distance(p, bp) <= 2]
    far = [p for p in all_pos if get_distance(p, bp) > 2]

    random.shuffle(near)
    random.shuffle(far)
    selected = []

    for _ in range(2):
        if near: selected.append((near.pop(), HINT_GREEN))
    for _ in range(1):
        if far: selected.append((far.pop(), HINT_BLUE))

    remaining = [p for p in all_pos if p not in [s[0] for s in selected]]
    random.shuffle(remaining)
    while len(selected) < 3 and remaining:
        p = remaining.pop()
        c = HINT_GREEN if get_distance(p, bp) <= 2 else HINT_BLUE
        selected.append((p, c))

    for pos, color in selected:
        game_state["hints"][pos] = {"color_idx": color}
        send_data(ser_stm32, (color << 4) | pos)

# 타격 후 힌트 생성
def generate_hints_after_hits(target_pos):
    global game_state
    bp = game_state["bunker_pos"]
    if bp is None or game_state["revealed_bunker"]: return

    candidates = get_cross_positions(target_pos)
    near = [p for p in candidates if get_distance(p, bp) <= 2]
    far = [p for p in candidates if get_distance(p, bp) > 2]
    random.shuffle(near)
    random.shuffle(far)

    count = choose_hint_count_after_hits(len(candidates))
    selected = []
    r = random.random()

    if count == 1:
        g, b = (1, 0) if r < 0.80 else (0, 1)
    elif count == 2:
        g, b = (2, 0) if r < 0.70 else (1, 1)
    else:
        g, b = (3, 0) if r < 0.40 else (2, 1)

    for _ in range(g):
        if near: selected.append((near.pop(), HINT_GREEN))
    for _ in range(b):
        if far: selected.append((far.pop(), HINT_BLUE))

    remaining = [p for p in candidates if p not in [s[0] for s in selected]]
    random.shuffle(remaining)
    while len(selected) < count and remaining:
        p = remaining.pop()
        c = HINT_GREEN if get_distance(p, bp) <= 2 else HINT_BLUE
        selected.append((p, c))

    for pos, color in selected:
        if pos == bp and user_grid_data[pos]["hit_count"] >= 2: continue
        game_state["hints"][pos] = {"color_idx": color}
        send_data(ser_stm32, (color << 4) | pos)

# 두 좌표 간 맨해튼 거리 계산
def get_distance(pos1, pos2):
    r1, c1 = pos1 % COLS, pos1 // COLS
    r2, c2 = pos2 % COLS, pos2 // COLS
    return abs(r1 - r2) + abs(c1 - c2)

# 인접 영역 계산
def get_cross_positions(center_pos):
    r, c = center_pos % COLS, center_pos // COLS
    offsets = [(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0)]
    positions = []
    for dr, dc in offsets:
        nr, nc = r + dr, c + dc
        if 0 <= nr < COLS and 0 <= nc < ROWS:
            positions.append(nc * COLS + nr)
    return positions

# 힌트 개수 결정
def choose_hint_count_after_hits(max_count):
    r = random.random()
    if max_count <= 1: return 1
    if max_count == 2: return 1 if r < 0.60 else 2
    if r < 0.50: return 1
    elif r < 0.85: return 2
    else: return 3

def main():
    global game_intro_active, game_sub_state, current_user_name, retry_selection, auto_mode_end, fade_alpha, total_strikes, user_strikes
    threading.Thread(target=fpga_receiver, daemon=True).start()
    threading.Thread(target=stm32_receiver, daemon=True).start()
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
                    continue
                if game_intro_active:
                    if game_sub_state == STATE_INTRO:
                        if event.key == pygame.K_RETURN:
                            game_sub_state = STATE_NAME_INPUT
                    elif game_sub_state == STATE_NAME_INPUT:
                        if event.key == pygame.K_BACKSPACE:
                            current_user_name = current_user_name[:-1]
                        elif event.key == pygame.K_RETURN and current_user_name.strip():
                            if current_user_name in user_records:
                                game_sub_state = STATE_RETRY_CHECK
                                retry_selection = True
                            else:
                                start_game()
                        elif len(current_user_name) < 10:
                            if event.unicode.isalnum():
                                current_user_name += event.unicode
                    elif game_sub_state == STATE_RETRY_CHECK:
                        if event.key == pygame.K_LEFT: retry_selection = True
                        elif event.key == pygame.K_RIGHT: retry_selection = False
                        elif event.key == pygame.K_RETURN:
                            if retry_selection: start_game()
                            else: game_sub_state = STATE_NAME_INPUT
                    continue

                if (auto_mode_end or game_state["is_win"] or game_state["is_lose"]) and fade_alpha >= 200:
                    if event.key == pygame.K_RETURN:
                        with data_lock:
                            for i in range(15):
                                com_grid_data[i].update({"is_destroyed": False, "hit_count": 0, "is_bunker": False, "hint": None, "is_target": False, "explosion_timer": 0, "explosion_frame": -1})
                                user_grid_data[i].update({"is_destroyed": False, "hit_count": 0, "is_bunker": False, "hint": None, "is_target": False, "explosion_timer": 0, "explosion_frame": -1})
                            game_state["record_updated"] = False 
                            game_state["revealed_bunker"] = False
                            game_state["is_win"] = False
                            game_state["is_lose"] = False
                            auto_mode_end = False
                            fade_alpha = 0
                            total_strikes = 0
                            user_strikes = 0
                            if current_mode == MODE_GAME:
                                game_sub_state = STATE_INTRO
                                game_intro_active = True
                                current_user_name = ""
            
            # 시뮬레이션용 키보드 입력
            if event.type == pygame.KEYDOWN:
                dummy_byte = 0
                if   event.key == pygame.K_1: dummy_byte = 0x51    # 초록, 1번 칸 (0101_0001)
                elif event.key == pygame.K_2: dummy_byte = 0x82    # 파랑, 2번 칸 (1000_0010)
                elif event.key == pygame.K_3: dummy_byte = 0xF3    # 타켓, 3번 칸 (1111_0011)
                elif event.key == pygame.K_4: dummy_byte = 0x43    # 벙커, 3번 칸 (0100_0011)

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

        if current_mode == MODE_GAME and game_intro_active:
            if game_sub_state == STATE_INTRO:
                render_game_intro()
            elif game_sub_state == STATE_NAME_INPUT:
                render_name_input()
            elif game_sub_state == STATE_RETRY_CHECK:
                render_retry_check()
                
            pygame.display.flip()
            clock.tick(30)
            continue

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
                                            send_data(ser_stm32, 0x10)
                                    if source is user_grid_data and current_mode == MODE_GAME:
                                        send_data(ser_fpga, 0x7E)
                                        if source[i].get("pending_logic"):
                                            if i == game_state["bunker_pos"]:
                                                if source[i]["hit_count"] == 1:
                                                    generate_hints_after_hits(i)
                                                elif source[i]["hit_count"] == 2:
                                                    game_state["revealed_bunker"] = True
                                                    send_data(ser_stm32, 0x40 | i)
                                                elif source[i]["hit_count"] >= 3:
                                                    game_state["is_win"] = True
                                                    if not game_state["record_updated"]:
                                                        name = current_user_name.strip() if current_user_name.strip() else "GUEST"
                                                        if name not in user_records or user_strikes < user_records[name]:
                                                            user_records[name] = user_strikes
                                                        game_state["record_updated"] = True
                                                    send_data(ser_stm32, 0x10)
                                            else:
                                                generate_hints_after_hits(i)
                                            source[i]["pending_logic"] = False

        # 랜더링
        screen.fill((10, 10, 15))
        layouts = get_layout_params(current_mode)
        if current_mode == MODE_AUTO:
            render_view(layouts['main'], com_grid_data, is_interactive=True)
        else:
            u_top = render_view(layouts['user'], user_grid_data, is_interactive=True, label=current_user_name.upper())
            render_view(layouts['com'], com_grid_data, is_interactive=False, label="PC")
            render_hint_guide(layouts['com']['x'] - 20, u_top, layouts['com']['w'])
            render_ranker(layouts['com']['x'] - 20, u_top + 300, layouts['com']['w'])

        # 결과 화면
        if auto_mode_end or game_state["is_win"] or game_state["is_lose"]:
            if fade_alpha < 220: fade_alpha += 5
            fade_surface.set_alpha(fade_alpha)
            screen.blit(fade_surface, (0, 0))
            if fade_alpha > 100:
                if game_state["is_win"]:
                    u_scores = sorted(list(set(user_records.values())))
                    try:
                        my_rank = u_scores.index(user_strikes) + 1
                    except: my_rank == 99
                    trophy_key = f"TROPHY_{my_rank}"
                    if my_rank <= 3 and trophy_key in assets:
                        trophy_img = pygame.transform.scale(assets[f"TROPHY_{my_rank}"], (130, 130))
                        trophy_rect = trophy_img.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 230))
                        screen.blit(trophy_img, trophy_rect)
                title_str = "VICTORY!" if game_state["is_win"] else ("DEFEAT..." if game_state["is_lose"] else "AUTO BUNKER SEARCH ENDS")
                count_str = f"Total Strikes: {user_strikes if current_mode == MODE_GAME else total_strikes}"
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
