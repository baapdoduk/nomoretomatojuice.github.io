# NMTJ 공통 게임플레이 프레임워크 (Godot 4)

2D 리니어 어드벤처용 공통 시스템(이동·탐험, 전투·보스, 퍼즐, 공통 인프라)입니다.
실제 스토리·챕터·아트는 범위 밖이며, 모든 그래픽은 임시 도형(Polygon2D / `_draw`)입니다.

- 엔진: **Godot 4.7.2 stable** (헤드리스 테스트 검증 버전). GDScript만 사용, 외부 애드온 없음.
- 프로젝트 위치: 저장소의 `game/` 폴더 (저장소 루트의 Nuxt 웹사이트와 무관).
- 기준 해상도 640×360 (창 1280×720, `canvas_items` 스트레치), 물리 60Hz, GL Compatibility 렌더러.
- 상세 설계/모듈 경계: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · 구현 현황/테스트 결과: [`docs/STATUS.md`](docs/STATUS.md) · 실기 체크리스트: [`docs/HARDWARE_CHECKLIST.md`](docs/HARDWARE_CHECKLIST.md)

---

## 1. 실행 방법

1. Godot 4.7.x를 설치하고 `game/project.godot`을 엽니다. (다른 4.x 버전이라면 아래 "버전 주의" 참고)
2. **F5** → 메인 씬 `scenes/tests/test_hub.tscn`(테스트 허브)이 실행됩니다.
3. 허브에서 Lab을 선택합니다. 어느 Lab에서든 **Esc / Options → Return to hub**로 돌아옵니다.
4. 개별 Lab은 해당 씬을 열고 **F6**으로 바로 실행할 수도 있습니다.

| Lab | 씬 | 확인 내용 |
|---|---|---|
| Controller Lab | `scenes/tests/controller_lab.tscn` | 버튼 원시 인덱스·DS4 이름, 스틱/데드존, L2/R2 아날로그, 진동 약/강, 라이트바, 자이로/가속도, 터치패드 클릭, 지원표 |
| Side-View Lab | `scenes/tests/side_view_lab.tscn` | 점프(코요테/버퍼/가변 높이), 대시, 일방향 발판, 낙사→체크포인트, 수집품·팝업·열쇠 문, 컨텍스트 액션 5종 |
| Top-Down Lab | `scenes/tests/top_down_lab.tscn` | 8방향 이동, 대시, 랜드마크, 일방향 문(지름길), 횡스크롤 Lab과 왕복(아이템/플래그 유지) |
| Combat Lab | `scenes/tests/combat_lab.tscn` | 허수아비, 테스트 보스(예고→공격→회복), 사망/재시작, 승리 출구, 모구모구 병 보스 프로토타입 |
| Puzzle Lab | `scenes/tests/puzzle_lab*.tscn` | 거울 1/3개·장애물·순환, 스위치/게이트, 연쇄 작동·지름길·루프백, 수위 전환, 평행세계, 리셋 |
| Integration | `scenes/tests/integration_overworld.tscn` ↔ `integration_interior.tscn` | 전 모듈 통합 경로(탑다운↔횡스크롤, 열쇠 게이트, 빛 퍼즐, 보스, 지름길) |

> 버전 주의: 4.7 미만에서 열면 `config/features` 경고가 뜰 수 있습니다. 스크립트는 4.4+ 문법만 사용하며, 라이트바/모션 센서 API는 `has_method` 검사 후 호출하므로 없는 버전에서도 실행됩니다.

## 2. 입력 매핑

| Action | DS4 | 키보드 | 비고 |
|---|---|---|---|
| `move_*` | 왼쪽 스틱 / D-pad | WASD / 방향키 | 데드존 0.2 (일시정지 메뉴 Settings에서 조정) |
| `jump` | ✕ (Cross) | Space | 탑다운에서는 기본 비활성 |
| `dash` | ○ (Circle) | Shift | 컨텍스트 액션 취소에도 사용 |
| `attack` | □ (Square) | J | |
| `interact` | △ (Triangle) | E | |
| `context_left/right` | L2 / R2 (아날로그) | Q / R | 트리거 깊이 입력 |
| `pause` | Options | Esc | |
| `ui_accept / ui_cancel` | ✕ / ○ | Enter·Space / Esc | 메뉴 조작 |

- Input Map은 `project.godot`에 있으며 에디터(Project Settings > Input Map)에서 수정하거나 `godot --headless --path game --script res://tools/gen_input_map.gd`로 재생성합니다.
- 패드 인덱스는 Godot의 SDL 표준 레이아웃(A=✕, B=○, X=□, Y=△, START=Options)입니다. **실제 장치의 매핑은 Controller Lab에서 버튼을 눌러 직접 확인**하세요.
- 상호작용 프롬프트는 마지막 입력 장치에 따라 DS4 기호(△ 등, 폰트 없이 도형으로 그림) 또는 키 이름(E)으로 바뀝니다.

## 3. 테스트

```bash
cd game
./tools/run_tests.sh            # import → 모든 스크립트/씬 로드 검사 → 전체 테스트 (헤드리스, --fixed-fps 60)
./tools/run_tests.sh light      # 파일/메서드 이름 필터
GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tools/run_tests.sh   # macOS (godot가 PATH에 없을 때)
```

- 테스트는 `tests/{unit,integration,smoke}/test_*.gd` (`TestCase` 상속, 외부 의존성 없음). 러너는 Logger로 엔진/스크립트 에러를 수집해 **에러가 난 테스트를 실패 처리**합니다.
- 스모크 테스트는 `scenes/tests/*.tscn`의 모든 Lab을 자동으로 찾아 3초간 입력을 주입하고 에러 여부를 확인합니다(새 Lab 추가 시 자동 포함).
- 로그: `game/.godot/test_logs/{import,check,tests}.log`
- 화면 캡처(레이아웃 확인용): `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 res://tools/capture_screens.tscn -- --out=/abs/dir` → 모든 Lab 스크린샷. 저장된 결과: [`docs/screenshots/`](docs/screenshots/)
- 자동 테스트는 로직만 검증합니다. **화면 표시, 실제 DS4 조작감·진동·라이트바·센서, macOS 동작은 사용자 실기 확인 항목**입니다 → `docs/HARDWARE_CHECKLIST.md`.

## 4. 디렉터리 구조

```
scenes/core/{autoload,player,interaction,ui,level}  재사용 코어 씬
scenes/combat/   보스, 공격 영역, 투사체, 허수아비, 아레나
scenes/puzzles/  거울, 발광기, 수신기, 스위치, 압력판, 상자, 게이트, 상태 전환 장치
scenes/tests/    테스트 허브와 Lab (회귀 테스트용으로 유지)
scripts/...      위 씬의 스크립트 (같은 트리 구조)
scripts/resources/  Resource 클래스 (PlayerConfig, ItemData, AttackPattern, BossConfig, BossPhase, PuzzleConfig)
resources/{player,items,combat,puzzles}/  튜닝 데이터 .tres
tests/           자동 테스트, tools/ 검증 스크립트, docs/ 문서
```

Autoload는 3개뿐입니다: `GameState`(체력·아이템·플래그·체크포인트·설정·저장), `SceneRouter`(전환·스폰·리스폰), `InputFeedback`(패드 연결·진동·버튼 표시, 일시정지 메뉴 포함).

## 5. 콘텐츠 제작 가이드 (코어 코드 수정 없이)

### 5.1 새 레벨(챕터 맵)
1. 새 씬(Node2D 루트)을 만들고 다음을 인스턴스합니다.
   - `scenes/core/player/player.tscn` → Inspector에서 `movement_mode`(SIDE_VIEW / TOP_DOWN), `config`(PlayerConfig) 지정
   - `scenes/core/ui/hud.tscn`
   - `scenes/core/interaction/spawn_point.tscn` (`spawn_id = start`, `is_default = true`) + 도착 지점마다 `from_<이전씬>` 스폰
   - `scenes/core/interaction/checkpoint.tscn` (입구·보스 직전 등)
2. 지형: `scenes/core/level/solid_block.tscn`, `one_way_platform.tscn` 또는 TileMapLayer(물리 레이어 1 World). 배경은 `parallax_background.tscn`, 카메라 제한은 `camera_bounds.tscn`.
3. 씬 연결: `scene_door.tscn`(상호작용) / `scene_exit.tscn`(접촉)에 `target_scene`, `target_spawn_id` 지정.
4. 지름길/루프백: `one_way_door.tscn`(`open_side`, `open_flag`) — 반대편에서만 열리고 열린 상태가 저장됩니다.
5. 목적지 사전 노출: `landmark.tscn`.
6. 챕터 시작점 지정: 진입 코드에서 `GameState.begin_chapter(&"chapter_id", scene_path, &"start")` 호출 → 일시정지 메뉴의 "Restart chapter"가 이 지점으로 복귀합니다.

### 5.2 아이템
1. `resources/items/`에 새 `ItemData` 리소스 생성: `id`(고유), `display_name`, `description`, `icon`(Texture2D), `type`(MEMORY / PROGRESSION / CONSUMABLE), `max_stack`, `required_flags`.
2. 맵에 `pickup.tscn`을 놓고 `item`에 지정. `auto_collect`(접촉/상호작용), MEMORY 아이템은 `popup_for_memory`로 사진 팝업.
3. 사용처: `locked_door.tscn` / `item_use_interactable.tscn`(`required_item`, `consume_required_item`, `success_flag`) 또는 퍼즐 `Gate`의 `required_items`.
4. 중복 수집은 `GameState.add_item`이 차단하고, 이미 가진 아이템의 픽업은 씬 재진입 시 자동으로 숨겨집니다. 소비형 아이템 픽업은 `collected_flag`를 지정하세요.

### 5.3 팝업 / 대화 / 컨텍스트 액션
- 사진·대화: `popup_interactable.tscn` (`title`, `body`, `image`, `read_flag`). 열려 있는 동안 이동이 잠깁니다.
- 컨텍스트 액션: `context_action.tscn` — `action_type` PRESS / HOLD / MASH / STICK_DIRECTION / TRIGGER_DEPTH, `time_limit = 0`(기본, 시간제한 없음), `success_flag`. 설정의 *Assist context actions*를 켜면 연타·트리거가 단순 홀드로 바뀝니다. 완료 시 퍼즐 입력 규약(`activated_changed`)도 만족하므로 게이트에 직접 연결할 수 있습니다.

### 5.4 공격 패턴과 보스
1. **패턴**: `resources/combat/`에 `AttackPattern` 생성 — `shape`(CIRCLE / CONE / LINE)와 크기, `origin`(SELF / TARGET) + `origin_offset`, `aim`(TOWARD_TARGET / FIXED_ANGLE / ROTATING), `telegraph_time`(기본 1.6s), `active_time`, `recovery_time`(기본 3.5s), `damage`, 투사체(`projectile_speed` > 0이면 발사형, `projectile_count`, `spread`), `repeat_count`/`repeat_interval`(0.35s)/반복 배치 방식. 바닥 예고와 피해 판정은 같은 다각형을 쓰므로 항상 일치합니다.
2. **페이즈**: `BossPhase` — `health_threshold`(체력 비율), `patterns`, 순서(SEQUENTIAL / RANDOM), `idle_time`, `recovery_time_override`. 페이즈 수는 자유입니다.
3. **보스 설정**: `BossConfig` — `max_health`, `phases`, 상태별 무적(`invulnerable_during_idle/telegraph/attack`; 회복 중에는 항상 공격 가능), 접촉 피해, `defeated_flag`, 처치 후 동작(KEEP / HIDE / FREE), 이미 처치된 경우(START_DEFEATED / REMOVE).
4. **씬**: `scenes/combat/boss.tscn`을 인스턴스하고 `config` 지정. 외형은 `Visual` 노드(BossVisual: ORB / BOTTLE 임시 스타일)를 Sprite2D/AnimatedSprite2D로 교체. 전투 시작은 `wait_for_trigger` + `BossFightTrigger` 영역. 승리 출구는 `Gate.required_flags = [defeated_flag]`.
5. 예시: `test_boss.tres`(3페이즈), `mogu_bottle_prototype.tres` + `mogu_bottle_boss.tscn`(병이 보스·노란 고양이 내부, 나타데코코 투사체 → 회복 → 칼 반격, **임시** — 실제 페이즈 수 미확정).
6. 타격 연출 훅: `HitFeedback` 노드(`health`/`hitbox` 연결 → 플래시, 효과음 노드, 진동 프리셋).

### 5.5 퍼즐
- **입력 규약**: `activated_changed(bool)` 신호 + `is_active()`를 가진 노드(스위치, 압력판, 수신기, 컨트롤러, 아이템 사용 지점, 컨텍스트 액션…)는 무엇이든 출력 장치의 입력이 될 수 있습니다. Inspector에서 `inputs`/`devices` 배열에 드래그해 연결합니다.
- **스위치** `switch.tscn`(TOGGLE / MOMENTARY / LATCH), **압력판** `pressure_plate.tscn`(플레이어·`pushable`), **상자** `push_box.tscn`(격자 밀기).
- **게이트** `gate.tscn`: `inputs` + `logic`(ALL / ANY) + `invert`, `latch_open`, `required_items`/`required_flags`, `open_flag`(영구). 플레이어가 아래에 있으면 닫힘을 미룹니다.
- **퍼즐 컨트롤러** `puzzle_controller.tscn`: `devices`, `mode`, `solved_flag`(재진입 시 해결 상태 유지), `success_player`(효과음), `hint_text`/`hint_delay`(60s). 컨트롤러끼리 연쇄 가능.
- **빛 반사**: `light_emitter.tscn`(+X 방향 발사, `power_inputs`), `mirror.tscn`(상호작용 시 90° 회전, `rotation_step_degrees = 45` 가능), `light_receiver.tscn`(`latch`). 여러 수신기 AND → 컨트롤러 → 게이트. 최대 반사 12회·순환 감지·epsilon은 `resources/puzzles/default_puzzle_config.tres`.
- **상태 전환(수위/전력)**: `state_driven.tscn`(`state_flag`, `active_values` → 표시+충돌 동시 전환) + `state_lever.tscn`(값 변경 전 플레이어/상자 갇힘 검사, 막히면 거부·안내). 평행세계는 `parallel_world_switch.tscn` + 레이어별 `state_driven`.
- **리셋**: `reset_lever.tscn`(`targets`)으로 언제든 초기화.

### 5.6 상태 저장 정책
- 씬을 다시 들어와도 유지되어야 하는 것은 모두 `GameState` 플래그/아이템에 기록됩니다(`persist_flag`, `solved_flag`, `open_flag`, `defeated_flag`, `collected_flag`). 플래그가 없는 장치는 씬 재로드 시 초기화됩니다.
- 체크포인트는 씬·스폰·체력·아이템·플래그(퍼즐 진행) 스냅샷이며, 사망 시 아이템과 월드 플래그가 함께 복원되어 중복/소실이 없습니다.
- 디스크 저장(P1): `GameState.save_to_disk()` / `load_from_disk()` → `user://save_slot_0.json` (`version` 필드 포함). `autosave_on_checkpoint` 설정으로 체크포인트 자동 저장.

## 6. 에셋 교체 방법
- 게임 로직은 에셋 경로를 하드코딩하지 않습니다. 각 씬의 `Visual` 노드(임시 도형)를 Sprite2D / AnimatedSprite2D로 교체하고, 필요하면 Player의 `state_changed`, `facing_changed`, `attacked`, `hurt` 등의 신호에 연결합니다.
- 아이템 아이콘: `ItemData.icon`. HUD 하트: `HeartsDisplay.full_texture/empty_texture`. 버튼 아이콘: `ButtonGlyph.joypad_textures`(키: "Triangle", "Cross", "L2" …) / `keyboard_texture`.
- 효과음: `PuzzleController.success_player`, `HitFeedback`의 사운드 노드 등 export된 AudioStreamPlayer에 스트림 지정.
- 튜닝: `resources/player/default_player_config.tres`(이동 180, 중력 1200, 점프 420, 코요테/버퍼 0.12, 대시 0.18/쿨다운 0.7, 피격 무적 1.0 …), 공격 패턴/보스/퍼즐 `.tres`.

## 7. 모듈 경계와 검증 명령 (리뷰어용)
| 모듈 | 경로 | 주요 테스트 |
|---|---|---|
| Core/Architect | `scripts/core/{game_state,scene_router,input_feedback,layers}.gd`, `scripts/combat/{health,hurtbox,hitbox,damage_event}.gd`, `interactable.gd`, `puzzle_device.gd`, `tests/test_*.gd`, `tools/` | `tests/unit/test_core_state.gd`, `tests/integration/test_router_core.gd` |
| A Exploration | `scripts/core/{player,interaction,level}/` | `test_player_*`, `test_exploration_*`, `test_integration_*` |
| B Combat | `scripts/combat/`, `scripts/resources/{attack_pattern,boss_*}.gd` | `test_combat_*` |
| C Puzzles | `scripts/puzzles/` | `test_light_*`, `test_puzzle_*` |
| D UI | `scripts/core/ui/`, `scripts/tests/{test_hub,controller_lab}.gd` | `test_ui_*`, `tests/smoke/` |

검증: `cd game && ./tools/run_tests.sh` (종료 코드 0 = 전부 통과).

## 8. 미구현 / 범위 외 / 실기 확인 필요
`docs/STATUS.md`에 요구사항별 상태(완료 / 부분 / 미구현)와 알려진 이슈를, `docs/HARDWARE_CHECKLIST.md`에 사용자가 직접 확인해야 할 DS4·macOS 항목을 정리했습니다.
