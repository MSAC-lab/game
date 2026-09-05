# 결정 26 FCAL 정오표 01

상태: **CANONICAL — FCAL 초기조건 보정**

관련 실행 문제: `M5-RUNTIME-B01`

사용자는 독립 검토 결과와 함께 이 한 필드 보정을 허용하고, 원래 hunger 40 사례를 건강 경계의 거부·원자성 시험으로 보존하도록 지시했다. 이 정오표는 결정 26 v0.2의 FCAL 초기조건과 이에 결속된 해시를 보정한다. M5 최종 PASS는 보정 후 전체 실행 검증의 결과로 별도 판정한다.

## 변경

| 항목 | 기존 | 보정 |
|---|---|---|
| `FCAL_initial_payload.state.persons[id=person:000003].need_scores.hunger` | 40 | 37 |
| FCAL 초기 state hash | `6914961c6d6dcaa5ed3f460fd870254a2aa0d851837a6f5545f19005d81886a1` | `4d5b8b6f98be80177caec978fd310e353f518e5a133f7eae2396af7c70ee0d51` |
| 유효 부록 design content hash | `df529563420b6b744536c60bc2794eafd980132fda3e94cd9d02a29b0cb50d92` | `9cd7d8629f03e74ed38c9442a0b276ae1051cb43852fa559d31623180e1f96f3` |

FCAL의 목적은 날짜·주간 정리·기억 만료·저장 재개 검증이다. 기존 hunger 40·39·38에서는 최초 건강 감소가 d=8에 발생하고 d=27 종료에서 건강이 0이 된다. hunger 37에서는 최초 감소가 d=9로 늦춰져 d=27 종료를 건강 5로 마친다. 같은 필드만 낮출 때 37이 28일을 완주하는 가장 가까운 초기값이다.

기존 건강·자원 알고리즘, 여섯 ruleset component, FCAL 28행의 scalar 기대값, B01·B02·B03, M4 투영 및 수치 벡터는 유지한다. 별도 B01의 초기 세계·기억·exact save는 보정 대상이 아니다. 초기 세계가 바뀌므로 FCAL의 M3 입력과 intent·context·후속 상태·artifact 해시는 보정된 세계에서 다시 계산한다. 실행으로 얻는 후속 전체 해시는 관측 기록이며 새 golden oracle로 간주하지 않는다.

## 원문 보존과 적용

- 승인 당시 [검증벡터 부록](../../tests/fixtures/m5_design_vectors.json)의 바이트 SHA-256은 `65914e923ed4786c51dcd45edb293823de9fffff29a9fb900f1a848d56df5d2e`로 보존한다. 결정 25·26 원문도 보존한다.
- 기계 판독 [정오표 JSON](m5-fcal-erratum-01.json)의 SHA-256은 `1b97855b959b5903aa13406a9b7877a00e9b692f1e35d0ca0dcdf01138da1e4e`다.
- `M5FixtureFactory.annex()`는 원본 부록의 바이트 결속을 확인한 후 지정 인물의 해당 필드와 파생 해시 두 개만 보정한 유효 정본을 제공한다. 보정을 역으로 적용하면 원본 전체와 동일해야 한다.
- `original_annex()`와 `original_fcal()`은 승인 당시 hunger 40 원문을 그대로 제공한다. 원본 안의 당시 승인 대기 문구와 기존 초기 해시는 역사 기록이며 현재 채택 상태는 채택 기록과 이 정오표가 정한다.
- 과거 [보정 제안](m5-fcal-proposal.json)과 [HOLD 실행 기록](../evidence/m5-pre-erratum-runtime-evidence.json)은 당시 근거로 보존한다. 이 정오표가 제안의 미승인 상태를 대체한다.

## 필수 실행 검증

1. 보정된 canonical FCAL은 28행 전체를 성공으로 완료하고, 기존 날짜·자원·기억·주간 수치 및 네 저장 checkpoint의 연속 실행 동등성을 충족한다.
2. 원래 hunger 40 FCAL은 d=27의 `person:000003` 건강 경계에서 거부된다. 오류 code·field·entity, 출력 세계 null, 거래·부분 변경 배열 없음, 중간·최종 해시 없음, 입력 세계와 exact save 전체 불변을 확인한다.
3. B01 날짜 분리·저장 재개, B02 입력 역순, 실패 artifact 7개와 M0–M4 회귀 게이트를 통과한다.
4. Linux·Windows에서 보정 후 전체 실행 기록의 바이트 동일성을 확인한다. M5 wrapper는 28일 완료 또는 건강 경계 회귀 검증이 누락되면 실패한다. 과거 HOLD를 PASS로 바꾸는 조건부 예외는 없다.
