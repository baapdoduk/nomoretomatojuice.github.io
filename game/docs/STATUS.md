# 구현 현황 · 테스트 결과 · 알려진 이슈

기준: `game_core_spec.md`(기능 요구사항). 상태 표기: ✅ 구현+자동 테스트 검증 · 🟡 구현됨, 일부만 자동 검증 / 실기 확인 필요 · ⬜ 미구현(범위 외 또는 후속).
"검증"은 헤드리스 자동 테스트 기준입니다. **화면 표시와 DS4/macOS 실기 동작은 자동 테스트로 증명되지 않으며** `HARDWARE_CHECKLIST.md`로 사용자가 확인해야 합니다.

## 1. 테스트 결과 요약

- 명령: `cd game && ./tools/run_tests.sh` (Godot 4.7.2, 헤드리스, `--fixed-fps 60`)
- 결과: **TEST_TOTAL_PLACEHOLDER**
- 로드 검사: 프로젝트의 모든 `.gd/.tscn/.tres` 로드 성공 (CHECK_PLACEHOLDER)
- 러너는 테스트 중 발생한 엔진/스크립트 에러를 Logger로 수집해 해당 테스트를 실패 처리합니다.
- 스모크 테스트: `scenes/tests/*.tscn` 전 Lab을 SceneRouter로 로드 → 3초 입력 주입 → 일시정지 열고 닫기 → 허브 복귀.
- 검증 불가 환경: 컨테이너에 디스플레이·게임패드가 없음 → GUI 렌더링, 실제 패드 입력/진동/라이트바/센서, 블루투스/USB 연결 해제, macOS 실행은 미검증.

## 2. 요구사항별 상태

### 3. 컨트롤러 및 공통 입력 (P0)
| 요구사항 | 상태 | 근거 |
|---|---|---|
| Input Map 기반 액션(move/jump/dash/attack/interact/context/pause), DS4+키보드 | ✅ | `project.godot`, `tools/gen_input_map.gd`; 메뉴용 ✕/○ 추가 |
| 버튼 인덱스 실기 확인 | 🟡 | Controller Lab에 원시 인덱스 표시. 실제 확인은 사용자 |
| 스틱 데드존 0.2, 설정 가능 | ✅ | `InputFeedback.set_stick_deadzone`, 일시정지 메뉴 슬라이더 |
| 연결 해제 시 일시정지 + 재연결 안내 | ✅(로직) 🟡(실기) | PauseMenu disconnect 모드, `test_ui_pause.gd` |
| Controller Lab(버튼/축/트리거/장치명/연결/진동 약·강) | ✅(로직) 🟡(실기) | `controller_lab.tscn`, `test_ui_controller_lab.gd` |
| 터치패드/자이로/가속도/라이트바 지원표 | 🟡 | API 존재 확인(4.7.2): 라이트바·모션 센서 있음, **터치패드 좌표 API 없음(클릭만)**. 장치 지원·macOS 실기 확인은 체크리스트 |
| 미지원 기능을 기본 진행에 사용 안 함 | ✅ | 모든 확장 API는 `has_method`/지원 여부 확인 후 호출, 진행 경로에 미사용 |
| 진동: 전환/일시정지/연결 해제 시 정지, 미지원 시 무음 실패 | ✅(로직) 🟡(실기) | `InputFeedback.stop_all_rumble` 호출 경로 테스트 |
| DS4 기호 프롬프트 | ✅ | `ButtonGlyph`(도형으로 직접 그림) + `InteractionPrompt` |
| 컨텍스트 액션(누르기/길게/연타/스틱/트리거 깊이), 시간제한 없음 + 보조 | ✅ | `ContextActionInteractable`, `test_exploration_context_actions.gd` |
| 내장 스피커 | ⬜ | 범위 제외(명세) |

### 4. 이동 및 탐험 (P0)
| 요구사항 | 상태 | 근거 |
|---|---|---|
| 횡스크롤: 이동/중력/점프/대시, 코요테·버퍼·가변 점프 | ✅ | `SideViewMotor`, `test_player_side_view.gd`(정점 v²/2g, 코요테 창, 버퍼, 짧은 점프) |
| 탑다운: 8방향(대각선 정규화), 대시, 점프 기본 비활성 | ✅ | `TopDownMotor`, `test_player_top_down.gd` |
| 두 시점에서 공격/상호작용 유지, 모터 분리·상태 중복 없음 | ✅ | Player 공통 컴포넌트 + 모터 2종 |
| 튜닝값 Inspector 조정(180/1200/420/0.12/0.18/0.7) | ✅ | `resources/player/default_player_config.tres` |
| Interactable: 프롬프트, 최근접 1개, 이동 잠금 옵션 | ✅ | `Interactor`, `test_player_interactor.gd` |
| 문/스위치/수집품/팝업/아이템 사용 동일 인터페이스 | ✅ | 모두 `Interactable` 기반 |
| ItemData(id/이름/아이콘/설명/유형/필요 플래그), 중복 방지 | ✅ | `ItemData`, `GameState.add_item` |
| Gate: 아이템/플래그 조건 개방 | ✅ | `Gate.required_items/required_flags` |
| Checkpoint 스냅샷(씬/스폰/체력/아이템/퍼즐), 아이템 중복·소실 금지 | ✅ | `GameState.make_snapshot/restore_snapshot`, `test_router_core.gd`, `test_progress_commit.gd` |
| 마지막 체크포인트 이후 마일스톤 보존(보스/퍼즐/지름길/열쇠) | ✅ | `GameState.commit_progress` (자문 반영 정책) |
| 챕터 재시작 | ✅ | `GameState.begin_chapter` + 일시정지 메뉴 |
| 로컬 저장(P1, JSON+version, user://) | ✅(API) | `save_to_disk/load_from_disk`; 타이틀 "이어하기" UI는 후속 |
| SceneRouter: fade→load→spawn→fade, 전환 중 입력 차단 | ✅ | 전환 중 트리 일시정지, `test_router_core.gd` |
| 탑다운↔횡스크롤 전환 | ✅ | `test_exploration_transitions.gd`, 통합 슬라이스 |
| 레벨 도구: 일방향 문/지름길, 조건부 게이트, 랜드마크, 배경 레이어 | ✅ | `OneWayDoor`, `Gate`, `Landmark`, `parallax_background.tscn` |
| 실제 챕터 연결/귀환 맵 | ⬜ | 후속 작업(명세) |

### 5. 전투 (P0)
| 요구사항 | 상태 | 근거 |
|---|---|---|
| Health/Hurtbox/Hitbox/DamageEvent 공통 | ✅ | `scripts/combat/` |
| 근접 칼 공격, 대시 회피, 피격 무적, 넉백 | ✅ | `PlayerMelee`, `test_player_combat.gd`, `test_combat_lab.gd`(대시 i-frame) |
| 한 공격이 같은 대상에 중복 피해 없음 | ✅ | `Hitbox.activate()` 대상 등록 |
| 보스 상태 머신 Idle→Telegraph→Attack→Recovery, Defeated | ✅ | `Boss`, `test_combat_boss.gd`(타이밍 1프레임 이내) |
| Recovery 중 공격 가능, 공격 중 무적 설정 | ✅ | `BossConfig.invulnerable_during_*` |
| 예고와 판정 분리, 바닥 표시=판정 좌표/범위 | ✅ | `AttackShape` 단일 다각형, 투사체는 경로 레인 |
| AttackPattern(shape/위치/방향/예고/활성/피해/속도/반복/회복) | ✅ | `AttackPattern` 리소스 |
| P0 패턴: 원형 낙하, 부채꼴/직선 발사, 순차 낙하 | ✅ | `resources/combat/*.tres` |
| 안전지대 패턴(P1) | 🟡 | 원형/직선 조합으로 구성 가능, 전용 프리셋 없음 |
| 투사체 화면 밖/수명 종료 제거 | ✅(수명) 🟡(화면 밖) | 헤드리스에서는 VisibleOnScreenNotifier가 동작하지 않아 신호 연결만 검증 |
| 모구모구 최종 보스 재사용 구조(병 보스, 나타데코코) | 🟡 | `mogu_bottle_prototype.tres` 임시 — 실제 스프라이트/페이즈 수는 후속 |
| 실패 시 보스 직전 재시작 | ✅ | 아레나 앞 Checkpoint, `test_combat_lab.gd` |
| 반복 실패 시 예고/회복 완화(P1) | ✅ | 3회 사망 시 안내 + `assist_combat_timing`(×1.35) |
| 접근성: 색 외 윤곽/채움, 공격 가능 상태 표시 | ✅(로직) 🟡(시각) | Telegraph 채움/펄스, 보스 방패/코어 모양 |
| 진동/플래시/효과음 훅 | ✅ | `HitFeedback`, `InputFeedback.rumble_preset` |

### 6. 퍼즐 (P0)
| 요구사항 | 상태 | 근거 |
|---|---|---|
| PuzzleController(상태/완료/reset/solved), 신호 기반 | ✅ | `PuzzleController`, `test_puzzle_gate_controller.gd` |
| Switch toggle/momentary/latch, Gate AND/OR, PressurePlate | ✅ | `test_puzzle_devices.gd` |
| 상자(P1, 한 방식) | ✅ | 격자 밀기 `PushBox` |
| 빛 반사: Emitter/Mirror/Receiver 독립 씬, 90°(45°) 회전 | ✅ | `scenes/puzzles/` |
| 최대 반사 12, 순환 감지, epsilon, Line2D | ✅ | `LightTracer`, `test_light_tracing.gd` |
| 장치 변경 시 재계산(움직이는 장애물 별도) | ✅ | `notify_changed` + `continuous_update` |
| 복수 수신기 AND, 래치, 완료 시 문+성공음 훅 | ✅ | `test_puzzle_light_door.gd` |
| 테스트: 거울 1/3개, 장애물, 순환 | ✅ | Puzzle Lab + 단위 테스트 |
| 상태 전환(수위/전력) 시각+충돌 동시, 갇힘 방지 | ✅ | `StateDriven`/`StateLever`, `test_puzzle_state.gd` |
| 연쇄 작동 A→B→C→최종 문, 목적지 사전 노출, 지름길, 루프백 | ✅ | Puzzle Lab (e), 통합 슬라이스 |
| 평행세계(P1) | ✅ | `ParallelWorldSwitch`, `test_puzzle_lab_world.gd` |
| 언제든 리셋, 소프트락 금지 | ✅ | `ResetLever`, 게이트 닫힘 지연, 상태 전환 거부 |
| 60초 힌트(P1) | ✅ | `PuzzleController.hint_text/hint_delay` |

### 8. 완료 기준
| 항목 | 상태 |
|---|---|
| 허브에서 모든 Lab 진입/복귀 | ✅ (`test_ui_hub.gd`, 스모크) |
| 횡스크롤↔탑다운 전환 시 아이템/플래그 유지 | ✅ |
| 키보드로 필수 기능 완주 | ✅(스크립트 주행 테스트) 🟡(사람이 직접 플레이는 미실시) |
| 실제 DS4 이동/공격/상호작용/일시정지/진동 | 🟡 사용자 실기 확인 필요 |
| 전투: 예고=판정, 회피 후 반격, 처치, 사망/재시작 | ✅ |
| 퍼즐: 반사 성공/실패/리셋, 순환 안전, 상태 전환, 지름길 | ✅ |
| 씬 재진입 상태 정책 일관성 | ✅ (ARCHITECTURE §6, 재진입 테스트) |
| README(실행/입력/테스트/생성법/에셋 교체/미구현/실기) | ✅ |

## 3. 알려진 이슈 / 제한
KNOWN_ISSUES_PLACEHOLDER

## 4. 후속 작업 제안
- 실제 스프라이트/애니메이션/사운드로 `Visual` 노드 교체, 실제 챕터 맵 제작(코어 수정 없이 씬 조합).
- 타이틀 화면의 "이어하기"(`GameState.load_from_disk` → `SceneRouter.respawn_at_checkpoint`) UI.
- 실기 체크리스트 결과에 따라 DS4 매핑/진동 세기/데드존 기본값 조정.
- 모구모구 보스 실제 페이즈 설계 후 `BossPhase` 추가.
