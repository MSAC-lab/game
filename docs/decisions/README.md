# M5 설계 정본 채택 기록

사용자가 결정 25 v0.2·결정 26 v0.2·검증벡터 부록 v0.2를 설계 정본으로 승인했고, 이어서 M5 구현을 승인했다. 세 원문은 승인 대상의 바이트와 해시를 보존하여 이 브랜치에 채택한다. 원문에 남아 있는 `NON-CANONICAL`·구현 승인 대기 문구는 승인 전 작성 시점의 기록이며, 이번 명시적 승인으로 대체된다.

| 승인 원문 | 저장소 경로 | 파일 SHA-256 |
|---|---|---|
| 결정 25 v0.2 | [decision-25-v0.2.md](decision-25-v0.2.md) | `227a409bbde0042a996f35b5b8edfc9fe9169d83ef6f786ddeb4d04ab6a3c8f9` |
| 결정 26 v0.2 | [decision-26-v0.2.md](decision-26-v0.2.md) | `a15b4bfc57786441825107bb6491d6f35c6eee0e40c06cf3e75a9e966e5d6a43` |
| 검증벡터 부록 v0.2 | [m5_design_vectors.json](../../tests/fixtures/m5_design_vectors.json) | `65914e923ed4786c51dcd45edb293823de9fffff29a9fb900f1a848d56df5d2e` |

구현의 기준은 M4 `main@774680cad964b3485ceab1324c8eebac763abe41`, tree `b8451f637b460957bd3c04870b6be1561e19de8c`다. B01·B02·B03 설계 검토는 CLOSED이며, B01의 날짜 분리 시험을 추가했다. 정본 승인과 구현 승인은 구현 시험 PASS 또는 병합 승인을 뜻하지 않는다.

실행에서 발견한 FCAL 건강 경계 충돌은 사용자의 한 필드 보정 허용을 반영한 [FCAL 정오표 01](decision-26-fcal-erratum-01.md)로 해결한다. 현재 유효 정본은 위 원문과 정오표를 함께 적용한 결과다. 원본 부록의 바이트는 보존하며 FCAL 초기 hunger 40→37과 이에 결속된 해시만 보정한다. 원래 hunger 40 사례는 건강 경계의 거부·원자성 회귀 시험으로 유지한다. 실행 결과와 최종 검증 상태는 [M5 구현·검증 기록](../m5-implementation.md) 및 해당 PR의 현재 HEAD CI에서 확인한다.
