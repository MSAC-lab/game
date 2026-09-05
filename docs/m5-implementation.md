# M5 구현과 실행 검증

## 판정

**IMPLEMENTED / REVIEW DRAFT / HOLD.** Schema 5와 M5 실행 경로를 구현했다. 결정 26의 정본 FCAL은 27일 종료에서 기존 건강 커널의 사망 미구현 경계에 도달한다. 따라서 전체 M5와 D26-R02를 PASS로 판정할 수 없다.

승인된 세 설계 파일·기존 M4 수치 규칙·건강 알고리즘은 보존했다. [정본 채택 기록](decisions/README.md), [실행 evidence](evidence/m5-runtime-evidence.json), [보정 제안](decisions/m5-fcal-proposal.json)을 함께 검토한다. 실행 evidence는 관측 출력이며 새 golden oracle이 아니다.

## 구현 경계

- 기본 `WorldState`는 Schema 4를 유지한다. Schema 5는 여섯 ruleset component와 승인된 추가 모델·링크를 명시적으로 선언한 세계만 허용한다. 자동 migration은 없다.
- 공개 진입점은 `M5Facade.execute_decisions_v1`, `process_contacts_v1`, `close_day_v1`이다. 입력 stamp의 상태 해시·날짜·social revision과 행동 → 접촉 → 하루 종료 순서를 검사한다.
- 기존 M3 판단과 M4 수치 커널을 native Schema 5 payload에 결속한다. 중간 해시는 별도 domain이며, 내부 scope는 살아 있는 호출 소유자·원본 snapshot·등록된 clone을 확인한다. 이 scope는 프로세스 내부 호출 계약이며 외부 코드 실행을 격리하는 sandbox가 아니다.
- M4 행동 결과를 당사자 경험·유효 seed 소유자의 목격·객관적 흔적으로 투영한다. 일반 접촉은 시작 snapshot에서만 전언을 골라 비밀·신뢰도·깊이·방향당 상한을 적용한다.
- 최초 수용 영수증으로 학습·관계·감정·규범 압력·기억을 한 번만 적용한다. 관계·감정은 snapshot에서 계획한 delta를 합산한 뒤 clamp한다. 기존 기억의 과거 사건·습득일을 보존하면서 현재 믿음을 갱신한다.
- 하루 종료에는 기존 소비·hunger·health 처리 뒤 감정 감쇠, 주간 ±2 성향 정리, 기억 8/24/64 상한, 반복 날짜 정리를 수행한다. 사회적 해석이 물리 상태를 바꾸면 전체 작업을 거부한다.
- Schema 5 저장은 정수 토큰·중복 JSON 키·exact 필드·참조·manifest·state hash와 제공된 감사 로그를 검증한다. 감사 로그가 비어 있어도 미래 상태는 동일하게 재개한다.

M6 자동 일정·60명 실행·새 UI·사망 처리는 이 구현에 포함되지 않는다.

## 실행 확인 항목

Godot 4.7.2 Standard에서 다음을 실행했다. 지원 검증의 전체 횟수와 결과는 evidence의 `checks`, `failures`에 기록한다. `M5 HOLD`는 지원 assertion 실패와 별개의 정본 충돌이다.

| 계약 | 실행 근거 |
|---|---|
| M5-T01·T17·D26-R01 | 초기 hash, B01 native A04 이후 전체 payload·exact save, FAR-00~06 전체 실패 결과, 중간 상태의 공개·저장·M3 거부, stage 오염·후반 실패 rollback |
| B01 보강 | 과거 기억 0일 → 새 A04 1일 → 저장·재개; 과거 기억 전체 불변, 현재 믿음의 사건·습득일 갱신 |
| M5-T02~T06 | 기존 M4 투영 9개를 실제 커널에서 재현; native Schema 5 절도·목격·비밀; INVALIDATED·A00 무반응; 동시 자원 경쟁으로 GRANT_PARTIAL 후 지급 0 |
| M5-T07~T11 | 전언 confidence, B02 역순의 전체 observation·hash, 한 번의 최초 수용, 압축 후 재적용 방지, 방향당 2개·상대 3명·깊이 3 상한, 99+4-3의 합산 후 clamp |
| M5-T12~T16 | 학습 전후 M40→48·효용 +80, norm69→71에서 C46→47, 압력·주간 경계, 기억 104→96, 첫 습득일 기준 14일 만료 |
| M5-T18~T20 | 제출 순서 변경의 전체 결과, 네 저장 checkpoint의 연속 실행 동등성, 공개 직접 변경 거부, player ID만 바꾼 의미 계산 동등성, 실제 상태 크기 |
| M0–M4 | 기존 실행 시험 및 golden artifact 보존 |

보정 제안 fixture는 원래 FCAL 28행의 날짜·수량·소비 거래·기억·epoch·revision·주간 수치를 모두 재현했다. 최종 식량은 80, 총 소비는 75, 자원 거래는 41개다. 최종 관측·영수증은 각각 3개이며 상세 기억은 0개다. 이 결과가 승인 전 정본 FCAL의 실패를 덮어쓰지는 않는다.

## M5-RUNTIME-B01: 정본 FCAL의 건강 경계

정본 `FCAL_initial_payload.state.persons`의 `person:000003`은 health=100, hunger=40, 하루 필요 식량=1이다. 0~4일 완전 식사로 hunger가 10까지 내려가고 이후 식량 부족으로 매일 24씩 오른다. 기존 임계값 80 이상이 이틀 연속이면 건강이 매일 5씩 감소한다.

| 종료일 d | 정본 hunger / health / 심각한 굶주림 연속일 | 보정 제안 hunger / health / 연속일 |
|---|---|---|
| 5 | 34 / 100 / 0 | 31 / 100 / 0 |
| 6 | 58 / 100 / 0 | 55 / 100 / 0 |
| 7 | 82 / 100 / 1 | 79 / 100 / 0 |
| 8 | 100 / 95 / 2 | 100 / 100 / 1 |
| 26 | 100 / 5 / 20 | 100 / 10 / 19 |
| 27 | 건강 0 요청 → 하루 종료 거부 | 100 / 5 / 20 |

거부 원인은 기존 `PersonDayUpdate.update_health`의 `M2_DEATH_NOT_IMPLEMENTED`다. M5는 허용된 오류 vocabulary로 `M5_POST_APPLY_INVARIANT`, `state.persons.health`, `person:000003`을 반환한다. 출력 세계는 null, 거래·변경 배열은 비어 있고 입력 clone 밖으로 자원 변화가 공개되지 않는다. 건강 커널 원문은 기준 커밋과 동일하다.

결정 26 §6.3은 기존 건강 알고리즘을 유지하도록 하며, §16의 FCAL 28행은 이 종료를 성공으로 요구한다. §17은 명세 충돌을 임의로 선택하여 구현하지 않도록 요구한다. 따라서 정본 보정 승인이 필요하다.

## 검토할 최소 보정안 — 아직 NON-CANONICAL

FCAL에만 `person:000003.need_scores.hunger: 40 → 37`을 적용한다. 38 또는 39는 여전히 27일 종료에서 건강 0이 되므로, 같은 필드만 조절할 때 37이 가장 가까운 생존 초기값이다. 물리 규칙·사망 처리·FCAL 28행의 기존 scalar 기대값은 바꾸지 않는다. 별도 B01 초기 payload와 exact save·실패 artifact 7개는 변경 대상이 아니다.

| 결속 | 값 |
|---|---|
| 기존 FCAL 초기 state hash | `6914961c6d6dcaa5ed3f460fd870254a2aa0d851837a6f5545f19005d81886a1` |
| 보정 제안 초기 state hash | `4d5b8b6f98be80177caec978fd310e353f518e5a133f7eae2396af7c70ee0d51` |
| 보정 제안 28일 최종 state hash (실행 관측) | `d6a1a9db0d844dcff85a9f39c118fabfd8d43c17c32a35fe64f520fbb8a1b138` |
| 보정 제안 첫 판단 | A04 선택, N=54, A04 효용 5505, A11 효용 3535 |

초기 세계가 달라지므로 M3 입력 hash와 그에 결속된 intent·context·후속 artifact hash도 달라진다. 규칙 의미 변경은 아니므로 social/simulation ruleset hash는 유지한다. 승인되면 별도 정본 정오표로 변경 대상을 고정하고, 보정된 canonical FCAL로 전체 게이트를 다시 실행해야 한다.

## 재현과 CI

저장소 루트에서 실행한다. 새 checkout은 먼저 Godot class cache를 생성한다.

```sh
godot --headless --editor --path . --quit
python tools/verify_m5.py --godot /absolute/path/to/godot
```

원래 M0–M4 시험 runner도 그대로 실행한다. M5 wrapper는 assertion·스크립트 오류·누락된 evidence를 실패로 처리한다. 종료 코드는 PASS=0, 실행 실패=1, 재현된 설계 HOLD=2다. 현재 기대 종료 코드는 2이며, CI에 통과 예외를 두지 않는다.

Linux·Windows job은 동일 runner를 실행하고 `m5-runtime-evidence.json`과 로그를 artifact로 남긴다. 별도 job이 두 실행 기록 전체의 바이트 동일성을 확인한다. 운영체제 동등성과 정본 계약 PASS는 별도 판정이며, HOLD가 동등하게 재현되어도 M5 완료로 간주하지 않는다.
