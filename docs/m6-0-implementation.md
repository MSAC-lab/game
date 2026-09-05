# M6-0 최소 자동 진행기 구현·관찰 기록

## 승인과 범위

사용자는 PR #15의 설계 정본 병합·사후 검증 이후 M6-0 구현을 승인했다. 구현 기준선은 `6c142b1739f677374094e2f2d8821904c53d1f2a`, tree `91486c3d465ce4a53a699a00dc38232f40c7a9dc`다.

- 설계: [M6-0 v0.2](decisions/m6-0-v0.2.md), SHA-256 `a8bcb4fb2346a3eb185ca50c0df0cf988d623d7dd2c7f6ff515998bf652332f8` 유지.
- 구현: 사용자 승인에 따라 구현. B 구현 검토 대기, 구현 PR 병합 미승인.
- 기존 M0–M5 규칙·상태 스키마·동결 자료와 시험은 보존한다.
- 이번 범위는 4명 환경의 반복 진행이다. 기존 M6 전체, 사망·이동·생산·강수·가격·새 행동·플레이 UI를 구현한 상태가 아니다.

## 실행

Godot 4.7.2 Standard를 사용한다. 저장소 루트에서 최초 editor scan을 수행한다.

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tools/run_m60.gd -- \
  --days=28 \
  --evidence-path=builds/m60-observation.json \
  --checkpoint-out=builds/m60-checkpoint.json
```

Windows에서는 `godot` 대신 `Godot_v4.7.2-stable_win64_console.exe` 경로를 사용한다. 위 명령을 한 줄로 연결하면 PowerShell에서도 실행할 수 있다.

기본 시나리오는 [m6-0-food-pressure-v1.json](../scenarios/m6-0-food-pressure-v1.json)이다. `--scenario=경로`로 다른 명시적 초기 조건을 사용할 수 있다. 숨은 초기화·식량 보충·매일 사실 주입은 없다.

```bash
godot --headless --path . --script res://tools/run_m60.gd -- \
  --days=1 \
  --checkpoint-in=builds/m60-checkpoint.json \
  --checkpoint-out=builds/m60-checkpoint.json \
  --evidence-path=builds/m60-resumed-observation.json
```

`--days`는 이번 호출에서 추가로 진행할 일수다. `0`은 초기/저장 경계 검증과 내보내기만 수행한다. 한 호출은 정수 `0..366`일로 제한해 동기 실행량을 제한한다. 이는 게임의 달력·수명 규칙이 아니며, 더 긴 실행은 체크포인트 재개로 나눈다.

| 종료 코드 | 뜻 |
|---|---|
| `0` | 요청한 추가 일수를 모두 완료 |
| `2` | 진행 중 중단; 실패한 날은 미확정, 직전 완료 세계와 진단 반환 |
| `1` | 진입·재개 조건 또는 CLI 입력·파일 처리 오류 |

CLI는 출력 디렉터리를 만들고 임시 파일을 완전히 쓴 후 교체한다. 기존 체크포인트 경로로 재개 결과를 저장할 수 있다. 체크포인트와 관찰 기록은 별도 파일이며, 두 파일을 묶은 파일시스템 트랜잭션을 제공하지는 않는다. 각 기록에 포함된 체크포인트 SHA-256으로 결속을 확인한다. 시나리오를 출력으로 덮거나 관찰 기록과 체크포인트에 같은 경로를 지정하는 입력은 거부한다.

## 구현 계약 대응

| 책임 | 구현 | 검증 |
|---|---|---|
| 같은 하루 시작 세계에서 판단 | `M60Runner`가 정렬된 생존 자동 대상 전체를 평가한 뒤 한 묶음으로 제출 | 인물별 판단 원문, 수동 M5 호출 및 순열 대조 |
| 실행용 현장 근거 | `M60PresenceIssuer`가 전체 인물·창고의 고정 현장 설정과 시작 세계에 결속 | 대상 선택으로 인원 추가 불가, 외부 창고·목격자 배제, 변조 문맥 거부 |
| 빈 자동 대상과 접촉 분리 | 행동만 생략, 유효 접촉 또는 빈 접촉 계획을 한 번 처리한 뒤 마감 | 두 경우 모두 수동 호출과 동일, 부양가족 소비 유지 |
| 하루 단위 확정 | 임시 상태에서 EXECUTE → CONTACTS → CLOSE, 성공한 하루만 이력에 추가 | 행동·접촉·마감 실패에서 세계·slot·epoch·카운터 보존 |
| 기존 M5 반환 호환 | `execute_decisions_observed_v1`가 기존 `_run`을 한 번 호출 | A00·A04·A11·INVALIDATED·거부·후기 실패의 정규 반환 동일성 |
| 실제 M4 원문 | M4 묶음 검증 직후 본문과 해시의 참조 없는 사본 확보 | 단일 커널 호출, 객체 변경으로 원문 불변, 해시 대조, 누락·변조 시 중단 |
| 하루 시작/재개 | `M60Checkpoint`의 Schema 5 검증 + 접촉일·slot·마감일·통합 epoch 검사 | 행동·빈 접촉을 처리한 중간 세계도 거부, 입력을 초기화하지 않음 |
| 설정·저장 결속 | 실행 설정·초기 세계·M5 저장 해시·하루 이력·버전 검증 | 설정 변경, 중간 세계, 누락된 날, 원문·판단·접촉·거래 변조 거부 |
| 반복 관찰 | 초기 세계·시드·설정과 전체 일별 원문을 실행 결과에 보존 | 동일 입력 반복, 7+21일 재개, 배열 순열의 정규 기록 동일성 |

실행 코드는 `src/simulation/autonomy/`에 있고 테스트용 현장 공급자를 사용하지 않는다. 기존 코드 변경은 M5 facade의 관찰용 진입점과 검증 직후 사본 확보뿐이다. M5의 기존 `M5OperationResult.to_data()`와 artifact 해시는 바뀌지 않는다.

## API와 기록

```gdscript
M60Runner.run_v1(initial_world, config, additional_days, checkpoint_json = "")
```

설정의 exact keyset은 `runner_version`, `initial_state_hash`, `simulation_ruleset_hash`, `automatic_person_ids`, `person_sites`, `store_sites`, `contacts`다. 현재 진행기 버전은 `m6-0-runner-v1`이다. 현장 맵에는 세계의 인물·창고를 빠짐없이 넣고, 접촉에는 정규 인물 순서의 ID를 사용한다. 접촉은 같은 현장의 생존자 사이에서만 실현하며 최대 3명의 상대 제한을 검증한다.

`M60RunResult`는 다음을 분리한다.

- `ok/status`: 기간 완주 `COMPLETED`, 진행 중단 `STOPPED`, 진입·재개 거부 `REJECTED`.
- `requested_days/advanced_days`: 이번 호출의 요청·완료 일수.
- `days`: 이전 체크포인트까지 포함한 전체 완료 이력.
- `failed_day`: 중단된 당일의 임시 증거. 완료 이력에 넣지 않는다.
- `next_world`: 마지막 완료 세계의 사본. 진입·재개 거부이면 `null`.
- `checkpoint_json`: 마지막 완료 경계의 저장 문자열. 거부이면 빈 문자열.
- `initial_payload/config`: 초기 상태·시드와 고정 현장·접촉·자동 대상·버전·규칙 식별자. 관찰 파일에서도 재현 입력을 확인할 수 있다.

각 일별 기록에는 판단 전체, M4 원문 또는 `null`, 접촉 계획, 세 단계의 M5 artifact와 자원 거래, 입력·출력 세계 해시 및 기록 해시를 남긴다. M5 artifact의 인식·기억·관계 변화와 M4 행동 결과를 같은 날에 연결한다. 이 기록을 NPC 판단 입력으로 다시 주입하지 않는다.

M4 본문의 `COMMITTED`는 M4 묶음 성공을 뜻한다. 이후 접촉·마감이 실패하면 원문은 그대로 두고 `failed_day.day_status=ABORTED`로 기록한다. 개별 `INVALIDATED`, 구호 거절, 절도 실패는 성공한 M5 묶음 안의 정상 결과여서 재판단이나 재추첨을 하지 않는다.

체크포인트는 기존 Schema 5 저장 포맷을 변경하지 않고 바깥 envelope로 설정과 하루 이력을 결속한다. 중간 세계를 노출하지 않는다. 전체 이력을 보존하므로 작은 실험에서 저장 크기는 실행 일수에 따라 증가한다. 해시는 일관성·재현성 검사이며 외부 작성자 인증이나 악의적인 전체 이력 위조 방지 서명이 아니다.

## 최초 28일 식량 압박 관찰

이번 시나리오는 승인된 M5 FCAL 정오표 적용 초기 세계를 그대로 복사했다. 원본 FCAL fixture와 정오표 파일은 수정하지 않았다. 자동 대상은 한결·미라·도윤 3명이며 나리는 생활·접촉 적용 대상이다. 모두 `site:village`에 고정하고 한결↔미라, 미라↔나리, 미라↔도윤을 접촉쌍으로 둔다.

```text
INITIAL STATE = 4d5b8b6f98be80177caec978fd310e353f518e5a133f7eae2396af7c70ee0d51
CONFIG HASH = 687ee01a169b095f39d924500854a596bfc26bde3032db7eeab8b5a35844e4d6
SCENARIO SHA-256 = 113340d2df337564f9414398f4a9e1c4d739b0c1c624bc29d58dbe7668b890cd
DAY 28 STATE = 23299127e3cd623143b470fbc8f9714742265424ae1270d166aca34b4afb28bb
```

| 인물 | 28일 선택 | 실제 처리 |
|---|---|---|
| 한결 | 도윤에게 A04 구호 요청 28회 | FULL 2회, PARTIAL 1회, NONE 25회 |
| 미라 | 도윤 가구 창고에 A11 절도 28회 | PARTIAL 6회, NONE 22회 |
| 도윤 | A00 현재 행동 유지 28회 | 자원 행동 없음 |

식량 155단위 중 75단위를 소비했고, 두 가구 창고는 0, 마을 창고는 80단위가 남았다. 28일 말 건강은 한결·미라·나리 각각 45, 도윤 5이며 네 인물의 굶주림은 100이다. 선택 원문에서 이번 실행의 구호 상대와 절도 대상이 도윤 가구로 한정됐음을 확인할 수 있다. 마을 창고 재고는 자동 배급되지 않는다. 이는 현재 초기 인식과 행동 규칙에서 나온 관찰값이며, 위 선택 횟수나 특정 이야기를 성공 조건으로 강제하지 않는다.

28일 완주와 건강 0 경계의 중단은 별도 검사다. 이 체크포인트에서 하루를 더 요청하면 29일째 마감이 `M5_POST_APPLY_INVARIANT / state.persons.health / person:000004`로 거부된다. 완료 일수는 28일을 유지하고 체크포인트 바이트도 동일하다. 실패한 날의 M4 본문은 `COMMITTED`, 바깥 하루는 `ABORTED`다. 건강 경계에서 식량 추가·소비 생략·건강 보정을 하지 않고 M5 원진단을 보존한다. 강수·수확·가격을 포함한 가뭄 모델의 실행 결과로 해석하지 않는다.

## 검증과 B 검토

```bash
python tools/verify_m5.py --godot /path/to/godot
python tools/verify_m60.py --godot /path/to/godot
```

M0–M4 기존 runner와 프로젝트 부팅 검사를 유지한다. 로컬 M5는 기존 1,915개 검사·실패 0을 유지했다. M6-0 gate는 7개 시험군의 완료, 엔진 오류·스크립트 중단 부재, 반복·재개 일치, 28일 완주와 별도 예상 건강 중단을 함께 검사한다. 검사 개수와 최종 판정은 실행한 HEAD의 `builds/m60-runtime-evidence.json`에 기록한다.

GitHub Actions의 Linux·Windows 각각에 M6-0 gate를 추가하고, 두 OS의 전체 M6-0 JSON 기록을 바이트 비교한다. 기존 M5 gate와 M5 기록 비교도 유지한다. OS 판정은 구현 PR의 현재 HEAD CI와 업로드된 `m60-evidence-linux`·`m60-evidence-windows`를 기준으로 확인한다.

B의 구현 검토 대상은 승인 계약 준수, 하루 원자성, 설정·저장 결속, 실제 원문의 단일 실행·참조 분리, 기존 M5 호환과 두 OS 재현성이다. 이 구현 기록은 B의 PASS 판정이나 병합 승인을 대신하지 않는다.
