# 결정 26 제안 — M5 상세 명세와 검증 벡터

작성일: 2026-09-05  
버전: v0.2 / HOLD 지적 반영 후 재검토용 비정본  
범위 기준: 결정 25 v0.2의 범위·책임 검토 PASS

```text
M5 DESIGN WORK = AUTHORIZED
DECISION 25 v0.2 = REVIEW PASS / APPROVAL RECOMMENDED / NON-CANONICAL
DECISION 26 v0.1 = HOLD / THREE REVIEW BLOCKERS
DECISION 26 v0.2 = REVISED DRAFT / REVIEW PENDING / NON-CANONICAL
D26-R01 / D26-R02 = SPECIFIED IN THIS DRAFT / RUNTIME VERIFICATION PENDING
M5 IMPLEMENTATION = NOT AUTHORIZED
BASE MAIN = 774680cad964b3485ceab1324c8eebac763abe41
BASE TREE = b8451f637b460957bd3c04870b6be1561e19de8c
```

v0.1의 HOLD 판정을 수용하고, 기존 M5 설계 승인 범위에서 세 blocker의 계약과 검증 원문을 보완했다. 이 개정은 정본 채택이나 구현 승인을 뜻하지 않는다. 문서·부록의 기대값은 선언적 설계 계산이며 Godot 실행 결과가 아니다.

| 재검토 지적 | v0.2 조치 | 검산 원문 |
|---|---|---|
| B01 과거 기억 ↔ 현재 믿음 참조 모순 | 과거 사건·습득일은 memory에 고정하고 linked_information_id는 같은 소유자의 안정된 현재 fact ID로 해석 | 4.5·11·16.5절, `blocker_vectors.B01` |
| B02 상충 보고 보관 대표 미정 | 미수용 보고에 진위와 독립적인 전체 정렬을 적용; 역순 입력의 전체 observation을 고정 | 9.3절, `blocker_vectors.B02` |
| B03 요청 identity·실패 artifact 미정 | exact 원소·preimage·계산 시점, 실패 단계별 값과 빈 값, 7개 실패 artifact 원문 | 18절, `blocker_vectors.B03` |

세 항목의 문서·벡터 반영을 완료한 개정안이며, blocker 해소의 재검토 판정은 아직 받지 않았다. D26-R01/R02의 기존 설계 해결안은 유지하고 실행 검증은 구현 승인 뒤에 수행한다.

## 1. 산출물과 읽는 순서

이 문서는 처리 의미·소유권·실패 조건을 정의한다. 동봉한 `Decision26_M5_상세명세_검증벡터_v0.2.json`은 exact keyset, social 규칙 원문, 규칙 해시, Schema 5 최초 세계 원문, 28일 연속 기대표·수치 벡터와 세 blocker의 추가 exact 벡터를 제공한다. JSON은 게임에 설치한 ruleset이나 시험 코드가 아니라 **검토용 명세 부록**이다.

| 결정 25에서 남긴 항목 | 이 문서의 위치 |
|---|---|
| Schema 5 keyset·소유권·참조 | 3–4절, JSON `exact_keysets` |
| API·원자성·replay·오류 우선순위 | 5–7절 |
| D26-R01 검증·해시 경계 | 6절 |
| 관찰·흔적·출처·전언 | 8–10절 |
| 믿음·관계·감정·압력 수치 | 11–13절 |
| 날짜·주간·기억 경계 / D26-R02 | 14–16절 |
| 규칙 원문·해시·기준 세계·검증 계약 | 17–20절, JSON 부록 |

관측할 인과는 `M4 결과 → 허용된 인식 → 현재 믿음·관계·감정·압력 → 다음 M3 계산`이다. 행동은 A00·A04·A11이며, 접촉과 실행 순서는 명시적인 test driver가 제공한다. 새로운 행동군·능력치·자동 일정은 이 명세에 없다.

## 2. 공통 수치와 정규화

### 2.1 정수

- 저장하는 일반 정수는 `0..2147483647`이다. `last_*` 초기값 `-1`, 압력 `-100..100`, 감사용 signed delta는 아래 별도 범위를 사용한다.
- 중간 산술은 signed 64-bit로 수행하며, 저장 범위를 넘으면 원자적 실패다. 점수와 압력에 명시한 clamp 외에 overflow를 clamp로 숨기지 않는다.
- `RD(n,d) = sign(n) × floor((2×abs(n)+d)/(2×d))`, `d>0`이다. 정확한 절반은 0에서 멀어지는 쪽으로 반올림한다. `RD(-1,2)=-1`이다.
- `TD(n,d)`는 0 방향 절삭 나눗셈이다. `floor`와 혼용하지 않는다. 양의 반복 압력에만 쓰는 나눗셈은 `floor`다.
- 점수는 `0..100`, 관계 delta의 적용은 동일 snapshot에서 모두 계산한 뒤 필드별 합산·1회 clamp다. 압력도 소유자·축별 합산 후 1회 `[-100,100]` clamp한다.
- 같은 batch의 배열 순서는 실행 의미가 아니다. 서로 다른 batch의 순서는 실행 의미다.

### 2.2 Canonical JSON

기준 코드의 `StateCanonicalizer`와 동일하게 UTF-8, 정렬된 객체 키, 공백 없는 JSON을 해시한다. 문자열 배열은 오름차순, 모든 원소에 `id`가 있는 객체 배열은 `id` 오름차순으로 정규화한다. 숫자 배열의 순서는 자동 변경하지 않으므로 `low_risk_days`는 입력부터 오름차순·중복 없음이어야 한다. 부동소수·NaN·Infinity·중복 JSON 객체 키는 Schema 5 입력에서 거부한다.

기존 Schema 1–4 decoder의 수치 허용 동작은 유지한다. 새 Schema 5 raw JSON의 정수 토큰 검증과 duplicate-key 검증은 typed 변환 전에 수행해야 한다. Godot JSON parse 후 동일 키의 마지막 값만 남은 상태를 exact-key 검증에 넘기는 것으로 대신하지 않는다.

`H(x)`는 위 canonical JSON의 SHA-256 소문자 64자리다. `null`은 문서·artifact에서 명시한 경우만 사용한다. 저장 모델의 없는 선택적 참조는 `""`다. JSON 파일 자체 SHA와 canonical 내용 SHA는 서로 다른 값이다.

### 2.3 기본값

존재하지 않는 관계의 다섯 축은 각각 0이다. 읽는 자기 성향·가치관·감정 key가 없으면 0이며 artifact에 경로를 기록한다. 새 기본 관계를 먼저 만들어 모든 NPC를 연결하지 않는다. 실제 적용 후 기본값과 다른 값이 생긴 방향에만 관계를 생성한다.

## 3. Schema 5 저장 계약

### 3.1 최상위

| 객체 | exact 키 |
|---|---|
| 해시용 payload | `schema_version`, `ruleset_manifest`, `simulation_ruleset_hash`, `state` |
| save envelope | payload 4키 + `audit`, `resource_audit`, `social_audit`, `state_hash` |
| manifest | `resource`, `decision`, `parameterization`, `response`, `resolution`, `social` |
| 각 component | `ruleset_id`, `ruleset_hash` |

`schema_version=5`다. 기존 다섯 component의 ID·hash·수치·선택 규칙은 유지하고 `social` 하나를 더한다. `simulation_ruleset_hash = H({"ruleset_manifest":manifest})`다.

`state`는 기존 Schema 4의 18키에 아래 6키를 더한 정확히 24키다. 전체 목록은 JSON `exact_keysets.state`와 최초 payload에 수록했다.

next_ids의 exact 키는 `decision,event,household,information,memory,person,resource_transaction`이다. 값은 모두 1..2147483647이다. 새 hash ID용 counter는 추가하지 않는다.

```text
social_state
social_observations
social_effect_receipts
traces
trait_pressures
repeat_exposures
```

`social_state`는 객체이고 나머지 다섯 컬렉션은 ID가 있는 객체 배열이다. PersonState에 별도의 `social_observation_ids`를 중복 저장하지 않는다. 소유자 인덱스는 이 컬렉션에서 파생한다.

### 3.2 social_state의 다섯 필드

| 필드 | 범위·의미 | 최초값 |
|---|---|---:|
| `last_integrated_resolution_epoch` | 마지막으로 사회적 통합까지 마친 M4 epoch | 0 |
| `revision` | 성공한 M5 공개 작업의 누적 횟수 | 0 |
| `last_contact_day_index` | 접촉 pass를 마친 날짜 | -1 |
| `last_closed_day_index` | 자원 진행과 사회적 정리를 모두 마친 날짜 | -1 |
| `last_settled_week_index` | 주간 정리를 마친 0-based 주차 | -1 |

공개 가능한 날짜 `d`의 불변식은 다음과 같다.

```text
resolution_epoch = last_integrated_resolution_epoch
last_closed_day_index = d - 1
last_settled_week_index = floor(d / 7) - 1
last_contact_day_index ∈ {d - 1, d}
day_phase = DAY_END
revision >= resolution_epoch
```

`DAY_END`는 기존 코드가 허용하는 안정된 세계의 phase 값이다. “현재 날짜의 close가 이미 끝났다”는 뜻으로 재해석하지 않는다. 날짜별 행동·접촉·종료 순서는 위 social_state가 보호한다.

새 Schema 5 시나리오의 기본 시작은 `d=0`, 두 epoch=0, revision=0이다. 기존 세이브를 자동 변환하지 않는다. 최초 fixture를 선언적으로 만드는 것은 허용하지만, Schema 4 세계에서 발생한 과거 행동을 모두 처리한 것처럼 epoch만 복사하는 변환은 허용하지 않는다. 별도의 mid-game migration API는 이번 범위에 없다.

### 3.3 기존 모델의 변경 범위

| 모델 | Schema 5에서의 차이 |
|---|---|
| PersonState | 기존 Schema 4의 19키 유지. 새 성격·능력 축 없음 |
| HouseholdState / ResourceStoreState / RelationState | 기존 직렬화 키 유지 |
| EventRecord | `m5_origin`, `objective_payload` 추가 |
| InformationState | `source_observation_id` 추가 |
| MemoryState | `source_observation_id`, `first_learned_day_index`, `core_eligible` 추가 |

Schema 1–4에서는 위 추가 키를 출력하지 않는다. 각 모델의 schema-aware `to_data/from_data`와 collection helper 호출까지 변경 대상을 명시해야 한다. 특히 현재 `MemoryState.to_data()`와 `EventRecord.to_data()`에는 schema 인자가 없으므로, world의 추가 배열만 넣는 것으로 완료할 수 없다.

### 3.4 감사 로그와 저장 재개

`audit`, `resource_audit`, `social_audit`는 배열이며 state hash에 포함하지 않는다. social_audit는 18절의 operation artifact 형식이다. 미래 판단·중복 방지·압력·반복 감쇠는 `state`만 읽는다.

Schema 5에서는 세 audit 배열이 빈 배열이어도 재개가 가능하다. 자원 sequence와 ID는 저장 상태의 counter를 이어 사용한다. **현재 Schema 4 decoder는 빈 resource_audit일 때 sequence=0을 요구한다. 이 제한은 Schema 4에 그대로 두고, Schema 5에서만 audit 생략을 허용한다.** 제공된 자원 로그가 있다면 ID·sequence 중복, 참조, quantity, 최대 sequence보다 큰 다음 counter 조건을 검사한다.

Schema 5의 권장 저장 진입점은 `M5SaveCodec.encode_checked(world,audit,resource_audit,social_audit)`이며 `{ok,json_text,errors}`를 반환한다. 실패의 json_text는 ""다. `decode_checked(json_text)`는 `{ok,world,audit,resource_audit,social_audit,errors}`를 반환하며 실패의 world=null, 세 audit=[]다. 기존 StateCodec의 Schema 5 분기는 이 checked 경로에 위임한다. legacy encode의 String 반환형은 유지하고 Schema 5 실패 시 ""를 반환하므로, 새 호출자는 checked API의 오류를 사용한다.

M4의 action transaction ID는 hash이고 소비 transaction ID는 순차 ID다. 소비 ID의 최댓값은 `next_ids.resource_transaction`보다 작아야 한다. hash ID를 순차 counter로 해석하지 않는다. 저장되지 않은 과거 로그와의 중복 여부를 validator가 복원했다고 주장하지 않으며, 실행 경로가 보존한 counter가 재사용을 막는다.

## 4. 신규 모델·ID·역참조

전체 exact keyset은 JSON 부록에 있다. 이 절은 각 필드의 의미와 조건을 닫는다.

### 4.1 사건과 흔적

M4의 `RESOLVED/A04` 및 `RESOLVED/A11` outcome당 EventRecord 하나를 만든다. action_instance_id 오름차순으로 기존 `next_ids.event`를 할당한다. 초기·기존 사건의 `m5_origin={}`, `objective_payload={}`를 허용한다. 새 사건은 두 필드가 모두 비어 있으면 안 된다.

`m5_origin`의 exact 키는 `source_action_instance_id`, `source_outcome_hash`, `source_context_id`, `input_resolution_epoch`, `output_resolution_epoch`다. 앞의 세 값은 소문 전달 권한이 없는 내부 식별자다. output epoch는 input+1이고 사건 날짜는 결속된 context의 `d`다.

- A04: `event_type=aid_exchange`, `action_id=A04`, actor_ids=[요청자], target_ids=[응답자], witness_ids=[], is_public=false, location_id=실제 지급 source store. `objective_payload`는 8절 aid payload 5키에 `source_store_id`, `recipient_store_id`를 더한다.
- A11: `event_type=theft_attempt`, `action_id=A11`, actor_ids=[행위자], target_ids=[], witness_ids=유효 seed 소유자, is_public=false, location_id=목표 store. `objective_payload`는 `actor_person_id`, `store_id`, `actual_units`, `attempted_units`, `trace_created`다.
- `result_id`는 M4의 objective_outcome(`FULL/PARTIAL/NONE`)이다. 그 값이 그대로 NPC의 인식 payload가 되지는 않는다.
- A11의 대상은 store이므로 기존 EventRecord의 사람 참조 배열인 target_ids에 store ID를 넣지 않는다.

`TraceState`는 `id`, `event_id`, `store_id`, `occurred_day_index`, `trace_type`, `exists`, `source_action_instance_id`의 7키다. `trace_created=true`인 A11당 하나, `trace_type=theft_disturbance`, `exists=true`다. ID는 `trace:` + action_instance_id다. M5에서는 조사·소멸·범인 발견을 실행하지 않는다. actor ID를 조사자에게 직접 주는 필드는 없다.

### 4.2 현재 인식

`SocialObservationState`의 유일키는 `(owner_person_id,event_id)`다. ID는 아래와 같다.

```text
social_observation: + H({algorithm_id:"m5-observation-id-v1",owner_person_id,event_id})
```

문자열 prefix 뒤에는 소문자 64자리 hash를 붙인다. 객체의 17키는 JSON 부록에 수록했다.

| 필드군 | 제약 |
|---|---|
| `owner_person_id`, `event_id` | 유효한 참조. 인식을 가진 소유자만 이 내용을 판단·전달에 사용 |
| `occurred_day_index` | 인식이 전하는 사건 발생일. 새 직접 인식은 M4 context의 d |
| `first_learned_day_index` | 이 사건에 대한 첫 수신일. 재수신·수용·출처 개선으로 갱신 금지 |
| `first_accepted_day_index` | 수용 전 -1, 최초 수용일부터 고정 |
| `acquisition_type` | `self_experience`, `direct_interaction`, `direct_witness`, `hearsay` 중 하나 |
| `origin_view` | `aid_requester`, `aid_responder`, `theft_self`, `theft_witness` 중 하나. 전언에서도 보존 |
| `original_source_person_id`, `current_source_person_id` | 최초 직접 정보원과 직전 전달자. 직접 경험에서는 둘 다 owner |
| `depth`, `confidence` | 직접은 0·100, 전언은 1..3·0..99 |
| `accepted`, `is_secret`, `conflicted` | bool. 판단에 사용하는 현재 수용 내용과 상충 보고의 존재를 구분 |
| `payload` | origin_view에 대응하는 8절의 exact payload |
| `importance` | 0..100. 최초 수용 시 자기 해석에서 계산. 미수용은 0 |

직접 경험의 owner·origin_view는 실제 역할과 맞아야 한다. 예를 들어 theft_self 직접 경험의 owner는 payload.actor_person_id다. 전언 수신자의 owner가 행위자일 필요는 없다. 저장 검증에서 주관적 내용을 objective_payload의 정답과 대조하여 잘못된 믿음을 교정하지 않는다. 참조·형식·자기 경험의 역할 제약을 검사하고, 새 직접 인식의 사실 결속은 내부 projector가 보증한다.

v0.2의 theft_self는 acquisition_type=self_experience, owner=actor, is_secret=true로만 허용한다. 일반 접촉에서 이 인식을 발신하거나 theft_self origin의 hearsay를 생성하는 경로가 없다.

첫 수신 후 최초 수용이 늦어지더라도 기억의 나이 원점은 첫 수신일이다. 여러 번 듣다가 수용한 사건을 새 사건처럼 무한 연장하지 않는 v0.2 정책이다. 같은 사건을 처음 들은 날이 늦은 다른 NPC는 그 사람의 첫 수신일부터 센다.

날짜 범위는 `0<=occurred<=first_learned<=world.day_index`다. first_accepted는 미수용일 때 -1, 수용 상태에서 first_learned..world.day_index다. 직접 인식은 실제 처리일에 생성하므로 occurred=first_learned=first_accepted=d다. 미수용에서는 importance=0이며 영수증이 없다.

### 4.3 사건별 적용 영수증

`SocialEffectReceipt`는 `(owner,event)`당 최초 수용 시 하나 생성한다. ID는 `social_effect:` + `H({algorithm_id:"m5-effect-receipt-id-v1",owner_person_id,event_id})`다.

필드는 `id`, `owner_person_id`, `event_id`, `applied_revision`, `applied_day_index`, `applied_observation_id`, `applied_payload_hash`, `memory_id`다. 관계·감정·압력이 모두 0이어도 수용했다면 영수증을 만든다. memory_id는 현재 살아 있는 기억을 가리키며, 압축·만료 시 같은 commit에서 `""`로 바꾼다. 영수증 자체는 삭제하지 않는다.

applied_revision은 해당 성공 작업의 최종 revision(r+1), applied_day_index는 현재 행동·접촉일 d다. applied_observation_id의 owner/event가 영수증과 같아야 하며, memory_id가 비어 있지 않으면 그 기억도 같은 owner/event/observation을 가리킨다. 현재 revision보다 미래인 applied_revision을 거부한다.

`applied_payload_hash = H({origin_view,payload})`는 최초 적용 당시 값이며, 나중에 출처·현재 인식이 개선돼도 불변이다. 이미 수용한 observation에는 영수증이 반드시 하나 있고, 미수용 observation에는 없어야 한다. 영수증이 존재하면 새 관계 효과·새 기억·학습·압력을 다시 발행하지 않는다. 추후 허위 고발 철회·복구는 별도 계약이다.

### 4.4 압력과 반복 상태

- TraitPressureState: `id`, `owner_person_id`, `trait_id`, `pressure`. trait_id는 `norm_adherence` 하나, pressure는 -100..100이다. ID=`trait_pressure:<person_id>:norm_adherence`. 없으면 압력 0이며, 주간 정리 후 0이 된 기존 레코드는 보존해도 결과가 달라지지 않도록 **v0.2에서는 보존**한다.
- RepeatExposureState: `id`, `owner_person_id`, `action_family`, `trait_id`, `low_risk_days`. action_family=A11, trait_id=norm_adherence. ID=`repeat_exposure:<person_id>:A11:norm_adherence`. low_risk_days는 아래 13절의 최대 7개 날짜다. 대상 store는 key에 포함하지 않는다. 비어 있는 기존 레코드도 보존한다.
- 순차 counter를 추가하지 않고 결정론적 ID를 사용한다. person·event·information·memory·resource_transaction 등 기존 counter는 보존한다.
- 할당 가능한 순차 counter는 먼저 필요한 개수를 세어 검사한다. 없는 필수 counter를 1로 추정하는 IdAllocator의 fallback은 Schema 5 진입 전에 막는다. 기존 순차 ID suffix의 최대값보다 다음 counter가 커야 하며 max int+1을 저장할 할당은 실패한다.

할당 순서는 사건은 action_instance_id↑, 새 information은 `(owner,fact_type,subject)`↑, 새 memory는 `(owner,event)`↑다. observation·영수증·관계·압력·반복은 위의 파생 ID를 사용한다. 모든 계획을 먼저 구성하고 counter preflight를 마친 뒤 같은 clone에 반영한다.

### 4.5 기존 링크와 새 링크

- information.source_observation_id=`""`이면 legacy/초기 fact다. 기존 linked_event_id는 필수다. 새 학습 fact는 observation을 참조하고, owner와 event가 모두 같으며 수용 상태여야 한다.
- 새 memory는 source_observation_id가 있고 linked_information_id=`""`다. linked_event_id는 observation의 event와 같아야 한다.
- legacy memory는 source_observation_id=`""`이고 linked_information_id가 필수다. 참조한 information은 존재하고 owner가 memory의 owner와 같아야 한다. 이 링크는 **현재 믿음의 안정된 레코드 ID**이며 과거 사건의 출처 snapshot이 아니다. information의 현재 linked_event_id·learned_day_index가 memory의 과거 사건·습득일과 같을 것을 요구하지 않는다.
- legacy memory의 linked_event_id는 독립적으로 존재하는 과거 사건을 참조하고 occurred_day_index는 그 사건 날짜다. first_learned_day_index는 생성·초기 fixture 선언 시 한 번 정한 값으로 `occurred<=first_learned<=world.day_index`를 만족해야 한다. encode/decode·현재 fact 갱신에서 이 날짜를 다시 추론하거나 덮어쓰지 않는다.
- 현재 fact의 `id,owner_person_id,fact_type_id,subject_kind,subject_id`는 갱신 전후 고정한다. 같은 ID를 다른 소유자·fact·대상에 재사용하거나 살아 있는 legacy memory가 참조하는 fact를 삭제하지 않는다. 현재 믿음의 값·출처만 11절에 따라 바뀐다.
- 과거 기억의 내용은 memory의 perceived 필드·related_person_ids·emotion_scores와 과거 event에서 읽는다. mutable information.claim·현재 출처를 따라가 과거 기억의 내용으로 표시하지 않는다. 정보 이력 컬렉션이나 새로운 저장 키는 추가하지 않는다.
- memory의 source_observation_id와 linked_information_id를 모두 채우거나 둘 다 비우면 거부한다. 새 observation-backed memory의 owner·event·첫 습득일은 source observation과 같아야 한다. legacy memory의 사건 독립 규칙을 새 기억의 역참조 완화에 적용하지 않는다.
- person.information_ids와 memory_ids는 각각 해당 owner의 실제 레코드와 정확히 일치한다. relation_ids는 그 person이 from_person인 방향의 실제 관계와 일치한다. 중복·다른 소유자 참조·누락을 모두 거부한다.
- 사건·인식·영수증·흔적은 v0.2에서 삭제하지 않는다. 살아 있는 모든 memory·information의 출처 링크를 유지한다. 실제 관계가 없는 전 인물 쌍이나 실제 접촉하지 않은 전 인물×전 사건 조합은 만들지 않는다.

## 5. 공개 API와 실행 순서

다음은 구현 시 제공할 signature다. 현재 코드에 존재한다는 뜻은 아니다.

```text
M5Facade.execute_decisions_v1(world: WorldState,
  stamp: M5RequestStamp,
  submissions: Array[DecisionSubmission],
  issuer: ResolutionContextIssuer) -> M5OperationResult

M5Facade.process_contacts_v1(world: WorldState,
  stamp: M5RequestStamp,
  plan: SocialContactPlan) -> M5OperationResult

M5Facade.close_day_v1(world: WorldState,
  stamp: M5RequestStamp) -> M5OperationResult
```

stamp의 exact 키는 `input_state_hash`, `day_index`, `social_revision`다. SocialContactPlan은 `{pairs:Array[SocialContactPair]}` 하나다. pair는 `id`, `person_a_id`, `person_b_id`이며 a<b, id=`contact:<a>-><b>`다. 접촉 한 쌍은 양방향 전달 기회를 뜻한다. 반대 순서로 같은 쌍을 다시 넣지 않는다.

성공 시 최종 next_world, 완료 artifact, 이번 자원 transaction만 반환한다. 실패 시 next_world=null, 공개 자원 transaction=[], 실패 artifact만 반환한다. 중간 M4 COMMITTED는 전체 작업의 성공을 뜻하지 않는다.

| 호출 | 입력 조건 | 성공 시 변화 |
|---|---|---|
| execute | publishable, contact_day=d-1, nonempty submissions, stamp 일치 | M4 epoch+1, integrated epoch+1, revision+1; 날짜 동일 |
| contacts | publishable, contact_day=d-1, stamp 일치 | contact_day=d, revision+1; epoch·날짜 동일 |
| close | publishable, contact_day=d, stamp 일치 | 날짜 d+1, last_closed=d, revision+1; epoch 동일 |

하루에 action batch는 0회 이상 가능하지만 각 사람의 daily_food_strategy 슬롯은 기존 M4 규칙대로 1회다. 접촉은 빈 plan을 포함해 정확히 1회, 종료는 그 후 1회다. 접촉 후에는 같은 날짜의 추가 행동을 허용하지 않는다. 다음 날에는 명시적인 새 판단과 새 stamp를 만든다.

원본 세계와 같은 원본 요청을 순수 함수에 다시 넣으면 같은 결과를 계산할 수 있다. 이것은 replay 방지가 실패한 것이 아니다. **성공한 결과를 현재 세계로 채택한 뒤 과거 요청을 적용하는 것을 거부**하는 계약이다. 이 API는 저장 파일 복제·과거 세계 분기를 전역적으로 금지하는 서버가 아니다.

M3는 Schema 5의 publishable 입력을 허용하도록 명시적으로 확장하되 현재 decision 수치와 subjective fact 경계를 유지한다. 단독 M4Facade·AtomicActionResolver 공개 API, 단독 DayProcessor·ResourceService mutation API는 Schema 5 입력을 거부한다. Schema 5 실행은 위 세 M5 진입점을 통해서만 한다.

## 6. D26-R01 — 내부 중간 세계와 공개 세계

### 6.1 선택한 구조

Schema 5를 Schema 4로 내려 변환한 뒤 실행하는 방식은 사용하지 않는다. Schema 5 전체 payload에 결속된 M3 판단·intent·context를 만들고, 기존 M4 수치 커널과 자원·건강 커널을 **Schema 5 내부 경로**에서 호출한다. 기존 공개 Schema 4 경로의 결과와 해시는 유지한다.

신뢰 경계는 기존 M4와 같은 in-process 경계다. `M5OperationScope`는 facade가 생성·소유하고 외부 JSON으로 decode하지 않는 실행 중 객체다. Scope의 실제 객체 소유권과 결속을 검사하며 hash를 소유권 증명으로 사용하지 않는다. 임의 코드를 같은 프로세스에서 실행하는 공격자까지 격리하는 보안 capability라고 주장하지 않는다.

scope의 의미 필드는 `operation_kind`, `input_state_hash`, `input_day_index`, `input_resolution_epoch`, `input_social_revision`다. scope_id는 `H({algorithm_id:"m5-operation-scope-v1",위의 다섯 필드})`다. 원본 payload와 deep clone을 내부에서 보유하고, 준비 단계가 끝나면 commit 또는 폐기한다.

### 6.2 API 분리

| 경로 | 계약 |
|---|---|
| `StateValidator.validate_world`의 Schema 5 분기 | 항상 전체 publishable 불변식. `allow_pending` 같은 caller 옵션 없음 |
| `StateHasher.hash_world`의 Schema 5 분기 | publishable 검증을 통과한 payload만 hash. 실패는 빈 문자열이며 validator 진단은 호출 진입점이 보존 |
| `StateCodec` Schema 5 encode/decode | 공개 검증을 통과한 세계만 저장·복원 |
| `M5StageBoundary._validate_after_resolution(scope,stage,batch)` | 해당 scope의 M4 중간 상태만 내부 검증 |
| `M5StageBoundary._validate_after_day_resources(scope,stage,day_result)` | 해당 scope의 자원·날짜 중간 상태만 내부 검증 |
| `M5StageBoundary._hash_stage(scope,stage_kind,stage)` | 아래 domain으로 내부 hash. 공개 state hash로 반환하지 않음 |

현재 StateValidator가 StateHasher.state_payload를 통해 자신을 검증하는 호출 구조에 유의한다. 새 public hash에서 validator를 부를 때 재귀가 생기지 않도록 **payload 구성 → 구조 검증 → 공개 불변식 → hash**를 분리한다. raw payload builder는 hash·검증을 호출하지 않는 내부 helper다.

deep clone은 schema-aware typed 복제 또는 내부 payload/from_data로 수행한다. 중간 세계를 일반 save envelope로 encode/decode해 복제하지 않는다. public codec을 우회하기 위한 `validate=false` 옵션을 만들지 않는다.

### 6.3 정확히 허용되는 중간 상태

입력 세계의 값을 `d`, `e`, `r`로 놓는다.

| 대상 | world.day | resolution epoch | integrated epoch | revision | last_closed | 접촉일 |
|---|---:|---:|---:|---:|---:|---:|
| 행동 입력 | d | e | e | r | d-1 | d-1 |
| 내부 `AFTER_RESOLUTION` | d | e+1 | e | r | d-1 | d-1 |
| 행동 최종 | d | e+1 | e+1 | r+1 | d-1 | d-1 |
| 종료 입력 | d | e | e | r | d-1 | d |
| 내부 `AFTER_DAY_RESOURCES` | d+1 | e | e | r | d-1 | d |
| 종료 최종 | d+1 | e | e | r+1 | d | d |

두 중간 상태 모두 일반 검증·저장·M3·새 서비스 입력에서는 거부한다. 공개 반환되는 최종 상태에는 중간 상태 flag나 scope를 저장하지 않는다.

AFTER_RESOLUTION에서는 원본 대비 다음 변화만 허용한다.

1. 기존 M4 규칙이 확정한 store quantity와 resource counter·sequence.
2. resolution_epoch의 정확히 +1과 처리한 슬롯의 추가.
3. 기존 M4 커널이 허용한 나머지 물리적 변경만 허용하며, 현재 A00/A04/A11에서는 위 항목 외 변화가 없다.
4. social_state 전체, 사건·인식·기억·압력·반복·관계·인물 감정은 원본과 동일해야 한다.

AFTER_DAY_RESOURCES에서는 기존 DayProcessor의 소비·hunger·health·severe_hunger_days·관련 resource counter, 날짜+1, resolved slots 초기화만 허용한다. social_state와 사회적 상태는 입력과 동일하다. 기존 건강 알고리즘은 새로운 사망 판정을 추가하지 않는다.

공통 구조·참조·규칙 hash·수량 범위·자원 보존·counter 검증은 두 내부 상태에서도 완화하지 않는다. 날짜·정리 경계에 종속된 사회적 불변식만 해당 scope의 입력 기준으로 검사한다. 중간 단계에서 아직 실행하지 않은 일일 기억 정리까지 끝났다고 요구하지 않는다.

### 6.4 해시 domain과 결속 순서

```text
public_state_hash = H(schema5_payload)

stage_hash = H({
  algorithm_id: "m5-stage-state-v1",
  scope_id: scope.scope_id,
  stage_kind: "AFTER_RESOLUTION" 또는 "AFTER_DAY_RESOURCES",
  payload: complete_schema5_stage_payload
})
```

Schema 5 내부 M4 batch의 input_state_hash는 public 입력 hash다. output_state_hash는 AFTER_RESOLUTION stage hash다. 기존 M4 batch의 숫자·outcome hash 구조는 유지하지만, 이것을 Schema 4 exact artifact와 같은 실행 결과라고 부르지 않는다. Schema 5 상위 artifact에는 input public hash, stage hash, 최종 public hash를 서로 다른 필드에 넣는다.

검사 순서는 입력 결속 → M4 처리 → stage 구조·허용 delta 검증 → stage hash 계산 → M4 batch hash 확정 → seed/outcome/intent/context 역참조 검증 → 사회적 반영 → 최종 검증·public hash다. batch hash를 stage payload 안에 넣지 않으므로 해시 순환이 없다.

M4 결과가 A00·INVALIDATED뿐이어서 사건이 0개여도 integrated epoch와 revision을 완료 값으로 올린다. REJECTED는 epoch·revision 모두 그대로다. M5 후반 실패 시 stage clone, 할당한 ID, 영수증, 자원 transaction을 모두 폐기한다.

### 6.5 경계 벡터

| 입력/고장 | 내부 검증 | 공개 검증·저장 | 전체 결과 |
|---|---|---|---|
| e=0, integrated=0 → 정상 A00 stage e=1, integrated=0 | PASS | 거부 | 최종 두 값 1, 사건 0 |
| 같은 stage를 새 M3·contacts·close에 제출 | 진입 권한 없음 | 거부 | 원본 불변 |
| stage의 e=2, integrated=0 | 거부 | 거부 | 실패 |
| stage의 social revision을 먼저 +1 | 거부 | 단독 공개조건과 무관하게 내부 delta 실패 | 실패 |
| 정상 day stage d=0→1, last_closed=-1 | PASS | 거부 | 최종 last_closed=0 |
| 정상 stage 해시 계산 후 quantity 1 변경 | 결속 거부 | 거부 | 실패 |
| 사건·관계 계산 후 counter overflow 또는 잘못된 memory 링크 | 앞단은 통과 가능 | 최종 거부 | M4 자원 이전까지 미공개 |

이 표와 7절의 원자성 assertion이 D26-R01의 설계상 해결안이다. 실제 native Schema 5 경로의 실행 검증은 구현 후 M5-T01·T17·T18의 필수 게이트다.

## 7. 오류·원자성·counter 보호

먼저 자료형·exact keyset을 검증하고, 안전하게 참조 가능한 데이터에서만 후속 검사를 수행한다. 오류는 18.3절의 exact 대표 진단 한 개를 반환한다. 아래 순위가 작을수록 먼저 선택하며 동일 code는 `field_path`, `entity_id`, `cause_code` 오름차순으로 선택한다. 배열 입력 순서를 오류 우선순위로 사용하지 않는다.

| 순위 | 대표 code | 예 |
|---:|---|---|
| 0 | `M5_INVALID_WORLD_TYPE` | WorldState 아님 |
| 10 | `M5_UNSUPPORTED_SCHEMA` | 공개 M5에 Schema 4 제출 |
| 20 | `M5_FIELD_CONTRACT` | 필수 counter 누락, 키·정수 토큰·자료형 오류 |
| 30 | `M5_RULESET_MISMATCH` | manifest·simulation·권한 component 불일치 |
| 40 | `M5_WORLD_NOT_PUBLISHABLE` | 미통합 epoch, 정리일 불일치, 기본 구조·참조 오류 |
| 50/51/52 | `M5_STALE_DAY` / `M5_STALE_REVISION` / `M5_STALE_STATE_HASH` | stamp 불일치 |
| 60/61/62 | `M5_ACTIONS_CLOSED` / `M5_CONTACT_ALREADY_PROCESSED` / `M5_CONTACT_REQUIRED` | 날짜 내 순서 위반 |
| 70 | `M5_REQUEST_CONTRACT` | 자기 접촉·중복·죽은 인물·사람당 4명 접촉 |
| 80 | `M5_M4_REJECTED` | 기존 M4 reason·action_instance_id를 진단에 그대로 보존 |
| 90 | `M5_ARTIFACT_BINDING` | 입력·출력 hash, epoch, seed/outcome/context 역참조 오류 |
| 91 | `M5_OBSERVATION_CONTRACT` | 금지 필드·알 수 없는 payload·직접 역할 불일치 |
| 100 | `M5_ARITHMETIC_OVERFLOW` | 할당할 counter·revision·epoch·날짜 overflow |
| 110 | `M5_POST_APPLY_INVARIANT` | 최종 보존·역참조·상한·hash 실패 |

위 표는 같은 검증 단계에 수집된 후보의 선택 규칙이다. 실행하지 않은 미래 단계의 가상 오류를 먼저 찾으려 하지 않는다. 예를 들어 request contract를 검사하기 전 stale day에서 실패했다면 M4를 실행하지 않는다. M4 내부 대표 reason 우선순위는 결정 24 그대로다.

모든 실패에서 `H(original_world)` 전후 일치, 원본 객체의 컬렉션·nested dictionary 불변, next_ids·sequence·epoch·revision 불변, next_world=null, 공개 transaction=[]를 함께 확인한다. 오류 진단을 objective EventRecord나 NPC 기억으로 생성하지 않는다.

## 8. A04·A11 관찰 payload

| origin_view | 직접 소유자 | exact payload 키 | 비밀 |
|---|---|---|---|
| aid_requester | 요청자 | requester_person_id, responder_person_id, requested_units, response_decision, actual_units | false |
| aid_responder | 응답자 | 위와 같음 | false |
| theft_self | 절도 시도자 | actor_person_id, store_id, actual_units | true |
| theft_witness | 유효 seed 소유자 | actor_person_id, store_id, took_goods | false |

A04의 response_decision은 `GRANT_FULL`, `GRANT_PARTIAL`, `REJECT` 중 하나다. requested_units는 1..10, actual_units는 0..requested_units다. REJECT이면 actual_units=0이다. 제공 응답인데 actual_units=0인 경우는 허용한다. 승인량·효용·reserve·상대 재고는 payload에 없다.

A11 self의 actual_units는 0..10이며, witness의 took_goods는 `actual_units>0`을 좁게 투영한 bool이다. 실패한 시도도 목격할 수 있다. witness에게 actual_units·trace_created·notice_score·다른 witness 목록·가족 보호 의도를 전달하지 않는다. 자기 경험에도 unseen witness 목록과 실제 보안은 없다.

객관적 seed의 `trace_created=true`는 TraceState를 만들 수 있지만 어떤 사람의 자동 관찰을 만들지 않는다. A04 비당사자도 자동 관찰하지 않는다. 같은 가구의 다른 사람이 기존 M3의 자기 식량 입력으로 반응하는 것은 계속 허용한다.

관찰 생성은 M4 facade가 내부에서 발행한 실제 batch와 scope에 한정된다. 외부 caller가 위 payload를 조립해 공개 API에 넣는 기능은 없다. 부록의 frozen M4 projection 벡터는 **내부 projector 단위 검증용 원문 결속**이며, runtime authority가 아니다.

## 9. 보고 병합·수용·충돌

### 9.1 하나의 사건을 하나의 반응 묶음으로

수신 후보를 `(owner,event)`로 모으고 기존 observation과 비교한다. 처음 수신이면 first_learned=d다. 같은 pass에서 여러 사람이 말해도 수신일은 한 번 정하고 confidence를 합산하지 않는다.

보고의 비교 순위는 `(직접=2/전언=1, occurred_day_index, confidence)` 내림차순이다. 동일 사건의 정상 보고는 발생일이 같으므로 습득일이 최신이라는 이유로 우선하지 않는다. 전달받은 날짜는 순위에 사용하지 않는다.

aid 두 origin_view는 동일 payload 의미로 비교한다. theft_self와 theft_witness는 서로 공통으로 아는 actor·store·took_goods로 비교한다. self의 took_goods는 그 사람이 가진 actual_units>0에서만 도출한다. 알지 못하는 수량을 반대로 복원하지 않는다.

동순위의 호환되는 보고는 내용이 더 구체적인 보고를 선택하고, 같은 내용이면 depth가 작은 것, original_source ID·current_source ID·payload hash 오름차순으로 하나를 고른다. 여기까지 동률이면 9.3절 report 원문의 H, canonical JSON UTF-8 bytes 순으로 비교해 전체 필드를 하나로 확정한다. 이 ID 동률 규칙은 서로 다른 내용을 참으로 판정하는 데 사용하지 않는다.

구체성 순위는 theft_self=2, theft_witness=1, 두 aid view=1이다. theft_self와 witness의 비교는 내부 projector/aggregator의 의미 비교 규칙이며, 비밀 자기 경험을 실제로 전송할 수 있다는 뜻은 아니다. 동순위 충돌은 구체성 순위로 진위를 선택하기 전에 판단한다.

### 9.2 상반된 보고

- 동순위 최상위 보고들이 서로 모순되며 기존 수용 내용도 없다면 accepted=false, conflicted=true다. 대표 payload와 출처는 9.3절의 보관 정렬로 정하며, 믿음·변화·발신에 사용하지 않는다.
- 기존 수용 내용과 동순위의 반대 보고가 오면 기존 내용·confidence를 유지하고 conflicted=true로 둔다. 이 표시는 기존 내용의 철회가 아니다.
- 기존 것보다 엄격히 높은 순위의 일관된 보고가 있으면 현재 내용을 교체할 수 있다. 이미 영수증이 있으면 관계·감정·기억·학습·압력은 재적용하지 않는다.
- 기존보다 낮은 반대 보고는 현재 내용을 덮지 않는다. 새 전언 때문에 기존 confidence를 반복 감소시키지 않는다.
- 최초 수용은 직접 경험 또는 confidence>=60인 일관된 전언에 한정한다. 수용하기 전 모든 사회적 delta는 0이다.
- 한 번 수용된 observation의 accepted는 v0.2에서 true로 유지한다. 체계적인 철회·관계 복구 모델은 구현하지 않는다.

conflicted=true는 저장·재개 후에도 보존되는 충돌 장벽이다. 보관한 observation의 순위가 그 장벽의 기준이다. 같은 순위나 낮은 순위의 내용을 다시 들었다는 이유로 flag를 지우거나 최초 수용을 발동하지 않는다. **기준보다 엄격히 높은 순위의 일관된 근거**가 들어온 경우에만 장벽을 해소한다. 따라서 같은 confidence 80의 반대 보고 두 개 → 한쪽 80 재청취는 계속 미수용이고, 일관된 90의 새 최선 근거가 들어올 때 최초 수용한다. 대표 payload 한 개만 남기면서 반대 보고의 존재를 잊는 문제를 이 보수적인 규칙으로 막는다.

같은 원천의 호환되는 여러 경로는 최선 보고 하나로 축약한다. 동순위 모순 여부는 이 축약 전에 판정해 같은 원천에서 온 반대 보고도 없었던 것으로 만들지 않는다. 다른 원천도 confidence 합산을 하지 않는다. 관측된 실제 정답을 조회해 상충을 해결하지 않는다.

핵심 경계 벡터는 `동순위 반대 두 보고 → 미수용`, `기존 수용 + 동순위 반대 → 기존 유지`, `거부 confidence 59 → 다음 날 일관된 60 수신 → 최초 효과 1회`, `그 후 직접 100 → 출처 개선·효과 0회`다. 같은 사건이 주장이 여러 개인 것처럼 쪼개져도 영수증은 하나다.

### 9.3 미수용 보고의 보관 대표 — B02

`report`의 exact 11키는 `owner_person_id,event_id,occurred_day_index,acquisition_type,origin_view,original_source_person_id,current_source_person_id,depth,confidence,is_secret,payload`다. 수신·집계 전 각 후보에서 이 키만 추출하며, 저장 observation의 id·날짜·수용 flag·importance를 report hash에 섞지 않는다.

기존 수용 내용이 없는 동순위 최상위 모순 그룹에서 다음 tuple이 **가장 작은 report 하나**를 보관한다. 각 숫자는 정수 비교, 문자열은 사전 오름차순, 마지막 canonical JSON은 UTF-8 byte 사전순이다.

```text
(depth,
 original_source_person_id,
 current_source_person_id,
 H(report),
 canonical_json(report))
```

마지막 항목은 앞의 hash까지 같은 경우도 원문으로 확정하기 위한 것이다. 전체 원문까지 같으면 같은 보고이므로 어느 복제본을 골라도 동일하다. 이 정렬에는 사실 여부·사회적 효과의 우선권이 없다. 선택한 report의 11개 필드를 모두 그대로 복사하고 나머지 observation 필드를 다음처럼 정한다.

| 필드 | 처음 수신한 모순 그룹 | 기존 미수용 충돌 장벽의 동순위 재수신 |
|---|---|---|
| id | 4.2절 `(owner,event)` 파생 ID | 기존 값 유지 |
| first_learned_day_index | 현재 수신일 d | 기존 값 유지 |
| first_accepted_day_index | -1 | -1 |
| accepted / conflicted / importance | false / true / 0 | false / true / 0 |
| report의 11필드 | 최상위 모순 그룹의 최소 보관 tuple | 기존 대표와 같은 순위 신규 보고를 합친 최소 tuple |

낮은 순위 보고는 장벽·대표를 변경하지 않는다. 엄격히 높은 순위의 새 최상위 그룹도 모순이면 그 그룹의 최소 tuple로 대표·장벽 순위를 갱신하고 미수용을 유지한다. 엄격히 높은 순위의 일관된 근거만 9.2절에 따라 장벽을 해소한다. 기존 accepted=true인 내용의 유지·교체는 9.2절을 그대로 적용하며 이 미수용 정렬로 수용 내용을 덮지 않는다.

`blocker_vectors.B02`는 confidence 80·depth 1의 `took_goods=true`(원천 person 1)와 `false`(원천 person 4)를 반대 순서로 넣는다. 두 경로 모두 원천 person 1의 report를 **미수용 보관 대표**로 저장한다. first_learned=1, first_accepted=-1, accepted=false, conflicted=true, importance=0과 전체 payload·출처까지 같은 observation 원문/H를 제공한다. 한쪽을 같은 순위로 다시 들어도 전체 observation과 효과 0회가 유지된다. 이 fixture는 내부 집계기 검증용이며 외부 보고 주입 API가 아니다.

## 10. 접촉과 전언 수치

### 10.1 접촉 검증과 snapshot

하루 1 pass, 사람당 서로 다른 상대 최대 3명이다. 빈 plan도 성공하면 해당 날짜 접촉을 마친다. 입력 pair 배열·중복·a<b·ID·살아 있는 사람 참조를 먼저 검증한다. 실행 결과에 따라 중간에 접촉을 더 생성하지 않는다.

pass 시작 snapshot에서 모든 발신 후보·수용 신뢰·평가 delta를 계산한다. 이번 pass에서 들은 내용이나 바뀐 관계는 같은 pass의 발신과 confidence 계산에 사용하지 않는다. A→B와 B→C가 같은 pass에 있어도 B가 처음 들은 사건은 C에게 가지 않는다.

### 10.2 발신 선택

발신자는 accepted인 자기 observation만 후보로 사용한다. secret=true, depth>=3인 것은 제외한다. 다음 중 하나를 만족해야 한다.

1. `0 <= current_day - first_learned_day <= 13`.
2. 그 observation에 연결된 중요·핵심 기억이 현재 남아 있음.

최근 기억이 없어져도 판단용 belief의 provenance가 남는다는 이유만으로 정확한 과거 대화를 일반 전언으로 복원하지 않는다. 최근 접촉·재수신은 발신 가능 기간을 연장하지 않는다.

각 방향 sender→receiver에 대해 sender의 관계·감정으로 계산한다.

```text
bond = floor((trust + affection + obligation) / 3)
threat = floor((relation.fear + resentment) / 2)
relevance = 20 if receiver가 허용 payload에 명시된 인물 else 0
share_score = importance + bond + relevance - threat - floor(sender.emotion.fear/2)
```

share_score>=20인 후보를 점수↓, importance↓, first_learned↓, observation ID↑로 정렬해 한 방향 최대 2개를 전한다. relation 방향은 sender→receiver다. 원시 정보원의 숨은 감정을 수신자에게 넘기지 않는다.

### 10.3 수신 confidence

수신자는 snapshot의 **receiver→sender trust**를 사용한다.

```text
loss = 10 + floor((100 - trust) / 5)
receiver_confidence = max(0, sender_confidence - loss)
receiver_depth = sender_depth + 1
```

직접 경험 confidence=100이다. 수용 threshold는 60이다. 신뢰 0/50/100에서 첫 전언은 각각 70/80/90이다. 신뢰 50을 연속해서 쓰면 100→80→60→40이며 세 번째 전언은 수신 기록만 남는다. 신뢰 100에서는 100→90→80→70까지 가능하고 depth=3에서 발신을 멈춘다.

손실은 항상 10 이상이므로 양의 confidence의 추가 전달이 확신을 높이지 않는다. 관계가 없으면 trust=0, 첫 전언 70이라는 수용 가능한 기본값을 적용한다. 미수용의 현재 보고는 발신 후보가 아니다.

## 11. 도움 기대와 M3 환류

A04 요청자가 실제 경험한 한 사건을 최초 수용할 때만 해당 응답자에 대한 `request_success_expectation`을 갱신한다.

```text
y = RD(100 × actual_units, requested_units)
기존 fact 존재: b_new = RD(3 × b_old + y, 4)
                 c_new = min(100, c_old + 10)
기존 fact 부재: b_new = y, c_new = 80
```

이는 그 상대에게서 필요한 만큼 도움받을 것이라는 자기 기대의 학습값이다. 객관적인 성공 확률을 알아낸 수치가 아니다. 동일 fact ID의 현재 출처만 최신 직접 경험의 linked_event_id·source_observation_id·learned_day_index로 바꾸고 acquisition_type=`direct_interaction`, 두 source person=owner, is_secret=false, claim=`m5:request_success_expectation`으로 한다.

이 fact를 참조하는 기존 legacy memory의 linked_event_id·occurred_day_index·first_learned_day_index·인식 내용은 변경하지 않는다. 저장·복원도 현재 fact로부터 과거 기억을 재구성하지 않는다. 따라서 `memory→event:000001`, `information→event:000002`는 같은 owner와 유효한 두 사건 참조를 가진 정상 상태다. 16.5절의 B01에서 이를 전체 payload로 확인한다.

소문을 들은 제3자와 응답자는 이 fact를 갱신하지 않는다. 다른 필수 fact인 접근·재고 능력·위험·권위자 정보를 만들어 주지 않는다. 현재 유일키 `(owner,fact_type,subject)`를 유지한다. 하나의 batch에서 이 유일키를 갱신할 직접 경험이 둘 이상이면 현재 daily slot 계약 위반으로 거부하며 순서대로 두 번 학습하지 않는다.

| old b/c | requested/actual | y | new b/c |
|---|---|---:|---|
| 50 / 80 | 10 / 10 | 100 | 63 / 90 |
| 50 / 80 | 10 / 5 | 50 | 50 / 90 |
| 50 / 80 | 10 / 0 | 0 | 38 / 90 |

제공 응답 후 0 지급도 체감 도움은 0이므로 y=0이다. 다만 12절의 관계·분노 처리는 명시적 거절과 다르다.

현재 M3는 `effective = RD(belief×confidence,100)`을 읽고 A04의 M을 capacity effective와 success effective의 최솟값으로 계산한다. 위 full grant에서 success effective는 40→57이다. capacity effective=48을 고정하면 M은 40→48, M 항목만의 utility_scaled 차이는 +80이다. 이는 전체 효용·최종 선택의 변화량이 아니다. 실제 관계와 fear 변화의 R·K 효과는 따로 보고한다.

환류 대조군은 물리적 세계·날짜·M3 seed를 같게 두고 사회적 필드만 바꾼다. memory/event 자연어를 직접 M3 입력으로 추가하지 않는다. norm이 69→71로 바뀌면 직무 역할 없는 A11의 C는 현재 공식에서 46→47이다. fear는 현재 K 공식의 입력이며 anger·guilt는 현재 M3의 직접 효용 항목이 아니다.

## 12. 관계·감정·기억 중요도 수치

### 12.1 적용 공통 규칙

표의 delta는 최초 수용 1회만 적용한다. 생략한 축은 delta=0이다. 개인 감정과 관계의 fear는 다른 필드다. 관계 target이 owner 자신이면 관계 delta를 만들지 않는다. 전언 수신자가 원래 당사자여도 직접 당사자 해석을 다시 발동하지 않는다.

기존 관계가 없으면 다섯 값 0에서 계산한 후 실제로 0이 아닌 최종 값이 있는 경우에만 생성한다. 예컨대 trust -2만 생겨도 0→0이면 새 관계가 필요 없다. resentment +1이 함께 생기면 그 방향 관계를 만든다. 반대 방향은 자동으로 만들지 않는다.

### 12.2 A04

| 경험 | 관계 owner→상대 | 개인 감정 | 중요도 |
|---|---|---|---:|
| 요청자, actual>0 | trust +4, affection +2, obligation +3, resentment -1을 각각 y/100 배율로 RD | fear -4, anger -2를 y/100 배율로 RD | 40 |
| 요청자, REJECT, 실행 전 N<60 | trust -1, resentment +1 | fear +1, anger +1 | 45 |
| 요청자, REJECT, 실행 전 N>=60 | trust -2, resentment +3 | fear +2, anger +3 | 45 |
| 요청자, GRANT 응답·actual=0 | 없음 | fear +1 | 40 |
| 응답자, actual>0 | 요청자에 대한 affection +1 | 없음 | 35 |
| 응답자, actual=0 | 없음 | 없음 | 20 |
| 수용한 전언 | 없음 | 없음 | RD(30×confidence,100) |

N은 검증된 요청자의 실행 전 M3 선택 후보의 food pressure다. 응답자가 실제로 곤궁했다는 이유를 만들어 내지 않는다. 다른 사람의 도움 이야기를 들으면 현재 버전에서는 인식·기억만 생기고 평판 점수를 일반화하지 않는다.

actual=5/requested=10이면 요청자의 delta는 trust +2, affection +1, obligation +2, resentment -1, fear -2, anger -1이다. 음수 절반 반올림도 공통 RD를 따른다.

### 12.3 A11 직접 자기 경험

검증된 선택 후보의 N·K·C와 자기 성향만 사용한다. C>=40이면 guilt +3, 그 외 guilt 변화 0이다. fear는 `+RD(K,20)`이다. 중요도는 `50 + 20×[C>=40] + 10×[K>=60]`다. 자기 경험은 secret=true이며 새 타인 관계 delta는 없다. 성공 여부만으로 성향 점수를 떨어뜨리지 않는다.

### 12.4 A11 목격·수용한 전언

소유자의 norm과 property_autonomy를 읽는다.

```text
q = 1 + [norm_adherence >= 50] + [property_autonomy >= 50]
```

직접 목격자는 행위자에 대한 trust `-2q`, resentment `+q`를 받는다. took_goods=true이면 관계 fear +1이다. 개인 anger +q, took_goods=true이면 개인 fear +1이다. 중요도는 `50+10q`다.

전언 수신자는 위 delta 각각에 `confidence/200`을 곱해 RD하고, 중요도는 직접 중요도×confidence/100을 RD한다. 어떤 경우에도 그 수신자의 성향 압력은 만들지 않는다. `q=3, confidence=70, took_goods=false`이면 trust -2, resentment +1, anger +1, 중요도 56이다.

피해자 가구, 가족 보호 동기, 실제 잔량을 읽어서 평가를 완화하거나 강화하지 않는다. 이 버전은 좁은 규칙으로 동일 관찰을 다르게 평가하는 최소 경로를 검증한다. 가치관 전체의 풍부한 해석을 구현했다고 주장하지 않는다.

## 13. 경험 맥락·규범 압력·반복 감쇠

### 13.1 내부 ExperienceContext

exact 필드는 actor_person_id, action_instance_id, decision_hash, norm_adherence, family_protection, N, K, C, voluntary다. M4 호출 전 검증된 선택 candidate와 실제 자기 상태에서 만든다. voluntary=true인 현재 자율 M3 선택만 지원한다. 자기 성향·가치 누락은 0과 default 경로를 기록한다.

이 context는 감사 artifact에만 남겨도 된다. 사회적 통합이 끝나면 미래 주간 처리에 필요한 것은 명시적 pressure와 repeat state다. 미래에 audit를 다시 읽어 압력을 계산하지 않는다. 외부 caller가 임의의 N·K·C나 “큰 희생”을 제출하는 API는 없다.

### 13.2 압력 표

압력의 유효 입력은 `RESOLVED/A11`의 직접 행위자 경험이다. A00·INVALIDATED·전언·목격·현재 A04에서는 0이다.

1. C<40이면 규범 충돌이 약한 사소한 경험으로 pressure=0.
2. 그 외 기본 magnitude=`1+[K>=40]+[C>=60]`, 즉 1..3.
3. K>=60, C>=60, N>=80을 모두 만족하면 magnitude=4. 기존 4..8 허용 범위의 최소값만 사용한다.
4. N>=60이고 family_protection>=norm_adherence+20이면 sign=-1(`survival_justification`), 그 외 sign=+1(`norm_reaffirmation`).
5. K<40이면 아래 저위험 반복 감쇠 후 sign을 적용한다. K>=40이면 감쇠 없이 적용한다.

압력은 선택과 자기 규범 충돌에 대한 좁은 해석이다. 실제 받은 물건의 양만으로 sign을 결정하지 않는다. 동일 N·K·C·자기 가치에서 성공·실패만 바꾸면 이 버전의 pressure는 같아야 한다. 죄책감 상승과 음의 장기 압력이 함께 생길 수도 있다. 감정과 자기합리화를 같은 축으로 합치지 않는다.

예: N=80,K=20,C=60,norm=70,family=95이면 base magnitude=2, sign=-1이다. 최초 저위험 경험은 -2, 다음 유사 저위험 경험은 -1이다. N=80,K=60,C=60,norm=70,family=80이면 +4다. 두 예 모두 trait score는 행동 직후 바뀌지 않는다.

### 13.3 반복 key와 7일 구간

key는 `(actor,A11,norm_adherence)`이며 target·action ID·memory ID는 포함하지 않는다. 현재 d의 저위험·의미 있는 경험(C>=40,K<40) 처리 전, 기존 low_risk_days 중 `d-6 <= day <= d`인 날짜만 센다. 현재 정상 slot에서는 동일 사람의 오늘 기록이 아직 없어야 한다.

prior count가 0/1/2이면 divisor=1/2/4, 3 이상이면 압력 0이다. `attenuated=floor(magnitude/divisor)`이고 최소 1로 끌어올리지 않는다. 0이 나온 경험도 현재 날짜를 목록에 추가한다. 대상만 바꾸어 감쇠를 우회할 수 없다.

하루 종료 후 다음 날을 위해 `<(d+1)-6`인 날짜를 제거한다. 의미 있는 저위험 경험 날짜만 저장하며 최대 7개다. 고위험·사소한 경험은 이 목록을 늘리지 않는다. 기억 압축은 이 목록을 변경하지 않는다.

base=3의 연속 경험은 3,1,0,0…이다. d=0 기록은 d=6까지 count에 포함되고 d=7의 실행 전에는 제외된다. 이것은 7일 창을 명시한 정책이며 하루나 target을 바꿀 때마다 초기화되는 정책이 아니다.

## 14. 주간 정리와 감정의 하루 종료

### 14.1 원점과 한도

주차는 `week(d)=floor(d/7)`이다. `(d+1)%7==0`인 6·13·20·27…일 종료에 그 주차를 정리한다. 정리한 마지막 주차는 -1로 시작한다. 여러 날 건너뛰는 close와 같은 주차의 중복 정리를 허용하지 않는다.

각 norm 압력 P에 대해:

```text
requested_delta = clamp(TD(P,5), -2, 2)
new_score = clamp(old_score + requested_delta, 0, 100)
actual_delta = new_score - old_score
remaining_pressure = P - 5 × actual_delta
```

변화하지 못한 delta의 압력을 차감하지 않는다. weekly 내부 커널도 last_settled_week+1과 대상 주차의 결속을 검사한다. 일일 wrapper 실패 시 변경 전 주차·압력을 유지한다. risk_taking·empathy·self_control·가치관은 이번 버전에서 갱신하지 않는다.

| score / P | actual delta | 다음 score / P |
|---|---:|---|
| 50 / 4 | 0 | 50 / 4 |
| 50 / 5 | +1 | 51 / 0 |
| 50 / 11 | +2 | 52 / 1 |
| 50 / -11 | -2 | 48 / -1 |
| 99 / 11 | +1 | 100 / 6 |
| 100 / 11 | 0 | 100 / 11 |
| 1 / -11 | -1 | 0 / -6 |

### 14.2 일일 감정 정리

자원·hunger·health 진행 후, 완료일 d를 인자로 받은 사회적 정리에서 fear는 2, anger는 3, guilt는 1씩 0 방향으로 감소시킨다. 다른 감정은 유지한다. 없는 key를 단지 감쇠하기 위해 새로 0으로 채우지 않는다. 기존 key가 0이 되어도 삭제하지 않는다.

같은 종료 안에서는 감정 감쇠 → 주간 압력 변환(해당일) → 기억 tier·상한 정리 → 반복 날짜 prune → 정리 stamp 확정 순서다. 이 정리는 자원·건강·날짜를 직접 변경하지 않는다. 기존 DayProcessor 커널을 담당하는 wrapper만 날짜를 한 번 증가시킨다.

## 15. 기억·압축·상태 크기

### 15.1 기억 생성

최초 수용 시 memory 하나를 만든다. 미수용은 observation만 남고 memory는 없다. 한 사건을 여러 보고로 들었다고 memory를 여러 개 만들지 않는다. perceived_action_id는 A04 또는 A11이다.

- A04 result: `aid_received` / `aid_refused` / `aid_offered_zero` / `aid_given` / `aid_response_zero` / `aid_report`를 12절 역할 표에 따라 부여한다.
- A11 result: 직접 자기 경험은 `attempt_with_gain` 또는 `attempt_without_gain`, 목격은 `witnessed_attempt_with_goods` 또는 `witnessed_attempt_without_goods`, 전언은 `theft_report`다.
- related_person_ids는 payload에 실제 명시된 사람만, owner를 제외하고 정렬한다.
- emotion_scores는 최초 반응의 비음수 감정 강도를 기록한다. 양의 감정 delta는 그 값, 감소 delta는 0이며 0인 key는 넣지 않는다. 개인 감정의 절대값이나 signed delta를 이 필드에 저장하지 않는다.
- occurred_day_index는 관측된 사건일, first_learned_day_index는 observation의 첫 수신일, core_eligible=false다.

### 15.2 나이와 tier

완료한 날짜 d에서 `age=d-first_learned_day_index`다. 최근 기억은 `0<=age<=13`이면 유지 대상이고 `age>=14`이면 최근 자격이 없다. 행동·접촉 직후처럼 아직 오늘을 정리하지 않은 공개 상태의 validation age는 `max(0,last_closed_day_index-first_learned_day_index)`다. 오늘 새로 얻은 기억을 음수 나이로 거부하지 않는다.

| tier | 자격 | cap |
|---|---|---:|
| core | core_eligible=true인 선언된 기존 기억 | 8 |
| important | importance>=70 | 24 |
| recent | 위에서 유지되지 않았고 최근 나이 조건 충족 | 64 |

각 사람의 기억 전체를 importance↓, first_learned↓, ID↑로 정렬한다. core 자격자 중 8개를 먼저 유지하고, 남은 important 자격자 중 24개, 남은 recent 자격자 중 64개를 유지한다. 상위 cap에서 밀린 기억도 하위 자격을 만족하면 내려올 수 있다. 어느 tier 자격도 없으면 압축한다. 기존 core 여부는 명시적 core_eligible로 보존하며, 단지 중요도가 높다는 이유로 A04·A11을 새 정체성 핵심 기억으로 만들지 않는다.

모든 성공한 공개 작업의 끝에서 cap을 적용한다. close에서는 완료일 d의 나이로 만료도 적용한다. 따라서 공개 세계에서 일시적으로 96개를 초과한 기억을 반환하지 않는다. 인식이 업그레이드돼도 이미 생성한 memory의 importance·날짜·내용을 다시 평가하지 않는다.

### 15.3 압축의 정확한 효과

압축은 memory 삭제, person.memory_ids 제거, effect_receipt.memory_id=""를 같은 작업에서 수행한다. legacy 기억은 영수증이 없을 수 있으므로 해당 단계만 생략한다. 관계·감정·trait score·pressure·repeat state를 더하거나 원복하지 않는다.

이미 영수증이 있는 사건은 재수신해도 memory를 재생성하지 않는다. observation과 영수증은 현재 인식·중복 방지·출처 결속을 위해 보존한다. 인식은 사건당 고정된 좁은 payload 하나이며 전체 전달 경로·M4 평가표를 계속 쌓지 않는다. 오래된 인식의 일반 전파는 10절의 기간·기억 자격으로 막는다.

### 15.4 저장량 보고

96개는 상세 memory의 인물별 최대값이다. 전체 상태 크기가 상수라는 주장은 하지 않는다. 각 commit의 audit에는 사건·흔적·인식·영수증·memory tier별 개수, 관계·압력·반복 레코드 수, canonical state UTF-8 byte 수를 보고한다. 감사 로그의 byte 수는 별도로 측정한다.

관찰자는 실제 수신한 사건에만 레코드가 생긴다. 상한을 맞추려고 영수증을 임의로 삭제하지 않는다. v0.2의 장기 저장 최적화는 이 관측값 이후 별도 결정한다.

## 16. D26-R02 — 28일 공통 연속 fixture

### 16.1 최초 세계 FCAL

부록 `FCAL_initial_payload`가 실제 원문이다. 동결 M4 F02 입력을 바탕으로 다음의 **새 fixture 초기값**을 선언했다. 기존 저장 파일을 실행 도중 수정하는 작업이 아니다.

- schema=5, day=0, legacy 사건·fact의 날짜=0, social 초기 stamp와 추가 컬렉션 설정.
- 인물·가구·재고·관계·기존 fact는 F02 유지. 첫 행동은 한결(person:000001)의 A04이며 요청·지급 10, GRANT_FULL이다. M3 구성요소는 기존 F02의 N=54, K=18, C=0이고 deterministic_margin을 유지한다.
- person:000002의 초기 fear=0은 늦은 전언 벡터를 단순하게 하는 fixture 값이다.
- person:000003의 norm=35, 초기 norm pressure=11은 주간 이월 확인용 **fixture seed**다. 게임 실행으로 이 압력을 발생시켰다는 주장이 아니다.
- 두 가구의 시작 식량은 15·60, 공동창고 80이다. 첫 A04 후 25·50·80이다. 일일 필요량은 각 가구 5·2다.
- 첫날 이후에는 목표가 없는 person:000003의 A00만 명시적으로 실행한다. 다른 인물의 행동을 자동 생성하지 않는다.

실제 native 실행 시험에서는 날짜·Schema 5 입력 hash에 맞춰 M3 결과·intent·context를 새로 발행한다. frozen F02의 오래된 DecisionResult나 context hash를 새 세계에 복사하지 않는다. A04의 수치 커널은 난수 없이 같은 선택·응답 값이 나오는 조건이다.

### 16.2 하루 driver

매일 action 1 batch → contacts 1 pass → close 1회를 실행한다. d=13에는 (1,4),(2,4),(2,3)을 접촉시키고 d=14에는 (2,4)를 접촉시킨다. 다른 날짜는 빈 plan이다. 숫자는 person ID suffix다.

d=0에 요청자 1과 응답자 4만 aid 인식·기억을 갖는다. d=13에 4→2 첫 전언이 confidence 70으로 수용된다. 같은 pass의 2→3은 새 전언을 재발신할 수 없어 3은 알지 못한다. 1↔4의 재청취는 first_learned=0과 기존 영수증을 유지한다.

d=14에는 오래된 직접 인식의 일반 발신 기간이 끝나 4→2 발신 후보가 없다. 2는 아직 최근 전언을 갖고 있어 2→4 전달을 시도할 수 있으나 confidence=40으로 떨어진다. 4의 기존 직접 confidence=100·최초일 0·효과는 그대로다. 늦은 전언도 순환하면 원천보다 강한 증거가 되지 않는다.

### 16.3 날짜·자원·기억 기대표

아래 표의 ‘초기 기억’은 1·4의 첫날 기억 두 개이고 ‘늦은 기억’은 2의 전언 기억이다. 날짜별 전체 scalar는 JSON `FCAL_rows`에 28행 모두 있다.

| 완료일 d | 거래 기록일(있을 때) | 반환 날짜 | 주간 정리 | 초기 기억 2개 | 늦은 기억 1개 | 총 기억 |
|---:|---:|---:|:---:|:---:|:---:|---:|
| 0 | 1 | 1 | — | 유지 | 미수신 | 2 |
| 1 | 2 | 2 | — | 유지 | 미수신 | 2 |
| 2 | 3 | 3 | — | 유지 | 미수신 | 2 |
| 3 | 4 | 4 | — | 유지 | 미수신 | 2 |
| 4 | 5 | 5 | — | 유지 | 미수신 | 2 |
| 5 | 6 | 6 | — | 유지 | 미수신 | 2 |
| 6 | 7 | 7 | YES | 유지 | 미수신 | 2 |
| 7 | 8 | 8 | — | 유지 | 미수신 | 2 |
| 8 | 9 | 9 | — | 유지 | 미수신 | 2 |
| 9 | 10 | 10 | — | 유지 | 미수신 | 2 |
| 10 | 11 | 11 | — | 유지 | 미수신 | 2 |
| 11 | 12 | 12 | — | 유지 | 미수신 | 2 |
| 12 | 13 | 13 | — | 유지 | 미수신 | 2 |
| 13 | 14 | 14 | YES | 유지 | 유지 | 3 |
| 14 | 15 | 15 | — | 압축 | 유지 | 1 |
| 15 | 16 | 16 | — | 압축 | 유지 | 1 |
| 16 | 17 | 17 | — | 압축 | 유지 | 1 |
| 17 | 18 | 18 | — | 압축 | 유지 | 1 |
| 18 | 19 | 19 | — | 압축 | 유지 | 1 |
| 19 | 20 | 20 | — | 압축 | 유지 | 1 |
| 20 | 21 | 21 | YES | 압축 | 유지 | 1 |
| 21 | 22 | 22 | — | 압축 | 유지 | 1 |
| 22 | 23 | 23 | — | 압축 | 유지 | 1 |
| 23 | 24 | 24 | — | 압축 | 유지 | 1 |
| 24 | 25 | 25 | — | 압축 | 유지 | 1 |
| 25 | 없음 | 26 | — | 압축 | 유지 | 1 |
| 26 | 없음 | 27 | — | 압축 | 유지 | 1 |
| 27 | 없음 | 28 | YES | 압축 | 압축 | 0 |

action 거래는 d=0에서 기록일 1·수량 10으로 한 건이다. A00에는 자원 거래가 없다. 소비 거래가 존재하는 날짜의 기록일도 d+1이다. 식량을 다 쓴 후에는 quantity=0 거래를 만들지 않으므로 d=25..27의 소비 거래 날짜는 null(거래 없음)이다. 실제 소비량은 첫 5일 각각 7, 다음 20일 각각 2, 마지막 3일 0이다.

총 시작 식량 155, 누적 소비 75, 마지막 세계 총 식량 80으로 보존된다. 자원 sequence는 action transaction 1개 + 소비 transaction 40개로 마지막 next_sequence=41이다. 매일 A00도 통합하므로 28일 종료 후 resolution_epoch=integrated_epoch=28, revision=84다.

첫날 습득 기억은 d=13 종료(age=13)까지 유지하고 d=14 종료(age=14)에 압축한다. d=13에 처음 들은 기억은 d=26 종료까지 유지하고 d=27 종료에 압축한다. 사건 발생일 0을 늦은 수신자의 기억 나이 원점으로 사용하지 않는다.

주간 정리는 d=6·13·20·27에 발동한다. 초기 pressure=11인 person 3은 d=6에 norm 35→37, pressure 1이 된다. 뒤의 세 주간 정리에서는 delta=0, pressure=1을 유지한다.

### 16.4 같은 fixture의 실패·재개 분기

- d=6,13,14,26 종료 직후 저장·decode한 경로와 계속 실행한 경로의 이후 canonical 세계가 같아야 한다. audit 배열을 모두 비운 재개 경로도 같다.
- d=13 첫 contacts 성공 뒤 최신 stamp로 contacts를 또 호출하면 CONTACT_ALREADY_PROCESSED다. 이전 stamp를 그대로 쓰면 STALE_REVISION이 먼저다.
- d=13 close 성공 결과(world day=14)에 이전 d=13 close stamp를 다시 넣으면 STALE_DAY다. 최신 stamp로 close를 곧장 호출하면 CONTACT_REQUIRED다.
- 미래 d=15 stamp를 world day=14에 넣으면 STALE_DAY다. 건너뛰기로 주간·기억 정리를 생략하지 않는다.
- d=14 첫 기억 삭제 뒤 그 사건을 다시 수용하는 내부 aggregator probe에서도 영수증 수·first_learned·관계·memory 수는 증가하지 않는다.
- 실패 분기는 정상 28일 경로의 기준 세계를 변경하지 않고 동일 입력에서 분기하여 검사한다.

이 최초 원문·28행 기대값·재개 지점·비교 연산자가 D26-R02의 설계상 해결안이다. JSON 행의 hash는 명세 내용 결속이며, Godot에서 측정한 28개 세계 hash가 아니다.

### 16.5 기존 기억 → A04 학습 → 저장·재개 — B01

FCAL의 기존 28행은 그대로 둔다. 별도 `blocker_vectors.B01`은 FCAL 최초 payload에 한결의 legacy `memory:000001`을 추가하고 memory counter를 2로 선언한다. memory와 `information:000003`의 초기 사건은 모두 `event:000001`이다. 기존 과거 기억은 importance=45, tier=recent, 첫 습득일=0이다.

같은 날 A04의 actual=requested=10인 직접 경험을 통합한 기대값은 다음과 같다.

| 값 | 학습 전 | 통합·저장·재개 뒤 |
|---|---|---|
| information:000003의 ID·owner·fact·subject | 기존 값 | 모두 동일 |
| 현재 belief / confidence | 50 / 80 | 63 / 90 |
| information의 linked_event_id | event:000001 | event:000002 |
| legacy memory의 linked_event_id | event:000001 | event:000001 |
| legacy memory 전체 | 부록 원문 | byte 의미 동일, 재평가 없음 |
| 전체 memory / receipt 수 | 1 / 0 | 3 / 2 |
| next_ids.event / next_ids.memory | 2 / 2 | 3 / 4 |
| epoch / integrated / revision | 0 / 0 / 0 | 1 / 1 / 1 |
| 두 가구 식량 | 15 / 60 | 25 / 50 |

부록에는 전체 초기 payload, 날짜·입력 hash로 다시 결속한 예상 M3/intent/context/outcome 원문, M4 중간 stage·batch hash preimage, 전체 최종 payload, audit 세 배열을 비운 save envelope와 그 canonical JSON 문자열을 넣었다. 기존 F02의 수치 커널은 유지하지만 예전 hash를 새 원문에 복사하지 않았다. 새 원문은 **계산된 기대값**이고 신뢰된 runtime 발행물이나 실제 실행 결과가 아니다.

- 초기 세계 H: `2fca2ed5e9296276d7af644176f9a1d584eac2f18456f023a43c569c4158a770`
- A04 통합 후 및 save decode 후 세계 H: `4df2f95f6e5aa99540daa3830152158336a7ee65be03d882f36ea7ecb38ef4a0`
- save canonical JSON UTF-8 SHA-256: `3b0ef1553dcc7b1e0aa99ec558fcc65eaf35309c3e1b0c98940ba310077dd8aa`

동일 save를 다시 decode할 때 위 H, 과거 memory 전체, 현재 information 전체, 영수증·counter가 같아야 한다. decode는 학습·관계 변화·기억 생성을 실행하지 않는다. 그 뒤 빈 contacts를 계속 실행한 세계와 재개 후 빈 contacts 세계도 같아야 하며, 부록 B03의 `close_checkpoint.input_payload`가 그 전체 기대 원문이다. 차이는 revision 1→2와 contact_day -1→0뿐이다.

고장 대조군은 legacy memory의 information을 다른 owner의 fact로 바꾸거나 과거 event를 존재하지 않는 ID로 바꾸면 공개 검증에서 거부하고, 새 memory의 source observation을 지우면 최종 통합 검증에서 거부한다. 현재 information의 사건이 과거 memory와 달라진 것 자체는 오류가 아니다.

## 17. Ruleset 원문·hash·서비스 authority

social ruleset exact JSON은 부록 `social_ruleset`이다. 모든 수치 표의 상수와 정책 algorithm ID를 그 객체에 포함했다. 문서와 부록이 충돌하면 임의로 한쪽을 선택해 구현하지 말고 명세 오류로 보고한다. 비수치 의미가 바뀌어도 algorithm ID 버전을 올려 hash를 바꿔야 한다. 이에 따라 v0.2는 social ruleset ID를 `drought-prototype-social-v2`, 통합 algorithm ID를 `m5-social-integration-v2`로 올렸다. legacy 참조·상충 보관·operation 계약의 정책 ID도 부록 원문에 넣었다. 기존 수치 벡터·FCAL 28행·M4 투영 9개는 동일하며, social 의미 변경으로 manifest·simulation·초기 세계 hash만 새로 결속한다. v0.1의 hash를 계속 승인값처럼 사용하지 않는다.

| 항목 | SHA-256 |
|---|---|
| 기존 M4 exact artifact 파일 | `63a154f947ccbe6309d3d89690dbb7b3d6b1f5bf695356a89dd5ff45028e6819` |
| social 규칙 canonical hash | `c295928deb3178c8ab081aa65ae2cd27ff473dac2d048e668ff8bafa9ca21142` |
| Schema 5 simulation ruleset hash | `9781a62e3f607f9fe861201a905c0fff6b7a12ffc564c660facb8fdddc40e5d4` |
| FCAL 최초 Schema 5 state hash | `6914961c6d6dcaa5ed3f460fd870254a2aa0d851837a6f5545f19005d81886a1` |
| JSON 부록 파일 byte SHA-256 | `65914e923ed4786c51dcd45edb293823de9fffff29a9fb900f1a848d56df5d2e` |

| component | ruleset ID | 유지/신규 hash |
|---|---|---|
| decision | `drought-prototype-rules-v3` | `bd3a83d9491eb0275605817fc50d9fde4cf444efb7f5d3ed749c3d6d975fddb8` |
| parameterization | `drought-prototype-parameterization-v1` | `2b3b28f3ad886962e462eaedbd7dfd5321b519329af25f2f2d9664c666c46ae3` |
| resolution | `drought-prototype-resolution-v1` | `5ac0e95d42761ba1037480a28edb996d73e318ab04dae44ee5ef587eb537a3fe` |
| resource | `drought-prototype-rules-v2` | `3c5da58d0e0168c9427b827c0e37c4b9dd1e4582834b8c33efc5a6e6c9015f03` |
| response | `drought-prototype-response-v1` | `6599cea3c34469b9051a6a6ecc8eebc89d4291620a792388a7a5b8aa9b5dae4d` |
| social | `drought-prototype-social-v2` | `c295928deb3178c8ab081aa65ae2cd27ff473dac2d048e668ff8bafa9ca21142` |

Schema 5 public 경로는 전체 manifest의 구조와 지원 simulation hash를 검사한다. 서비스별 수치 해석 authority는 M3=`decision`, parameterizer=`parameterization,decision`, response=`response,resource`, resolver=`resolution,resource`, day resource kernel=`resource,resolution`, M5=`social`이다. facade는 필요한 커널들을 호출하며 모든 component 구현 hash의 일치를 검증한다. social 해석기가 실제 보안이나 resource 내부 상태를 자유롭게 읽을 권한이 생기는 것은 아니다.

M5 state hash는 기존 Schema 4 hash로 가장하지 않는다. 기존 다섯 component의 byte·hash와 M4 fixture byte는 회귀 게이트에서 그대로 확인한다.

## 18. M5 artifact와 검증 자료

### 18.1 공개 결과와 감사 객체

M5OperationResult의 exact 필드는 `ok`, `next_world`, `resource_transactions`, `artifact`다. runtime next_world는 typed WorldState 또는 null이며 artifact hash 대상에는 포함하지 않는다.

artifact의 exact 키는 다음과 같다.

```text
algorithm_id, operation_kind, operation_id, status,
input_state_hash, intermediate_state_hash, output_state_hash,
input_day_index, output_day_index,
input_social_revision, output_social_revision,
m4_batch_artifact_hash, errors, observation_changes, effect_applications,
field_changes, maintenance_changes, defaulted_inputs, state_metrics, artifact_hash
```

algorithm_id=`m5-operation-artifact-v2`, operation_kind는 `EXECUTE/CONTACTS/CLOSE`, status는 `COMMITTED/REJECTED`다. artifact_hash는 **artifact_hash 자신만 제외한 나머지 19키 객체**를 H한다. 성공 시 errors=[]이며 최종 공개 hash·날짜·revision을 기록한다. 성공 EXECUTE의 intermediate_state_hash·m4_batch_artifact_hash는 검증된 AFTER_RESOLUTION·committed batch의 H다. 성공 CONTACTS는 두 필드 모두 "", 성공 CLOSE는 검증된 AFTER_DAY_RESOURCES H와 m4_batch_artifact_hash=""다. 실패는 18.3절의 단 하나의 직렬화 정책을 사용한다.

#### 요청 identity 원문

operation ID의 exact preimage는 아래 4키다. stamp는 caller가 제출해 검증을 통과한 3키 값이며 다른 nonce·timestamp·issuer 객체 주소를 추가하지 않는다.

```json
{
  "algorithm_id": "m5-operation-id-v2",
  "operation_kind": "EXECUTE",
  "stamp": {
    "input_state_hash": "<validated input hash>",
    "day_index": 0,
    "social_revision": 0
  },
  "request_identity": []
}
```

위 값은 형식을 설명하는 예시이며 `<validated input hash>`는 실제 preimage에서 소문자 64자리 값으로 대체한다. 비어 있는 EXECUTE 배열은 공개 요청 검증에서 실패한다. 구체적인 값과 canonical JSON은 B03에 있다. `operation_id=H(preimage)`다.

| 호출 | request_identity exact 형태 | 정렬·출처 |
|---|---|---|
| EXECUTE | 아래 4키 원소의 배열 | id↑, 동일 id의 서로 다른 원문은 REQUEST_CONTRACT 오류 |
| CONTACTS | `{pairs:[{id,person_a_id,person_b_id}]}` | 검증된 plan 전체, pairs는 id↑ |
| CLOSE | `{}` | 필드 없음 |

EXECUTE 원소의 exact 키는 `id,actor_person_id,decision_key,submitted_decision_hash`다. actor와 decision_key는 **DecisionRequest**의 `to_data()`에서 가져온다. submitted_decision_hash는 전달받은 **DecisionResult.to_data() 전체**의 H이며, 기존 `DecisionArtifactCodec.hash_result`와 같다. 선택 후보 ID나 일부 점수만 hash하지 않는다.

```text
fields = {actor_person_id, decision_key, submitted_decision_hash}
element.id = H({algorithm_id:"m5-execute-submission-id-v1", ...fields})
element = {id:element.id, ...fields}
```

배열의 완전히 같은 원소도 중복 제거하지 않는다. 동일한 두 submission은 두 원소로 identity에 남고 기존 M4의 duplicate slot 검증으로 넘어간다. 요청 ID 계산은 순수 직렬화이며 제출 판단의 진정성이나 issuer의 신뢰를 보증하지 않는다. M4는 기존 재계산·provenance·authority 검증을 그대로 수행한다. 정상 request의 같은 identity라도 이후 context·실패 단계가 다르면 artifact hash는 다를 수 있다.

#### identity 계산 시점

공개 facade의 순서는 다음으로 고정한다. 각 단계가 실패하면 뒤 단계를 실행하지 않는다.

1. world의 자료형·Schema·exact 키·ruleset·공개 불변식을 검증한다. **전부 통과한 뒤에만** 입력 public H·날짜·revision을 artifact용으로 확정한다.
2. stamp의 exact 자료형·범위를 검사한 뒤 day → revision → state_hash 값을 비교한다. 자료형 오류는 FIELD_CONTRACT, 값 불일치는 7절 STALE 코드다.
3. 날짜 내 호출 순서(ACTIONS_CLOSED 등)를 검사한다.
4. 요청 형태를 검증한다. EXECUTE는 nonempty typed submission 배열, nonnull DecisionRequest·DecisionResult, 정확한 요청 키와 안전하게 canonical 직렬화 가능한 기존 result 형식을 요구한다. CONTACTS는 10.1절의 pair·참조·중복·상한을 검사한다. CLOSE는 추가 요청이 없다. 내용의 M3 일치 여부·중복 행동 slot·issuer 신뢰는 여기서 추측하지 않고 M4에서 검사한다.
5. 검증된 요청에서 identity 원문과 operation_id를 만든다. 같은 element ID에 다른 원문이 있는 경우에는 4단계 요청 실패로 처리한다. 이후 커널·사회적 처리·최종 검증으로 진행한다.

따라서 world/stamp/순서/요청 검증 실패의 operation_id는 항상 ""다. 부분적으로 읽을 수 있는 요청을 hash해 임시 ID를 반환하지 않는다. 다른 잘못된 요청들이 같은 대표 오류·공개 입력을 가지면 같은 실패 artifact가 될 수 있다. operation_id는 실패 요청 전체의 식별을 약속하지 않는다.

### 18.2 배열 원소

각 배열 원소는 id를 가진 dictionary이며 id 오름차순으로 정규화한다.

| 배열 | 원소 exact 키 |
|---|---|
| errors | id, code, field_path, entity_id, cause_code |
| observation_changes | id, observation_id, operation, before_hash, after_hash, selected_source_person_id, received_report_count |
| effect_applications | id, receipt_id, observation_id, rule_id, relation_deltas, emotion_deltas, pressure_delta, belief_change, experience_context |
| field_changes | id, owner_person_id, target_id, field_path, before_value, requested_delta, after_value, applied_delta |
| maintenance_changes | id, owner_person_id, kind, target_id, before_value, after_value |

observation operation=`CREATE/UPDATE/KEEP_CONFLICT/KEEP_DUPLICATE`다. before/after hash는 observation.to_data의 H이고 없는 쪽은 ""다. 최종 동일 상태라도 받은 전언 경로는 이 audit에 기록할 수 있다. 미래 실행이 이 배열을 읽지는 않는다.

effect의 relation_deltas는 `{target_person_id,trust,affection,fear,resentment,obligation}` 배열, emotion_deltas는 `{anger,fear,guilt}`, pressure_delta는 `{trait_id,raw_magnitude,sign,repeat_prior_count,applied_pressure}`다. 적용하지 않은 필드는 0이며 압력이 없으면 trait_id=""다. belief_change는 없으면 {}, 있으면 `{information_id,old_belief,new_belief,old_confidence,new_confidence,sample}`다. experience_context는 self A11 또는 직접 A04 requester에만 13절의 객체, 다른 경우 {}다.

effect_applications의 delta는 snapshot 기준 계획값이다. 여러 효과가 합산·clamp된 실제 변화는 field_changes에서 `(owner,target,field_path)`당 한 행으로 기록한다. applied_delta=after_value-before_value이며, clamp 때문에 계획값과 다를 수 있다. 개인 필드의 target_id는 owner다. 임의의 사건 하나에 clamp 손실을 배정하지 않는다. 배열 원소의 id는 `<배열명>:`+H(그 원소의 id를 제외한 나머지 필드)로 계산한다. 식별자로 만든 hash는 미래 simulation 입력이 아니다.

maintenance kind는 `EMOTION_DECAY/WEEKLY_TRAIT/PRESSURE_REMAINDER/MEMORY_TIER/MEMORY_COMPRESS/REPEAT_PRUNE`다. before/after value는 kind별로 두 값의 동일 타입을 유지한다(점수·압력은 int, tier는 string, 압축은 memory ID string→"", prune은 정수 날짜 배열). defaulted_inputs는 경로 문자열 배열이다.

state_metrics exact 키는 `persons`, `events`, `traces`, `observations`, `effect_receipts`, `memories_recent`, `memories_important`, `memories_core`, `relations`, `trait_pressures`, `repeat_exposures`, `canonical_state_bytes`이며 비음수 int다. 실패에는 {}다. 공개 관찰 자료에서 비공개 식별자·전체 세계 hash를 인물 지식으로 다시 주입하지 않는다.

### 18.3 실패 단계별 반환 필드 — B03

실패 artifact는 완료된 검증 경계를 보고하며 임시 social 처리 순서를 보고하지 않는다. **이미 계산했다는 사실만으로 hash를 반환하지 않는다.** 아래 checkpoint가 온전히 검증됐을 때만 해당 hash를 보존한다.

- `PUBLIC_INPUT`: 18.1의 world 검증 전체 완료.
- `REQUEST_IDENTITY`: world·stamp·순서·요청 검증과 operation_id 계산 완료.
- `VERIFIED_M4_REJECTION`: 신뢰된 내부 M4의 REJECTED batch에 대해 input H·epoch·정확한 rejected 형태·대표 reason·diagnostic·batch hash 검증 완료. 중간 세계는 없다.
- `VERIFIED_M4_COMMIT`: 6.4절의 stage 허용 delta·stage hash·M4 batch hash·seed/outcome/intent/context 결속 검증이 **모두 완료**. stage hash와 batch hash를 한 checkpoint로 확정한다. 이때부터 후반 M5 실패에도 두 hash를 보존한다.
- `VERIFIED_DAY_RESOURCES`: CLOSE의 자원·소비·건강·날짜 stage와 transaction·보존 검증 전체 및 stage hash 확정. 이 경로에는 M4 batch가 없다.

| 실패 시점 | input H / day / revision | operation_id | intermediate_state_hash | m4_batch_artifact_hash |
|---|---|---|---|---|
| world 검증 전체 완료 전 | "" / -1 / -1 | "" | "" | "" |
| 공개 world 유효, stamp·순서·요청 실패 | 실제 공개 입력 값 | "" | "" | "" |
| identity 완료, 커널 실행 전·완료된 checkpoint 없음 | 실제 공개 입력 값 | 계산값 | "" | "" |
| 검증 완료된 M4 REJECTED | 실제 공개 입력 값 | 계산값 | "" | 검증한 rejected batch H |
| M4 stage 또는 batch·provenance 결속 검증 실패 | 실제 공개 입력 값 | 계산값 | "" | "" |
| M4 COMMIT checkpoint 뒤 projector·해석·할당·최종 검증 실패 | 실제 공개 입력 값 | 계산값 | 검증한 AFTER_RESOLUTION H | 검증한 committed batch H |
| CONTACTS의 사회적 처리·최종 검증 실패 | 실제 공개 입력 값 | 계산값 | "" | "" |
| CLOSE 자원 stage 검증 완료 전 실패 | 실제 공개 입력 값 | 계산값 | "" | "" |
| CLOSE 자원 checkpoint 뒤 정리·최종 검증 실패 | 실제 공개 입력 값 | 계산값 | 검증한 AFTER_DAY_RESOURCES H | "" |

M4 stage hash 계산에 성공했어도 이후 batch·provenance 검증이 실패했다면 그 checkpoint는 미완료이므로 **둘 다 ""**다. checkpoint 이후의 변조·링크 오류는 마지막으로 검증한 immutable checkpoint hash를 유지한다. 변조된 clone으로 hash를 다시 계산해 대체하지 않는다. 검증되지 않은 REJECTED batch도 M4_REJECTED가 아니라 ARTIFACT_BINDING 실패이며 batch H=""다.

아래 값은 모든 실패 단계에서 고정한다. 앞 표와 합치면 artifact의 20키와 result의 4키를 빠짐없이 결정한다.

| 필드 | 모든 실패의 값 |
|---|---|
| result.ok / next_world / resource_transactions | false / null / [] |
| artifact.algorithm_id / operation_kind / status | m5-operation-artifact-v2 / 호출한 facade 종류 / REJECTED |
| output_state_hash / output_day_index / output_social_revision | "" / -1 / -1 |
| observation_changes / effect_applications | [] / [] |
| field_changes / maintenance_changes / defaulted_inputs | [] / [] / [] |
| state_metrics | {} |
| errors | 대표 오류 1개만 가진 exact 배열 |
| artifact_hash | 위 값으로 완성한 19키 원문의 H |

실패 직전 관찰·영수증·delta·기억 정리·default 경로가 얼마나 계산돼 있었든 위 다섯 social 배열은 **모두 비운다**. 부분 성공 artifact·출력 세계 hash·자원 거래 원문을 상위 결과에 남기지 않는다. 검증한 M4 batch의 H가 남는 것은 M4 자원 이전이 공개됐다는 뜻이 아니다. result의 거래 배열과 next_world는 끝까지 []·null이다.

errors 원소는 18.2의 exact 5키다. code·field_path·entity_id·cause_code가 정해진 뒤 `id="errors:"+H(나머지 4키)`로 만든다. cause_code는 M5_M4_REJECTED에서 기존 M4 대표 reason, 나머지에서는 ""다. M4 거부의 field_path="m4.batch", entity_id는 M4 대표 diagnostic의 action_instance_id(없으면 "")다. 같은 단계의 대표 선택은 `(7절 code 순위, field_path, entity_id, cause_code)` 오름차순이며 완전 동률은 동일 출력 하나다. 실행하지 않은 뒤 단계의 오류를 탐색하지 않는다.

field_path는 모델 필드의 고정 경로이고 배열 index를 넣지 않는다. 식별 가능한 레코드는 entity_id로 표시한다. malformed 원소의 안전한 식별자가 없으면 collection 경로와 entity_id=""를 쓴다. 예: empty submissions는 `submissions`, 전체 세계 자료형 오류는 `world`, 잘못된 batch output hash는 `m4.batch.output_state_hash`다. 자유 설명문·stack trace·지역화 메시지는 이 exact artifact에 넣지 않는다. 실패 artifact는 관찰·EventRecord·기억을 만들지 않는다.

### 18.4 exact 벡터의 주장 범위

부록은 최초 세계 전체와 정확한 투영 기대값을 제공한다. round/confidence/learning/weekly/repeat/clamp/feedback/memory capacity는 수치 oracle이다. M4 projection 벡터는 실제 frozen outcome hash와 소유자·수량·흔적 기대값에 결속했다. 28일 표는 날짜·자원·epoch·revision·기억·인식 수의 정확한 assertion projection이다.

v0.2는 B01의 전체 초기·A04 후·저장 재개 기대 원문/H와 B03의 **실패 artifact 7개 전체 원문·canonical preimage·H**를 추가한다. 이는 작은 고정 사례를 계약에서 계산한 oracle이며 Godot의 출력이 아니다. FCAL의 매일 full-world hash와 성공 operation artifact 전 필드를 생성·실행한 것은 아니다. 구현 승인 후 engine fixture가 독립적으로 위 기대값을 재현해야 하며 실행 출력을 기대값에 덮어써 PASS로 만들지 않는다.

| 추가 벡터 | 검산 대상 |
|---|---|
| B01 | 기존 memory의 과거 사건 보존, 현재 fact 학습, 전체 저장·재개 H |
| B02 | 처음 반대 보고 두 개 및 동순위 재청취의 전체 observation·출처·H |
| B03 identity | EXECUTE exact 원소·전체 preimage·역순 동일 ID·중복 유지, 빈 CONTACTS, CLOSE |
| FAR-00 / 01 | world 실패의 빈 입력 metadata, 요청 실패의 유효 입력 metadata와 빈 operation ID |
| FAR-02 / 03 | 검증한 M4 REJECTED H 보존, 미완료 stage/batch checkpoint의 H 전부 비움 |
| FAR-04 | M4 완료 뒤 memory 링크 고장: checkpoint H 보존, 관찰·효과·default 임시 배열 폐기 |
| FAR-05 / 06 | CONTACTS 후반 실패의 중간 H 없음, CLOSE 후반 실패의 자원 stage H만 보존 |

B03의 permutation은 identity 직렬화 단위 사례다. 두 번째 제출 result는 hash 입력을 구별하기 위한 값으로 M3가 발행했다고 주장하지 않는다. `*_input_json` 문자열은 입력 배열 순서를 그대로 보존하고, 구조화된 identity 배열은 2.2절에 따라 정규화한다. FAR-04~06의 고장은 내부 fixture seam에서 선언한 오류로, 공개 API에 임의 고장 옵션이나 외부 stage 제출 권한을 추가하지 않는다.

각 FAR에는 expected_result의 4키와 artifact 전체, artifact_hash를 제외한 exact preimage와 canonical JSON, 실패 후 원본 세계 H를 함께 넣었다. 구현자는 빈 값이나 부분 배열 반환을 선택하지 않는다. 설계 검산과 native engine 실행 검증은 별도다.

## 19. 기존 20개 검증 계약의 구체화

결정 25의 M5-T01~T20을 유지한다. 아래는 각 항목의 concrete assertion이며 시험 통과 보고가 아니다.

| ID | 실행할 검증 | exact 기대 또는 실패 조건 |
|---|---|---|
| M5-T01 | Schema 호환·저장·manifest | B01 기존 기억+현재 믿음 학습·save/resume; 1–4 기존 golden 동일; 5의 keyset 정확; 최초 state hash 부록 일치; mid-stage encode/decode 거부; audit 빈 재개 허용 |
| M5-T02 | M4 상태 경계 | REJECTED delta=0; INVALIDATED·A00 사건=0; committed이면 epoch와 integrated 모두 +1 |
| M5-T03 | A04 경험 | F02/F03/F04 각각 actual 10/5/0; 소유자 actor·target만; grant-zero와 reject 관계 delta 상이 |
| M5-T04 | A11 경험·목격 | F06A/B self만, F06C self+person4·실패 시도, F07 trace=0이어도 person4 목격 |
| M5-T05 | 비공개 필드 | payload exact keyset 외 actual_security·trace·notice·다른 witness 필드 삽입 거부; 허용 payload 고정 해석기의 결과 동일 |
| M5-T06 | 흔적 | trace=true일 때 store별 실제 사건 trace 하나; seed가 없으면 타인 observation·관계 0 |
| M5-T07 | 전언·C08·I06 | confidence 60 수용/59 미수용; 미수용 delta=0; FCAL person3 같은 pass 미수신 |
| M5-T08 | snapshot·상한 | 당일 신규 2→3 전달 0; 4번째 접촉 상대 입력 실패; 방향당 선택 2 이하; 중복 pass 거부 |
| M5-T09 | 비밀·출처 | 자기 theft 일반 전언 0; direct→hearsay 구분·원천 보존; confidence 매 hop 감소·depth 3 상한 |
| M5-T10 | 중복·충돌 | 9절 59→60→100에서 효과 1회; 동일 원천 합산 없음; B02 동순위 상충의 전체 observation·출처·H 순서 독립 |
| M5-T11 | 관계·감정 | 방향 유지; sparse 기본값 0; start99 +4 -3 =100; 순차 clamp의 잘못된 97 금지 |
| M5-T12 | 판단 환류 | 고정 capacity48에서 학습 전후 M40→48; norm69→71에 C46→47; 다른 항목·선택은 별도 관찰 |
| M5-T13 | 압력·C09 | C<40은0; 의미1..3·고비용4; 예 -2/-1 및 +4; 성공만 바꿔 sign 불변; target 변경 감쇠 우회 불가 |
| M5-T14 | 주간·I09 | FCAL 6/13/20/27일만 발동; score99/P11→100/P6; 반대경계 대칭; 반복·재개 한도 유지 |
| M5-T15 | 기억·I08 | FCAL 첫0일 기억 d13 유지/d14 압축; 첫13일 기억 d26 유지/d27 압축; 습득일 재갱신 없음 |
| M5-T16 | 압축 | core9+important25+recent70 총104 → 8/24/64, 압축8; 영수증 유지·memory 참조 제거·효과 0 |
| M5-T17 | 원자성·오염 | stage hash 이후 값 오염 거부; FAR-00~06 실패 artifact 원문·H; 후반 링크/overflow 실패 시 원본·자원·모든 counter 불변 |
| M5-T18 | 결정론·재개 | 지원하는 집합 배열 permutation 동일 canonical 결과; 숫자 날짜 배열 unsorted 거부; FCAL 4 checkpoint 재개 동등; Linux/Windows 같은 hash |
| M5-T19 | 권한·시간 | direct M4/Day mutation에 Schema5 거부; M5 해석기 resource·health·day delta0; close 날짜+1; contacts 전에/후 순서 검증 |
| M5-T20 | 규모·공통 규칙 | memory 인물별<=96, observation/receipt owner-event당<=1; 실제 레코드·bytes 보고; player_person_id만 바꿔 같은 인물의 의미 출력 동일 |

세계 전체 hash가 달라지는 것과 정보 누출은 구분한다. 비공개 사실을 바꾸면 input metadata hash는 달라질 수 있다. 허용된 개인 입력을 고정한 M3·해석기의 의미 출력이 바뀌는지 검사한다. 실제 M4 보안을 바꿔 seed가 달라진 경우는 투영 전 사건 판정의 변화다.

A04 grant-zero는 unit fixture에서 `GRANT_FULL,requested=10,actual=0`의 내부 승인 payload로 해석 차이를 검증하고, native 통합 시험에서는 같은 source store의 경합으로 실제 0 지급을 만드는 별도 M4 조건을 구성한다. unit payload를 공개 실행 결과로 발행하지 않는다.

## 20. 구현 시 변경 대상과 완료 조건

### 20.1 변경 대상

- 모델/codec/validator/hasher/manifest의 Schema 5 분기와 내부 clone 경로.
- bare WorldState 생성과 기존 fixture의 기본 schema는 4로 유지하고, Schema 5는 명시적인 생성 경로에서 선택한다. 지원 schema 목록 확장과 기본 생성값 변경을 혼동하지 않는다.
- M3·parameterizer의 Schema 5 publishable 입력 지원. 기존 decision 규칙은 유지.
- 기존 M4 numerical kernel과 DayProcessor 자원·건강 kernel을 사용하는 신뢰된 Schema 5 내부 경로. 공개 legacy 경로는 회귀 보존.
- M5 facade, stage boundary, observation projector, contact processor, appraisal, pressure·memory maintenance, social rules, 감사 artifact.
- 구현 승인 후 M5-T01~T20 시험과 fixture, 기존 M0–M4 회귀·Linux/Windows 검증.

부록은 저장소의 정본 ruleset·fixture로 설치하지 않았다. repository write·commit·push·PR·merge와 Godot 시험 실행은 이번 설계 작업에 포함하지 않았다.

### 20.2 이번 설계 검산과 남은 게이트

이번에 실시한 것은 세 지적과 원문·동결 코드 대조, 참조 정책과 canonical 직렬화의 명세 검산, 새 exact 기대값 계산이다. v0.1의 numeric_vectors·FCAL 28행·M4 투영 9개·기존 다섯 component와 결정 25 검증 계약 20개 원문을 그대로 보존했는지 대조했다. Godot 시험과 독립 QA의 PASS를 대신하지 않는다.

```text
DECISION 26 v0.1 = HOLD / THREE REVIEW BLOCKERS
DECISION 26 v0.2 = REVISED / REVIEW PENDING / NON-CANONICAL
B01 / B02 / B03 = CONTRACT AND EXACT VECTORS ADDED / REVIEW PENDING
D26-R01 = INTERNAL/PUBLIC VALIDATION AND HASH CONTRACT SPECIFIED
D26-R02 = DAY 0–27 CONTINUOUS EXPECTATIONS SPECIFIED
DESIGN ARITHMETIC = CHECKED
GODOT M5 IMPLEMENTATION / TESTS = NOT PERFORMED
M5 IMPLEMENTATION = NOT AUTHORIZED
```

다음 검토에서는 B01의 과거 참조 보존, B02의 미수용 대표 전체 정렬, B03의 identity·checkpoint·실패 빈 값과 exact artifact를 우선 확인한다. 기존 D26-R01/R02와 수치·날짜·영수증 계약도 함께 적용한다. D25·D26 정본 채택과 실제 구현 착수는 별도 상태로 관리한다.

## 부록 A. 결정 25의 검증 계약 20개 원문

다음 표는 결정 25 v0.2에서 문구를 바꾸지 않고 옮겼다. 19절의 상세 assertion과 함께 적용한다.

| ID | 시험 | 필수 확인 |
|---|---|---|
| M5-T01 | Schema 호환 | Schema 1–4 회귀 유지, Schema 5의 저장·복원과 새 규칙 해시 |
| M5-T02 | M4 경계 | REJECTED·INVALIDATED·A00이 허구의 거절·목격·압력을 만들지 않음 |
| M5-T03 | A04 직접 경험 | 당사자만 인식하고, 제공 응답 후 0 지급과 명시적 거절을 구분 |
| M5-T04 | A11 직접 경험·목격 | 행위자의 자기 경험, seed 소유자의 목격, 실패한 시도 목격을 분리 |
| M5-T05 | 비공개 필드 차단 | 실제 보안·응답 효용·목격자 목록·trace 존재 등 허용되지 않은 필드를 인식에 복사하지 않음 |
| M5-T06 | 미목격 흔적 | 흔적은 보존되지만 자동 범인 인지·전 주민 평판 변화 없음 |
| M5-T07 | 전언 경계 / C08·I06 | 목격자, 수신 후 수용자, 미수용자, 미접촉자의 상태가 각각 올바름 |
| M5-T08 | 접촉 snapshot | A→B→C 당일 연쇄 전달 차단, pass 재호출 및 상한 우회 차단 |
| M5-T09 | 비밀·출처 | 일반 대화의 비밀 제외, 전달자의 실제 보유 검증, 원천·깊이 유지 |
| M5-T10 | 중복·충돌 | 동일 사건 재청취·순환 소문 증폭 없음, 상반된 보고의 배열 순서 독립성 |
| M5-T11 | 관계·감정 | 방향성·소유자·범위·default 경로와 합산 후 clamp 검증 |
| M5-T12 | 판단 환류 | 바뀐 fact·관계·fear·norm 입력의 계산 경로 추적, 특정 최종 행동 강제 없음 |
| M5-T13 | 압력 / C09 | 자기 경험·규범 충돌·반복 감쇠, 성공만으로 성향 급변하지 않음 |
| M5-T14 | 주간 한도 / I09 | 주차 경계, ±2, 잔여 압력·0/100 경계·반복 호출·저장 재개 |
| M5-T15 | 기억 / I08 | 14일 경계·단계 상한·개수 상한·늦은 습득·반복 소문의 날짜 갱신 방지 |
| M5-T16 | 압축 | 관계 효과 재적용·원복 없음, 중복 방지 유지, dangling reference 0 |
| M5-T17 | 원자성·오염 | M5 후반 실패 시 M4 자원 이전도 공개되지 않음, 원본과 모든 counter 불변 |
| M5-T18 | 결정론·재개 | 입력 순서 변경·저장 재개·Linux/Windows에서 동등한 의미와 canonical 결과 |
| M5-T19 | 자원·시간·행위 권한 | M5 단독 자원·건강·날짜 변경 없음, wrapper 날짜 한 번 증가, 자동 추가 행동 없음 |
| M5-T20 | 상태 규모·공통 규칙 | 기억·인식·적용 상태 규모 보고, sparse 관계, 플레이어/NPC 동일 규칙 |

## 근거와 확인 범위

실제 열람한 로컬 game-m4는 HEAD `06116ebd680cdbbf1d79ea18ffcaaad20f657352`, tree `b8451f637b460957bd3c04870b6be1561e19de8c`이며 clean 상태였다. 동결 기준 tree와 일치한다. 원격 merge 객체는 이 로컬 object database에 없어 로컬 merge ancestry를 새로 검증하지 않았다. 최신 원격 main이나 CI가 변하지 않았다는 주장을 새로 하지 않는다.

설계 근거는 해당 동일 tree의 다음 파일과 결정 25 v0.2다.

- [기존 단계·결정 1–24](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/docs/drought-prototype-v0.md)
- [M4 facade](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/action/m4_facade.gd) · [resolver](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/action/atomic_action_resolver.gd)
- [DayProcessor](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/time/day_processor.gd)
- [WorldState](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/model/world_state.gd) · [StateCodec](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/serialization/state_codec.gd) · [StateValidator](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/serialization/state_validator.gd)
- [M3 DecisionEngine](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/src/simulation/decision/decision_engine.gd) · [M4 exact artifact](https://github.com/MSAC-lab/game/blob/774680cad964b3485ceab1324c8eebac763abe41/tests/fixtures/m4_exact_artifacts.json)

첨부 능력치·캐릭터 초안에서는 능력과 성격의 분리·방향성 관계·주관적 인식 원칙만 참고했다. 새 능력치나 세계관 WB 설정을 기술 계약으로 편입하지 않았다. 첨부 원본과 결정 25 v0.2를 수정하지 않았다.
