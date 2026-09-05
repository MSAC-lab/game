# M5 구현과 실행 검증

## 판정

**IMPLEMENTED / LOCAL FULL GATE PASS / REVIEW DRAFT.** Schema 5와 M5 실행 경로를 구현했다. 허용된 FCAL 초기 hunger 40→37 보정을 [정오표 01](decisions/decision-26-fcal-erratum-01.md)로 적용하고, 최종 검토의 M5-IMPL-B01 건강 오류 순서 문제를 수정했다. 로컬 Godot 4.7.2에서 28일 정본과 전체 M5 1,915개 검사를 통과했다. D26-R01·R02와 M5-RUNTIME-B01의 기존 PASS·CLOSED는 유지하며 최종 구현 재검토는 대기 중이다. 현재 HEAD의 Linux·Windows 전체 게이트와 evidence 동등성 결과는 [PR #14](https://github.com/MSAC-lab/game/pull/14)의 CI를 기준으로 판정한다.

승인된 세 설계 파일·기존 M4 수치 규칙·건강 알고리즘은 보존했다. 현재 유효 정본은 [정본 채택 기록](decisions/README.md)의 원문과 [정오표 JSON](decisions/m5-fcal-erratum-01.json)을 함께 적용한 결과다. [실행 evidence](evidence/m5-runtime-evidence.json)는 관측 출력이며 새 golden oracle이 아니다. 보정 전 HOLD 실행은 [과거 evidence](evidence/m5-pre-erratum-runtime-evidence.json)와 [로그](evidence/m5-pre-erratum-linux-runtime.log)에 보존했다.

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

Godot 4.7.2 Standard에서 다음을 실행했다. 현재 검증은 `checks=1915`, `failures=[]`, `m5_status=PASS`다. 보정된 정본의 28일 성공, 원본의 건강 경계 거부, M5-IMPL-B01 오류 순서·저장 재개 검증은 각각 필수 검사이며 하나라도 누락되면 전체 게이트가 실패한다.

| 계약 | 실행 근거 |
|---|---|
| M5-T01·T17·D26-R01 | 초기 hash, B01 native A04 이후 전체 payload·exact save, FAR-00~06 전체 실패 결과, 중간 상태의 공개·저장·M3 거부, stage 오염·후반 실패 rollback |
| B01 보강 | 과거 기억 0일 → 새 A04 1일 → 저장·재개; 과거 기억 전체 불변, 현재 믿음의 사건·습득일 갱신 |
| M5-T02~T06 | 기존 M4 투영 9개를 실제 커널에서 재현; native Schema 5 절도·목격·비밀; INVALIDATED·A00 무반응; 동시 자원 경쟁으로 GRANT_PARTIAL 후 지급 0 |
| M5-T07~T11 | 전언 confidence, B02 역순의 전체 observation·hash, 한 번의 최초 수용, 압축 후 재적용 방지, 방향당 2개·상대 3명·깊이 3 상한, 99+4-3의 합산 후 clamp |
| M5-T12~T16 | 학습 전후 M40→48·효용 +80, norm69→71에서 C46→47, 압력·주간 경계, 기억 104→96, 첫 습득일 기준 14일 만료 |
| M5-T18~T20 | 제출 순서 변경의 전체 결과, 네 저장 checkpoint의 연속 실행 동등성, 공개 직접 변경 거부, player ID만 바꾼 의미 계산 동등성, 실제 상태 크기 |
| FCAL 정오표·건강 경계 | 한 필드와 파생 해시만 보정됨을 전체 원본 비교로 검증; 원래 hunger 40의 d=27 거부·오류·거래 및 부분 변경 없음·입력 세계와 exact save 불변 |
| M5-IMPL-B01 | 동시 건강 경계의 정순·역순·각각의 저장 재개에서 동일 입력 hash와 전체 실패 결과·artifact hash; 원본 배열 순서·세계·exact save 불변 |
| M0–M4 | 기존 실행 시험 및 golden artifact 보존 |

보정된 canonical FCAL은 기존 28행의 날짜·수량·소비 거래·기억·epoch·revision·주간 수치를 모두 재현했다. 최종 식량은 80, 총 소비는 75, 자원 거래는 41개다. 최종 관측·영수증은 각각 3개이며 상세 기억은 0개다. 현재 `FCAL_canonical`의 28일 상태·artifact 기록은 보정 전 별도 제안 실행의 전체 기록과 같고, 원래 hunger 40의 27일 기록 및 마지막 거부 artifact도 보정 전 기록과 같다. B01 날짜 분리 사례의 상태 해시도 유지됐다.

## M5-IMPL-B01: 건강 오류 우선순위 — 수정·재검토 대기

최종 구현 검토에서 여러 인물이 같은 날 건강 0 경계에 걸리면 배열의 첫 인물이 대표 오류로 선택되는 문제를 발견했다. 결정 26 §7은 같은 단계의 동일 code·field 오류를 entity ID 순서로 선택하도록 요구한다.

`person:000001`과 `person:000003`을 health=5, hunger=100, severe_hunger_days=1, 전체 식량=0으로 두고 공개 접촉 처리 후 하루 종료를 실행했다. 수정 전 코드에서 새 회귀 시험은 1,915개 검사 중 2개가 실패했으며, [수정 전 실행 기록](evidence/m5-impl-b01-before.json)에 네 경우의 전체 결과를 남겼다.

| 입력 형태 | 수정 전 오류 대상 | 수정 후 오류 대상 |
|---|---|---|
| 정순 | `person:000001` | `person:000001` |
| 역순 | `person:000003` | `person:000001` |
| 정순 저장·재개 | `person:000001` | `person:000001` |
| 역순 저장·재개 | `person:000001` | `person:000001` |

네 입력의 상태 hash는 모두 `89d0915748a5610d27b9d4fbaad3b5c423597857ec5c8f94b76ea0d609c3b0fa`다. 수정 전 역순의 artifact hash는 `888a9686f40ab9c38cadcd6507f0ee831ff6f84a26106a7715ecec142e30761e`였고, 수정 후 네 경우는 모두 `278038056c8374a8cd6a5c18ee26d8ef860641659bc14ce88f7f2d3514c290e6`으로 일치한다. 해시뿐 아니라 반환 결과 전체의 canonical JSON도 동일하다.

수정은 Schema 5의 건강 검사 목록을 복사해 인물 ID 오름차순으로 순회하는 것으로 한정했다. 세계의 인물 배열을 제자리 정렬하지 않는다. Schema 2·4의 순회, 건강·굶주림 수치 알고리즘, 정본과 ruleset hash는 유지한다. 회귀 시험은 거부 후 원본의 배열 순서를 포함한 raw JSON, 상태 hash, exact save, 출력 세계 null, 거래·부분 변경 배열 없음과 미완료 중간·출력 hash가 비어 있음을 함께 확인한다.

84개 검사를 추가해 전체 1,915개를 통과했다. 새 실행 evidence는 기존 기록에서 검사 수만 바뀌고 `M5_health_error_order_regression` 항목이 추가됐다. 기존 FCAL 28일 기록, 원래 hunger 40의 거부 artifact, B01 날짜 분리 결과를 포함한 나머지 모든 evidence 필드는 동일하다. 수정의 로컬 실행 검증은 PASS이며, PR의 최종 구현 재검토는 별도로 대기한다.

## M5-RUNTIME-B01: 원본 FCAL의 건강 경계 — 회귀 시험으로 보존

보정 전 `FCAL_initial_payload.state.persons`의 `person:000003`은 health=100, hunger=40, 하루 필요 식량=1이다. 0~4일 완전 식사로 hunger가 10까지 내려가고 이후 식량 부족으로 매일 24씩 오른다. 기존 임계값 80 이상이 이틀 연속이면 건강이 매일 5씩 감소한다.

| 종료일 d | 원본 hunger / health / 심각한 굶주림 연속일 | 보정 정본 hunger / health / 연속일 |
|---|---|---|
| 5 | 34 / 100 / 0 | 31 / 100 / 0 |
| 6 | 58 / 100 / 0 | 55 / 100 / 0 |
| 7 | 82 / 100 / 1 | 79 / 100 / 0 |
| 8 | 100 / 95 / 2 | 100 / 100 / 1 |
| 26 | 100 / 5 / 20 | 100 / 10 / 19 |
| 27 | 건강 0 요청 → 하루 종료 거부 | 100 / 5 / 20 |

거부 원인은 기존 `PersonDayUpdate.update_health`의 `M2_DEATH_NOT_IMPLEMENTED`다. M5는 허용된 오류 vocabulary로 `M5_POST_APPLY_INVARIANT`, `state.persons.health`, `person:000003`을 반환한다. 출력 세계는 null, 거래·변경 배열은 비어 있고 입력 clone 밖으로 자원 변화가 공개되지 않는다. 건강 커널 원문은 기준 커밋과 동일하다.

결정 26 §6.3의 기존 건강 알고리즘과 §16의 FCAL 28행 성공 요구가 충돌하여 보정 전에는 HOLD로 보고했다. 독립 검토가 같은 결과를 확인한 뒤 사용자가 한 필드 보정을 허용했다. 이제 원래 40 사례는 d=27 종료의 **거부를 기대하는 회귀 시험**이며, 37을 사용하는 유효 정본은 28일 성공을 기대한다. 원본의 실패를 무시하거나 건강 커널을 우회하지 않는다.

## 채택된 최소 보정 — FCAL 정오표 01

FCAL에만 `person:000003.need_scores.hunger: 40 → 37`을 적용했다. 38 또는 39는 여전히 27일 종료에서 건강 0이 되므로, 같은 필드만 조절할 때 37이 가장 가까운 생존 초기값이다. 물리 규칙·사망 처리·FCAL 28행의 기존 scalar 기대값은 바꾸지 않았다. 별도 B01 초기 payload와 exact save·실패 artifact 7개도 유지됐다.

| 결속 | 값 |
|---|---|
| 기존 FCAL 초기 state hash | `6914961c6d6dcaa5ed3f460fd870254a2aa0d851837a6f5545f19005d81886a1` |
| 보정 정본 초기 state hash | `4d5b8b6f98be80177caec978fd310e353f518e5a133f7eae2396af7c70ee0d51` |
| 보정 정본 28일 최종 state hash (실행 관측) | `d6a1a9db0d844dcff85a9f39c118fabfd8d43c17c32a35fe64f520fbb8a1b138` |
| 보정 정본 첫 판단 | A04 선택, N=54, A04 효용 5505, A11 효용 3535 |
| 유효 부록 design content hash | `9cd7d8629f03e74ed38c9442a0b276ae1051cb43852fa559d31623180e1f96f3` |
| M5-IMPL-B01 수정 후 로컬 실행 evidence SHA-256 | `34e578713cf967894f6553c41684c1e8eca1a14ff6f91491ec39cc8dbeefed4d` |

초기 세계가 달라지므로 M3 입력 hash와 그에 결속된 intent·context·후속 artifact hash를 보정된 세계에서 다시 계산했다. 규칙 의미 변경은 아니므로 social/simulation ruleset hash는 유지했다. 승인 당시 원문과 과거 보정 제안은 역사 기록으로 보존하며 현재 FCAL에는 정오표가 우선한다.

## 재현과 CI

저장소 루트에서 실행한다. 새 checkout은 먼저 Godot class cache를 생성한다.

```sh
godot --headless --editor --path . --quit
python tools/verify_m5.py --godot /absolute/path/to/godot
```

원래 M0–M4 시험 runner도 그대로 실행한다. M5 wrapper는 assertion·스크립트 오류·누락된 evidence를 실패로 처리한다. 보정된 canonical FCAL의 28행 완료, 원본 건강 경계 회귀 PASS, M5-IMPL-B01 오류 순서·저장 재개 회귀 PASS도 요구한다. 종료 코드는 PASS=0, 실패=1이며, 이전 HOLD 종료 코드 2를 통과로 받아들이지 않는다.

Linux·Windows job은 동일 runner를 실행하고 `m5-runtime-evidence.json`과 로그를 artifact로 남긴다. 별도 job이 두 실행 기록 전체의 바이트 동일성을 확인한다. 전체 판정에는 두 플랫폼의 모든 게이트 PASS와 기록 동등성이 함께 필요하다. 이 기록은 로컬 검증 결과이며 원격 결과는 현재 PR HEAD의 CI와 대조한다.
