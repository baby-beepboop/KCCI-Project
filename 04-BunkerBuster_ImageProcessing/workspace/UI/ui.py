import threading
import serial
import pygame
import os
import sys

# 공유 데이터 및 쓰레드 안전을 위한 Lock
grid_data = [
    {"hint": None, "is_target": False, "explosion_frame": -1, "explosion_timer": 0, "is_destroyed": False,
     "hit_count": 0, "is_bunker": False} for _ in range(15)]
data_lock = threading.Lock()

# UART 설정
SERIAL_PORT = 'COM4'
BAUD_RATE = 9600
ser = None

pygame.init()
pygame.mixer.init()

# 해상도 설정
info = pygame.display.Info()
SCREEN_WIDTH, SCREEN_HEIGHT = 2560, 1440 
MARGIN = 60 
GAME_WIDTH = SCREEN_WIDTH - (MARGIN * 2)
GAME_HEIGHT = SCREEN_HEIGHT - (MARGIN * 2)
OFFSET_X, OFFSET_Y = MARGIN, MARGIN

screen = pygame.display.set_mode(
    (SCREEN_WIDTH, SCREEN_HEIGHT), pygame.FULLSCREEN | pygame.DOUBLEBUF | pygame.HWSURFACE)

# 5x3 격자 설정
ROWS = 3
COLS = 5
CELL_WIDTH = GAME_WIDTH // COLS
CELL_HEIGHT = GAME_HEIGHT // ROWS

# 색상 정의
BLACK_BEZEL           = (30, 30, 30)
GRAY_GROUND_PARTITION = (128, 128, 128)
BROWN_GROUND_0        = (219, 151, 85)
BROWN_GROUND_1        = (166, 108, 65)
BROWN_GROUND_2        = (140, 85, 48)
RED_TARGET            = (237, 28, 36)

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
                    if result:
                        update_grid_data(result)

            except Exception as e:
                print(f"데이터 수신 실패: {e}")
                break

# UART 데이터 디코딩
def decode_data(data_byte):
    upper_4 = (data_byte >> 4) & 0x0F
    lower_4 = data_byte & 0x0F
    
    if lower_4 >= 15: return None

    # 타겟 (1111)
    if upper_4 == 0x0F:
        return {"type": "TARGET", "position": lower_4}
    
    # 벙커 (1100)
    elif upper_4 == 0x0C:
        return {"type": "BUNKER", "position": lower_4}
    
    # 힌트
    else:
        shape_code = (upper_4 >> 2) & 0x03
        color_code = upper_4 & 0x03
        return {
            "type": "HINT",
            "position": lower_4,
            "shape_idx": shape_code,    # 0: 원, 1: 삼각형
            "color_idx": color_code     # 0: 초록, 1: 파랑, 2: 노랑
        }

# 카메라 베젤
def draw_bezel():
    bezel_surf = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
    bezel_surf.fill(BLACK_BEZEL)

    inner_rect = pygame.Rect(OFFSET_X, OFFSET_Y, GAME_WIDTH, GAME_HEIGHT)
    pygame.draw.rect(bezel_surf, (0, 0, 0, 0), inner_rect, border_radius=50)

    screen.blit(bezel_surf, (0, 0))

    pygame.draw.rect(screen, (60, 60, 60), inner_rect, 2, border_radius=50)

# 점선
def draw_dashed_line(surf, color, start_pos, end_pos, width=1, dash_length=10):
    x1, y1 = start_pos[0] + OFFSET_X, start_pos[1] + OFFSET_Y
    x2, y2 = end_pos[0] + OFFSET_X, end_pos[1] + OFFSET_Y
    dl = dash_length

    if x1 == x2:      # 수직선
        for y in range(y1, y2, dl * 2):
            pygame.draw.line(surf, color, (x1, y), (x1, min(y + dl, y2)), width)
    elif y1 == y2:    # 수평선
        for x in range(x1, x2, dl * 2):
            pygame.draw.line(surf, color, (x, y1), (min(x + dl, x2), y1), width)

# 격자
def draw_grid():
    # 기본 배경색
    for row in range(ROWS):
        for col in range(COLS):
            x, y = col * CELL_WIDTH + OFFSET_X, row * CELL_HEIGHT + OFFSET_Y
            pygame.draw.rect(screen, BROWN_GROUND_0, (x, y, CELL_WIDTH, CELL_HEIGHT))

    radius = min(CELL_WIDTH, CELL_HEIGHT) // 2
            
    # 폭격 지점 배경색
    with data_lock:
        # 인접 영역의 타원
        for i in range(15):
            if not grid_data[i]["is_destroyed"]: continue
            row, col = i // COLS, i % COLS
            x, y = col * CELL_WIDTH + OFFSET_X, row * CELL_HEIGHT + OFFSET_Y
            cx, cy = x + CELL_WIDTH // 2, y + CELL_HEIGHT // 2
            
            # 가로 인접 체크
            if col < COLS - 1 and grid_data[i + 1]["is_destroyed"]:
                if not (grid_data[i]["hit_count"] >= 2 and grid_data[i+1]["hit_count"] >= 2):
                    ellipse_w = CELL_WIDTH + (radius * 2)
                    ellipse_rect = pygame.Rect(cx - radius, cy - radius, ellipse_w, radius * 2)
                    pygame.draw.ellipse(screen, BROWN_GROUND_1, ellipse_rect)
            # 세로 인접 체크
            if row < ROWS - 1 and grid_data[i + COLS]["is_destroyed"]:
                if not (grid_data[i]["hit_count"] >= 2 and grid_data[i+COLS]["hit_count"] >= 2):
                    ellipse_h = CELL_HEIGHT + (radius * 2)
                    ellipse_rect = pygame.Rect(cx - radius, cy - radius, radius * 2, ellipse_h)
                    pygame.draw.ellipse(screen, BROWN_GROUND_1, ellipse_rect)

        # 2회 타격 시
        for i in range(15):
            if not grid_data[i]["is_destroyed"]: continue
            row, col = i // COLS, i % COLS
            x, y = col * CELL_WIDTH + OFFSET_X, row * CELL_HEIGHT + OFFSET_Y
            cx, cy = x + CELL_WIDTH // 2, y + CELL_HEIGHT // 2
            
            # 가로 인접 체크
            if col < COLS - 1 and grid_data[i + 1]["is_destroyed"]:
                if grid_data[i]["hit_count"] >= 2 and grid_data[i+1]["hit_count"] >= 2:
                    ellipse_w = CELL_WIDTH + (radius * 2)
                    ellipse_rect = pygame.Rect(cx - radius, cy - radius, ellipse_w, radius * 2)
                    pygame.draw.ellipse(screen, BROWN_GROUND_2, ellipse_rect)
            # 세로 인접 체크
            if row < ROWS - 1 and grid_data[i + COLS]["is_destroyed"]:
                if grid_data[i]["hit_count"] >= 2 and grid_data[i+COLS]["hit_count"] >= 2:
                    ellipse_h = CELL_HEIGHT + (radius * 2)
                    ellipse_rect = pygame.Rect(cx - radius, cy - radius, radius * 2, ellipse_h)
                    pygame.draw.ellipse(screen, BROWN_GROUND_2, ellipse_rect)

        # 각 칸의 기본 1x1 원
        for i in range(15):
            if grid_data[i]["is_destroyed"]:
                row, col = i // COLS, i % COLS
                x, y = col * CELL_WIDTH + OFFSET_X, row * CELL_HEIGHT + OFFSET_Y
                color = BROWN_GROUND_2 if grid_data[i]["hit_count"] >= 2 else BROWN_GROUND_1
                pygame.draw.circle(screen, color, (x + CELL_WIDTH // 2, y + CELL_HEIGHT // 2), radius)

    # 구분선
    for row in range(ROWS):
        for col in range(COLS):
            x, y = col * CELL_WIDTH, row * CELL_HEIGHT
            draw_dashed_line(
                screen, GRAY_GROUND_PARTITION, (x + CELL_WIDTH, y), (x + CELL_WIDTH, y + CELL_HEIGHT), 2, 8)     # 수직선
            draw_dashed_line(
                screen, GRAY_GROUND_PARTITION, (x, y + CELL_HEIGHT), (x + CELL_WIDTH, y + CELL_HEIGHT), 2, 8)    # 수평선

# 그리드 데이터 업데이트
def update_grid_data(result):
    pos = result["position"]
    with data_lock:
        if result["type"] == "TARGET":
            grid_data[pos]["is_target"] = True
            grid_data[pos]["explosion_timer"] = 30    # 30fps 기준 약 1초 대기
            grid_data[pos]["explosion_frame"] = -1
        elif result["type"] == "BUNKER":
            grid_data[pos]["is_bunker"] = True
        else:
            grid_data[pos]["hint"] = result

# 이미지 및 사운드 로딩
def load_assets():
    base_path = os.path.dirname(__file__) if "__file__" in locals() else "."
    assets_dir = os.path.join(base_path, "assets")

    asset_files = {
        "CIRCLE_0": "vent.png",           # 초록 원: 환풍구
        "TRIANGLE_0": "tree.png",         # 초록 삼각형: 나무
        "CIRCLE_1": "barrels.png",        # 파란 원: 배럴
        "TRIANGLE_1": "rock.png",         # 파란 삼각형: 돌
        "CIRCLE_2": "tire_tracks.png",    # 노란 원: 타이어 자국
        "TRIANGLE_2": "crate.png"         # 노란 삼각형: 상자
    }

    scaled_assets = {}
    img_size = (int(CELL_WIDTH * 0.6), int(CELL_HEIGHT * 0.6))

    explosion_assets = []
    exp_size = (int(CELL_WIDTH * 0.9), int(CELL_HEIGHT * 0.9))

    sound_path = os.path.join(assets_dir, "explosion.mp3")
    
    # 힌트
    for key, filename in asset_files.items():
        full_path = os.path.join(assets_dir, filename)
        try:
            if os.path.exists(full_path):
                img = pygame.image.load(full_path).convert_alpha()
                if key == "CIRCLE_2":
                    target_w = int(CELL_WIDTH * 0.8)
                    aspect_ratio = 783 / 279
                    target_h = int(target_w / aspect_ratio)
                    scaled_assets[key] = pygame.transform.scale(img, (target_w, target_h))
                else:
                    scaled_assets[key] = pygame.transform.scale(img, img_size)
            else:
                print(f"힌트 이미지 파일을 찾을 수 없음: {full_path}")
        except Exception as e:
            print(f"힌트 이미지 로드 실패 ({filename}): {e}")

    # 폭발 이미지
    for i in range(7):
        exp_path = os.path.join(assets_dir, f"explosion_{i}.png")
        try:
            if os.path.exists(exp_path):
                img = pygame.image.load(exp_path).convert_alpha()
                explosion_assets.append(pygame.transform.scale(img, exp_size))
            else:
                print(f"폭발 이미지 파일을 찾을 수 없음: {exp_path}")
        except Exception as e:
            print(f"폭발 이미지 로드 실패: {e}")
    scaled_assets["EXPLOSION"] = explosion_assets

    # 폭발 사운드
    try:
        if os.path.exists(sound_path):
            scaled_assets["SOUND_EXPLOSION"] = pygame.mixer.Sound(sound_path)
        else:
            print("폭발 사운드 파일을 찾을 수 없음: explosion.mp3")
            scaled_assets["SOUND_EXPLOSION"] = None
    except Exception as e:
        print(f"폭발 사운드 로드 실패: {e}")
        scaled_assets["SOUND_EXPLOSION"] = None

    # 벙커
    bunker_path = os.path.join(assets_dir, "bunker.png")
    try:
        if os.path.exists(bunker_path):
            b_img = pygame.image.load(bunker_path).convert_alpha()
            scaled_assets["BUNKER"] = pygame.transform.scale(b_img, (int(CELL_WIDTH * 0.7), int(CELL_HEIGHT * 0.7)))
    except Exception as e:
            print(f"벙커 이미지 로드 실패: {e}")

    return scaled_assets

assets = load_assets()

# 힌트, 타겟팅 지점, 벙커 그리기
def draw_object(position, data_node):
    row, col = position // COLS, position % COLS
    cx = col * CELL_WIDTH + CELL_WIDTH // 2 + OFFSET_X
    cy = row * CELL_HEIGHT + CELL_HEIGHT // 2 + OFFSET_Y
    
    # 폭발
    if data_node["explosion_frame"] >= 0:
        exp_list = assets.get("EXPLOSION", [])
        if data_node["explosion_frame"] < len(exp_list):
            img = exp_list[data_node["explosion_frame"]]
            screen.blit(img, img.get_rect(center=(cx, cy)))
        return

    # 벙커/힌트
    if data_node["is_bunker"]:
        if "BUNKER" in assets:
            screen.blit(assets["BUNKER"], assets["BUNKER"].get_rect(center=(cx, cy)))
    elif data_node["hint"]:
        h = data_node["hint"]
        key = f"{'CIRCLE' if h['shape_idx'] == 0 else 'TRIANGLE'}_{h['color_idx']}"
        if key in assets:
            screen.blit(assets[key], assets[key].get_rect(center=(cx, cy)))

    # 타겟
    if data_node["is_target"]:
        ts = int(CELL_HEIGHT // 5)
        pygame.draw.circle(screen, RED_TARGET, (cx, cy), ts, 6)
        pygame.draw.line(screen, RED_TARGET, (cx - ts - 10, cy), (cx + ts + 10, cy), 6)
        pygame.draw.line(screen, RED_TARGET, (cx, cy - ts - 10), (cx, cy + ts + 10), 6)
        pygame.draw.circle(screen, RED_TARGET, (cx, cy), 8)

def main():
    thread = threading.Thread(target=data_receiver, daemon=True)
    thread.start()
    clock = pygame.time.Clock()

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit(); sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit(); sys.exit()
            
            # 시뮬레이션용 키보드 입력
            if event.type == pygame.KEYDOWN:
                dummy_byte = 0
                if   event.key == pygame.K_1: dummy_byte = 0x01    # 원, 초록, 1번 칸 (00_00_0001)
                elif event.key == pygame.K_2: dummy_byte = 0x52    # 삼각형, 파랑, 2번 칸 (01_01_0010)
                elif event.key == pygame.K_3: dummy_byte = 0x23    # 원, 노랑, 3번 칸 (00_10_0011)
                elif event.key == pygame.K_4: dummy_byte = 0xF3    # 타겟, 3번 칸 (1111_0011)
                elif event.key == pygame.K_5: dummy_byte = 0x43    # 삼각형, 초록, 3번 칸 (01_00_0011)
                elif event.key == pygame.K_6: dummy_byte = 0xF4    # 타겟, 4번 칸 (1111_0100)
                elif event.key == pygame.K_7: dummy_byte = 0xF8    # 타겟, 8번 칸 (1111_1000)
                elif event.key == pygame.K_8: dummy_byte = 0xF7    # 타겟, 7번 칸 (1111_0111)
                elif event.key == pygame.K_9: dummy_byte = 0xF2    # 타겟, 2번 칸 (1111_0010)
                elif event.key == pygame.K_0: dummy_byte = 0xF9    # 타겟, 9번 칸 (1111_1001)
                elif event.key == pygame.K_q: dummy_byte = 0xF7    # 타겟, 7번 칸 (1111_0111)
                elif event.key == pygame.K_w: dummy_byte = 0xF2    # 타겟, 2번 칸 (1111_0010)
                elif event.key == pygame.K_e: dummy_byte = 0xF6    # 타겟, 6번 칸 (1111_0110)
                elif event.key == pygame.K_r: dummy_byte = 0xF1    # 타겟, 1번 칸 (1111_0001)
                elif event.key == pygame.K_t: dummy_byte = 0xF6    # 타겟, 6번 칸 (1111_0110)
                elif event.key == pygame.K_y: dummy_byte = 0xFC    # 타겟, 12번 칸 (1111_1100)
                elif event.key == pygame.K_u: dummy_byte = 0xFB    # 타겟, 11번 칸 (1111_1011)
                elif event.key == pygame.K_i: dummy_byte = 0xCB    # 벙커, 11번 칸 (1100_1011)
                
                if dummy_byte != 0:
                    result = decode_data(dummy_byte)
                    update_grid_data(result)

        # 배경색 & 격자 렌더링
        screen.fill((0, 0, 0))
        draw_grid()

        # 데이터가 있는 칸 렌더링 및 애니메이션 로직
        with data_lock:
            for i in range(15):
                # 힌트 및 타겟 데이터 렌더링
                if grid_data[i]["hint"] or grid_data[i]["is_target"] or grid_data[i]["explosion_frame"] >= 0 or grid_data[i]["is_bunker"]:
                    draw_object(i, grid_data[i])

                # 폭발 애니메이션 타이머 및 프레임 업데이트 & 사운드 재생
                if grid_data[i]["is_target"]:
                    if grid_data[i]["explosion_timer"] > 0:
                        grid_data[i]["explosion_timer"] -= 1
                        if grid_data[i]["explosion_timer"] == 0:
                            grid_data[i]["explosion_frame"] = 0
                            if assets["SOUND_EXPLOSION"]:
                                assets["SOUND_EXPLOSION"].play()
                    
                    elif grid_data[i]["explosion_frame"] >= 0:
                        if pygame.time.get_ticks() % 3 == 0:
                            grid_data[i]["explosion_frame"] += 1
                            if grid_data[i]["explosion_frame"] >= 7:
                                grid_data[i].update(
                                    {"is_target": False, "explosion_frame": -1, "hint": None,
                                     "is_bunker": False, "is_destroyed": True})
                                grid_data[i]["hit_count"] += 1

        # 카메라 베젤 그리기
        draw_bezel()

        pygame.display.flip()
        clock.tick(30)

if __name__ == "__main__":
    main()
