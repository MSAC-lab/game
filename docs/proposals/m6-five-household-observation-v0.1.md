# M6 가구 확대 관찰 — 5가구 초기 설정·단일 입력 비교안 v0.1

```text
STATUS = PROPOSAL / B REVIEW CANDIDATE
AUTHORITY = PREPARATION OF INITIAL SETTINGS AND COMPARISON CONDITIONS
BASE MAIN = cb4c4554f052018202549c5c90ee2cfc10030aef
BASE TREE = 337576001de5966e83e70e8395cd249d45620701
RUNTIME SCENARIO IMPLEMENTATION = NOT STARTED
FIVE-HOUSEHOLD EXECUTION = NOT RUN
CANONICAL ADOPTION / IMPLEMENTATION / MERGE = SEPARATE
```

## 1. 목적과 해석 범위

현행 M0–M6-0 규칙으로 5가구 사이의 요청·거절·절도·자원 경합과 사회적 반영을 관찰한다. 목표는 인물별 판단 근거와 실제 원장 결과를 설명하고, 다음에 필요한 기능 하나를 선택할 근거를 얻는 것이다. 특정 이야기, 절도 발생, 모든 비교에서의 선택 변경을 합격 조건으로 삼지 않는다.

이 문서는 검토용 초기 설정과 비교 조건이다. 실행 JSON·생성기·새 시험·규칙 변경을 포함하지 않는다. 첨부 캐릭터 모델 v0.2는 방향성 참고자료이며, 이 시험에서 새 8성격·13가치 체계를 채택하거나 구현한 것으로 취급하지 않는다. 현행 입력의 의미와 소비 경로를 사용한다.

기존 `scenarios/m6-0-food-pressure-v1.json`, FCAL 및 모든 동결 fixture를 그대로 보존한다. 기존 4명 시나리오의 파일 SHA-256은 `113340d2df337564f9414398f4a9e1c4d739b0c1c624bc29d58dbe7668b890cd`이다. 새 시나리오는 초기 인물값·자원·정보·현장도 다르므로, 기존 4명 기록과의 차이를 인구 증가 하나의 효과로 해석하지 않는다.

절도 반환·환수·형벌, A11 재고 믿음 갱신, 신규 행동, 규범준수의 파생값 전환은 후속 규칙 확장 후보다. 이번 초기 설정에는 그러한 효과를 미리 넣지 않는다.

## 2. ID·공통 초기값

이하 `P01`–`P15`는 `person:000001`–`person:000015`, `H01`–`H05`는 `household:000001`–`household:000005`의 표기 약칭이다. 가구 저장소 `S01`–`S05`는 `resource_store:household:000001`–`resource_store:household:000005`, 공동창고 `G`는 `resource_store:village_granary`이다. 배열 순서는 ID 오름차순으로 작성한다.

| 항목 | 초기값 또는 작성 규칙 |
|---|---|
| 실험 기준 이름 | F00 |
| 새 `scenario_id` | `m6-five-household-observation-v1` |
| `schema_version` | 5 |
| `rng_seed_hex` / `rng_state_hex` | `0123456789abcdef` / `fedcba9876543210` |
| `season_id` | `late_summer_drought` — 강수·수확 생성 기능을 의미하지 않음 |
| `day_index` / `day_phase` | 0 / `DAY_END` |
| `player_person_id` | P01 — 이 시험은 자동 진행이며 플레이어 UI가 없음 |
| `resolution_epoch` / `next_resource_sequence_index` | 0 / 0 |
| `resolved_decision_slot_ids` | 빈 배열 `[]` |
| `social_state` | `revision=0`, `last_integrated_resolution_epoch=0`, `last_closed_day_index=-1`, `last_contact_day_index=-1`, `last_settled_week_index=-1` |
| 규칙 | 기준 main의 Schema 5 manifest 6개 구성요소와 해시를 그대로 사용 |
| `simulation_ruleset_hash` | `9781a62e3f607f9fe861201a905c0fff6b7a12ffc564c660facb8fdddc40e5d4` |
| 진행기 | `m6-0-runner-v1`, 판단 key는 `daily_food_strategy` |
| 전 인물 | `alive=true`, `health=100`, `severe_hunger_days=0` |
| `need_scores` | `hunger=0` |
| `emotion_scores` | `anger=0`, `fear=0`, `guilt=0` |
| 전 인물 기초·기술 입력 | `dexterity=50`, `perception=50`, `intrigue.theft=30`, `intrigue.stealth=30` |
| 초기 기억·사회적 실행 이력 | `memories`, `social_observations`, `social_effect_receipts`, `traces`, `trait_pressures`, `repeat_exposures`는 빈 배열 |

성격·가치·수행 입력은 이 소규모 시험을 위한 명시적 저작값이다. 역할에서 성격을 자동 생성하거나 매일 다시 추첨하지 않는다. 기술·기초능력은 성격 비교를 위해 동일하게 두며, 실존 인물이나 연령 집단의 일반적 능력에 대한 주장이 아니다. 값 0은 이 표에서 명시한 초기 상태에만 사용한다.

구현 시 `config.initial_state_hash`는 완성된 초기 세계를 기존 해시 함수로 계산한다. 계획 단계에서 해시를 꾸며 넣지 않는다. `config.simulation_ruleset_hash`는 위 값과 같아야 하며, 나머지 config는 6절의 명세로 구성한다.

## 3. 5가구·15명·식량

| 가구 | 구성원 | 부양 인원 | 하루 필요량 | 가구 식량 | 명목 식량일수 | 10일 필요량 | 최초 A04 여유분 |
|---|---|---|---:|---:|---:|---:|---:|
| H01 | P01·P02·P03 | P03 | 5 | 15 | 3 | 50 | 0 |
| H02 | P04·P05·P06 | 없음 | 6 | 150 | 25 | 60 | 90 |
| H03 | P07·P08·P09 | P08·P09 | 4 | 80 | 20 | 40 | 40 |
| H04 | P10·P11·P12 | P12 | 5 | 25 | 5 | 50 | 0 |
| H05 | P13·P14·P15 | P14·P15 | 4 | 8 | 2 | 40 | 0 |
| 합계 | 15명 | 6명 | 24 | 278 | 가구별 상이 | 240 | 130 |

공동창고 G에는 별도로 식량 120을 둔다. 초기 총 식량은 **398**, 하루 필요량은 **24**다. 전량 접근 가능하다고 가정한 명목 공급량은 약 16.58일치이며, 28일 필요량 672보다 274 부족하다. 이는 산술 계획값이며, 실제 섭취량·재분배·건강 경계 도달일은 실행 전 미확정이다. 공동창고의 120은 자동 배급되지 않는다.

S01–S05의 `owner_kind=household`, `owner_id=각 H`, `resource_type_id=food`, `security_level=30`이다. G는 `owner_kind=village`, `owner_id=village:main`, `resource_type_id=food`, `security_level=45`다. 실제 보안과 주민의 보안 관련 믿음은 별도 입력이다.

가구 공통값은 `livelihood_id=mixed_labor`, `residence_id=residence:household:00000n`, `wealth_units=0`이다. `dependency_load`는 표의 부양 인원 수이고, `member_ids`, `dependent_person_ids`, `resource_store_id`는 위 표를 따른다. 별도 소득·생산은 발생시키지 않는다.

| 인물 | 이름 | 가구 | `occupation_id` | `role_ids` | 일일 식량 필요 | 자동 판단 | 성향·가치 프로필 |
|---|---|---|---|---|---:|---|---|
| P01 | 한결 | H01 | field_worker | `[]` | 2 | 예 | A |
| P02 | 미라 | H01 | weaver | `[]` | 2 | 예 | B |
| P03 | 나리 | H01 | child | `[]` | 1 | 아니오 | D |
| P04 | 도윤 | H02 | village_head | `[village_head]` | 2 | 예 | C |
| P05 | 유선 | H02 | field_worker | `[]` | 2 | 예 | D |
| P06 | 다솔 | H02 | granary_staff | `[granary_staff]` | 2 | 예 | E |
| P07 | 서준 | H03 | field_worker | `[]` | 2 | 예 | F |
| P08 | 은서 | H03 | elder | `[]` | 1 | 아니오 | D |
| P09 | 연우 | H03 | child | `[]` | 1 | 아니오 | D |
| P10 | 태오 | H04 | field_worker | `[]` | 2 | 예 | A |
| P11 | 소담 | H04 | weaver | `[]` | 2 | 예 | B |
| P12 | 보람 | H04 | child | `[]` | 1 | 아니오 | D |
| P13 | 길상 | H05 | field_worker | `[]` | 2 | 예 | D |
| P14 | 옥분 | H05 | elder | `[]` | 1 | 아니오 | D |
| P15 | 찬우 | H05 | child | `[]` | 1 | 아니오 | D |

자동 판단은 P01·P02·P04·P05·P06·P07·P10·P11·P13, 총 9명이다. 이 9명의 `goal_ids=[goal:secure_household_food]`, 나머지 6명의 `goal_ids=[]`다. 자동 판단 대상이 아닌 인물도 식량·건강 처리와 조건에 맞는 목격·접촉·기억·사회적 반영의 대상이다. 생업·역할 표기는 새 행동이나 권한을 생성하지 않는다. P06의 역할은 현재 규칙이 이미 읽는 직무 충돌에 영향을 줄 수 있다.

### 성향 4개·가치 6개를 빠짐없이 명시

| 프로필 | `risk_taking` | `empathy` | `self_control` | `norm_adherence` | `family_protection` | `community_survival` | `legitimate_order` | `fairness_reciprocity` | `property_autonomy` | `life_protection` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A | 50 | 50 | 50 | 70 | 70 | 50 | 60 | 50 | 50 | 50 |
| B | 70 | 40 | 50 | 40 | 80 | 40 | 30 | 40 | 40 | 50 |
| C | 50 | 50 | 50 | 70 | 70 | 50 | 70 | 50 | 70 | 50 |
| D | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 |
| E | 40 | 50 | 60 | 80 | 60 | 60 | 80 | 60 | 60 | 50 |
| F | 40 | 80 | 50 | 60 | 70 | 80 | 50 | 70 | 60 | 80 |

프로필은 입력의 묶음이며 선인·악인·도둑 같은 결과 유형이 아니다. 현행 규칙에서 `self_control`이 직접 소비되지 않는 경로에 효과가 있다고 주장하지 않는다. `norm_adherence`의 M5 경험 압력·주간 변화는 현행 그대로 둔다. 문서의 위험감수·공감민감성·가족의무·자비·생명보호·공공안녕은 각각 현행 `risk_taking`·`empathy`·`family_protection`·`life_protection`·`community_survival`과 비교하는 출발점일 뿐, 의미의 완전한 동등성을 선언하지 않는다.

## 4. 목표와 주관적 정보

### 인물별 알려진 행동 대상

아래 목록은 후보 생성에 필요한 초기 정보의 범위다. 행동을 선택하라는 명령이 아니며 선택은 M3가 한다. 같은 가구 안의 사람에게 A04를 요청하거나 자기 가구 창고를 A11 대상으로 두지 않는다.

| 정보 소유자 | A04 상대 | A11 저장소 | `village_authority` 믿음 대상 |
|---|---|---|---|
| P01 | P04 | G | P04 |
| P02 | P04·P07 | S02 | P04 |
| P04 | P07 | G | 없음 |
| P05 | P07 | G | P04 |
| P06 | P07 | G | P04 |
| P07 | P04·P10 | G | P04 |
| P10 | P04·P07 | G | P04 |
| P11 | P04·P07 | S02 | P04 |
| P13 | P04·P07 | G | P04 |

초기 A04 정보 묶음은 14개, A11 정보 묶음은 9개, 권위 믿음은 8개다. 부양 인원 6명은 초기 `information_ids=[]`로 시작한다. 이후 실제로 얻은 정보는 M5가 처리한다.

각 A04 묶음에 다음 4개 fact를 만든다. 표의 숫자는 `belief_value`, 최초 `confidence`는 모두 100이다.

| 대상 | `request_food_access` | `request_food_capacity` | `request_success_expectation` | `request_social_risk` |
|---|---:|---:|---:|---:|
| P04 | 100 | 80 | 80 | 20 |
| P07 | 100 | 60 | 20 | 15 |
| P10 | 100 | 30 | 35 | 15 |

각 A11 묶음에는 다음 5개 fact를 만든다. 최초 `confidence`는 모두 100이다.

| 대상 | `food_stock_level` | `theft_access` | `theft_opportunity` | `detection_risk` | `sanction_severity` |
|---|---:|---:|---:|---:|---:|
| G | 80 | 80 | 80 | 40 | 60 |
| S02 | 70 | 80 | 70 | 30 | 50 |

권위 믿음 8개는 `subject_kind=person`, `fact_type_id=village_authority`, `belief_value=100`, `confidence=100`이다. 실제 `village_head` 역할만으로 다른 인물에게 이 믿음이 자동 생성되지는 않는다.

전체 정보는 **109개**다: `14×4 + 9×5 + 8`. 소유자·대상·fact의 중복 조합은 없다. 구현 시 `(owner_person_id, subject_kind, subject_id, fact_type_id)` 사전순으로 정렬해 `information:000001`부터 ID를 배정하고, 각 인물의 `information_ids`를 정확히 역참조시킨다. `subject_kind`는 A04·권위이면 `person`, A11이면 `resource_store`다. 표에 없는 fact는 생성하지 않는다.

초기 정보는 시험 제작자가 작성한 과거 인식의 출발점이다. 실제 재고와 일치하는 지식이나 과거 원조 실행 결과로 가장하지 않는다. 특히 `food_stock_level`과 `request_food_capacity`는 현행 0–100 의미를 쓰는 주관적 입력이며 창고의 곡물 단위와 같지 않다. `sanction_severity`를 부여해도 실제 처벌 기능이 생기지 않는다.

각 자동 판단 인물별로 시작 정보의 근거 event를 하나씩 작성한다. 자동 판단 ID순으로 `event:000001`–`event:000009`를 배정한다. 각 event는 `event_type=subjective_observation_basis`, `action_id=observe`, `result_id=facts_acquired`, `day_index=0`, `actor_ids=[owner]`, `witness_ids=[owner]`, `target_ids=해당 인물의 A04·권위 믿음 대상인 person ID만 모은 중복 없는 정렬 목록`, `location_id=location:village_center`, `is_public=false`, `objective_payload={}`, `m5_origin={}`다. 현행 event의 `target_ids`는 인물 참조만 허용하므로 저장소 ID를 넣지 않는다. 저장소 대상은 A11 정보의 `subject_id`로 참조한다. 이는 실행 중의 사건·목격 기록이 아니라 초기 fixture의 출처 표기다.

모든 초기 fact는 `linked_event_id=소유자의 위 event`, `acquisition_type=observation_fixture`, `learned_day_index=0`, `original_source_person_id=""`, `current_source_person_id=""`, `source_observation_id=""`, `is_secret=false`, `claim=initial-estimate:<fact_type_id>`다. 실행 중에는 기존 M5 출처·관찰 검증을 따른다.

### 최초 후보의 정합성

공통 굶주림은 0이다. H01·H04·H05는 10일 필요량보다 적은 재고로 양의 식량 압력을 가지며, 해당 자동 판단 5명에게 A04·A11 후보가 열려 있어야 한다. H02·H03의 자동 판단 4명은 처음에 식량 압력 0이므로 A00을 선택할 수 있다. 이들은 목표·정보가 누락된 인물이 아니며 이후 조건 변화로 후보가 열릴 수 있다.

P01은 A04(P04), A11(G), A00을 가진다. 최초 후보 수의 산술 예상은 P01 3개, P02·P10·P11·P13 각 4개, P04·P05·P06·P07 각 1개, 합계 23개다. 제외 후보와 구체적인 사유도 기록한다. 이 수는 코드 대조로 작성한 예상이며 실행 PASS를 보고한 것이 아니다.

## 5. 관계

관계 값의 열 순서는 `(trust, affection, obligation, fear, resentment)`다. 아래 규칙으로 작성하며 해당 쌍의 양방향을 각각 별도 저장한다. 처음에 같은 값을 줘도 이후 변화는 방향별이다.

| 적용 대상 | 초기값 |
|---|---|
| 같은 가구의 서로 다른 모든 구성원 쌍 | `(80, 80, 80, 0, 0)` |
| 4절 A04 요청자–상대의 서로 다른 가구 쌍 | `(50, 20, 20, 0, 0)` |
| 아래 접촉망 중 위에 없는 서로 다른 가구 쌍 | `(50, 20, 20, 0, 0)` |

중복 쌍을 합치면 방향성 관계는 **58개**다. 그 밖의 초기 관계는 생성하지 않는다. 없음은 시험 저작에서 의도한 중립·미형성 상태이며 성격·가치 입력의 누락과 구분한다. 초기 관계가 없는 사람도 서로 목격하고 이후 관계를 형성할 수 있다.

관계 ID는 기존 `relation:<from_id>-><to_id>` 규칙을 사용한다. 각 인물의 `relation_ids`에는 자신이 `from_person_id`인 관계를 모두 넣고, `memory_ids=[]`로 시작한다.

## 6. 고정 현장·접촉망

15명과 저장소 6개 모두를 `site:five_household_courtyard`라는 단일 고정 시험 현장에 명시적으로 배치한다. 대상 선택 결과로 현장 구성원을 추가하지 않는다. 거주지 ID는 가구 신원이고 이번 진행기의 이동 모델이 아니다.

| 접촉 유형 | 고정된 무방향 쌍 |
|---|---|
| 가구 내부 | P01–P02, P02–P03; P04–P05, P05–P06; P07–P08, P08–P09; P10–P11, P11–P12; P13–P14, P14–P15 |
| 가구 사이 | P01–P04, P04–P07, P07–P10, P10–P13, P01–P13 |

총 15쌍이다. P01·P04·P07·P10·P13은 접촉 상대 3명, 나머지는 1–2명으로 현행 상한 3을 지킨다. 각 쌍에서 작은 인물 ID를 a, 큰 ID를 b로 두고 `id=contact:<a>-><b>`, `person_a_id=a`, `person_b_id=b`로 만든다.

**단일 현장은 의도한 시험 단순화다.** 절도 한 건에 최대 14명이 직접 목격 판정 대상이 될 수 있다. 접촉망의 차수 3은 직접 목격자를 3명으로 제한하지 않는다. 직접 목격과 접촉으로 전해 들은 정보를 나눠 기록하며, 이 시험의 노출 빈도를 자연스러운 마을의 이동·야간·비밀 유지 모델로 일반화하지 않는다.

`person_sites`에는 15개 인물 ID, `store_sites`에는 6개 저장소 ID가 정확히 존재해야 한다. 표에 있는 접촉은 자동 판단 여부와 관계없이 기존 M5 계획에 포함한다.

초기 카운터는 `next_ids={person:16, household:6, event:10, information:110, memory:1, decision:1, resource_transaction:1}`이다. 초기 개체와 역참조·카운터·정렬은 기존 Schema 5 및 M6-0 진입 검증을 받아야 한다.

## 7. 단일 입력 비교 조건 8개

F00을 기준으로 아래 각 행을 **서로 독립적으로** 복사해 만든다. 한 행에서 바꾸는 원인 입력은 표의 한 scalar뿐이다. 다른 변형에 이어 적용하지 않는다. 인물·가구·정보 ID, seed, scenario_id, 초기 날짜, 관계, 다른 값, 현장·접촉망은 F00과 같다. 실험 라벨 C01–C08은 결과 파일명/외부 목록에 둔다.

초기 세계·설정 해시와 관련 결속값은 변경된 입력으로 재계산해야 한다. 이 파생 메타데이터 차이는 두 번째 원인 입력으로 세지 않는다. 다른 변형의 체크포인트를 재사용하지 않는다. 원인 입력 차이와 해시 등 파생 차이를 별도로 열거한다.

| ID | F00에서 바꾸는 유일한 원인 입력 | 기존값 → 비교값 | 직접 확인할 경로 |
|---|---|---|---|
| C01 | P13 `trait_scores.risk_taking` | 50 → 80 | P13의 A04·A11 위험 구성요소 K와 효용·선택 |
| C02 | P04 `trait_scores.empathy` | 50 → 80 | P04가 실제 A04 요청에 응답할 때 care·응답 효용·선택·제공량 |
| C03 | P01 `value_scores.family_protection` | 70 → 90 | P01의 A04·A11 가치 구성요소 V와 선택; 제공자 성향 효과로 해석하지 않음 |
| C04 | P04 `value_scores.life_protection` | 50 → 80 | P04의 A04 응답 care·효용·실제 제공량 |
| C05 | P04 `value_scores.community_survival` | 50 → 80 | P04의 A04 응답 care·효용·실제 제공량 |
| C06 | P04 `value_scores.family_protection` | 70 → 90 | 음성 대조: 동일 최초 요청에 대한 P04의 A04 응답 공식은 이 입력을 직접 읽지 않음 |
| C07 | P01의 P04에 대한 `request_success_expectation.belief_value` | 80 → 20 | 해당 A04의 기대 이익 M·전체 점수·선택 및 실행 후 기존 M5 학습 |
| C08 | P13의 G에 대한 `theft_access.confidence` | 100 → 60 | 유효 접근값 `80×60/100=48`; A11(G)의 접근 조건 미충족과 제외 사유 |

C01–C08은 각자 초기 세계에서 **첫 하루만** 진행하는 비교 조건이다. 선택 변경 후 발생하는 행동·목격·기억 차이는 단일 원인 입력에서 이어진 결과일 수 있지만, 서로 다른 행동의 M4 결과를 동일 행동의 수행능력 차이처럼 비교하지 않는다. 근접 동점 추첨의 후보 집합·가중치·난수 근거도 남긴다.

P04 응답 비교는 실제로 생성·선택·실행된 P01의 A04 요청을 관찰하는 경로로 잡는다. 미선택 행동을 강제로 제출하거나 별도로 실행한 결과를 실제 일일 묶음의 원문으로 가장하지 않는다. 해당 경로가 실행되지 않으면 `NOT_EXERCISED`로 기록하고 그 비교를 PASS로 마감하지 않는다.

### 최초 하루의 수식 대조 기준 — 실행 결과 아님

아래 수치는 현행 정수식과 이 문서의 초기 입력을 대입한 설계 점검값이다. 실제 엔진·해시·난수·거래 검증을 대체하지 않는다.

- P01의 식량 압력은 54다. F00의 A04(P04)는 `N=54, G=100, V=58, R=55, M=80, K=14, C=0, T=25`로 효용 5,795다.
- F00의 P01 A11(G)는 `N=54, G=100, V=-15, R=66, M=80, K=17, C=47, T=50`로 효용 3,570이다. A00은 0이다. 따라서 P01의 A04(P04)는 근접 동점 범위 500 밖에서 우세하도록 구성했다.
- P04의 최초 여유분은 90이며 P01의 요청량은 10이다. F00에서 `care=50`, `relation_score=30`, `reserve_cost=11`, 응답 효용은 1,080이다. C02·C04·C05는 `care=58`, 응답 효용 1,240이 된다. 실제 제공량은 이후 자원 경합을 거쳐 원장으로 확인한다.
- C06에서 위 단일 응답의 care·여유분·관계·응답 효용은 같아야 한다. 전체 세계 해시나 전체 기록의 바이트 동일성을 요구하는 대조가 아니다. P04 자신의 훗날 판단에 가족보호 값이 미치는 효과까지 부정하지 않는다.
- C07은 P01의 A04 점수를 600 낮추지만 여전히 위 A11보다 우세하다. C03은 A04와 A11의 V를 각각 63, -12로 만든다. 이 두 비교 모두 다른 행동이 반드시 나와야 한다는 조건을 두지 않는다.

## 8. 실행 준비·기록·판정

### 구현 승인 뒤의 실행 순서

1. F00 및 8개 비교 입력을 위 명세로 만들고 Schema 5·초기 하루 경계·설정 결속·단일 원인 입력 차이를 검증한다.
2. F00은 28일을 요청해 완료된 일수와 중단 이유를 관찰한다. 처음부터 28일 완주를 보장한 생존 시나리오는 아니다.
3. 각 비교는 F00과 같은 초기 시점에서 하루만 진행하고, 후보·응답·실제 묶음 원문을 대응시킨다.
4. F00을 동일 입력으로 다시 실행해 재현성을 확인한다. 7일 완료 시점이 있으면 해당 체크포인트에서 나머지 21일을 요청해 연속 실행과 대조한다. 그 전에 중단됐다면 재개 비교가 수행되지 않았음을 명시한다.

이 순서는 준비안이다. 이번 문서 작성 단계에서 5가구 실행이나 새 실행 시험을 수행했다는 의미가 아니다.

### 필수 관찰 기록

- 각 인물의 판단 후보·제외 사유, N/G/V/R/M/K/C/T, 최종 효용·선택·추첨 근거, 읽은 정보 ID와 입력 기본값 사용 내역.
- A04의 요청량, 응답별 `source_stock_units`, `reserve_need_units`, `surplus_units`, `care_score`, `relation_score`, `reserve_cost`, `grant_utility`, 응답 결정·허용량·실제량.
- 원장으로 각 저장소의 하루 시작량·유입·유출·생활 소비·마감량을 연결한다. 모든 저장소를 합친 초기 398과 누적 실제 소비·잔량의 보존도 확인한다.
- **10일 필요량은 개별 응답의 계산 기준이다.** 현행 M4는 같은 저장소의 구호 합산에도 여유분 상한을 적용한다. 그러나 절도·다른 거래·이후 생활 소비까지 처리한 마감 잔량이 10일치로 보장되는 것은 아니다. 개별 응답 허용량의 합을 실제 지급량으로 사용하지 않는다.
- A11의 시도량·실제량·흔적·직접 목격자, 접촉으로 전달된 내용과 수용 여부, 기억·관계·감정·규범 압력·주간 변화.
- A04의 `request_success_expectation` 갱신과 A11에서 현재 갱신되지 않는 재고 믿음을 구별한다. 반복 선택만으로 학습 부재를 단정하지 않는다.
- 완료된 하루와 실패한 하루를 구분하고, 실패 단계·원문 처리 상태·마지막 완료 체크포인트를 남긴다.

### 판정의 구분

| 구분 | 조건 |
|---|---|
| 입력 준비 PASS | 모든 초기 참조·정렬·카운터·값 범위·목표·정보·현장·접촉·해시 결속 검증을 통과 |
| 비교 경로 PASS | 해당 입력을 읽는 경로가 실제 실행되고 현행 계산·기록 계약에 맞음; 선택 유지도 허용 |
| `NOT_EXERCISED` | 비교하려던 실제 판단·응답 경로가 실행되지 않음; 해당 비교 PASS로 대체하지 않음 |
| `COMPLETED` | 요청한 28일을 모두 확정함 |
| 건강 경계 중단 | 기존 M5 건강 불변식에서 `ok=false`가 발생하고 해당 날을 확정하지 않으며 직전 완료 세계를 보존함; 기간 완주와 별도로 보고 |
| BLOCKER | 잘못된 초기 참조·후보 누락, 계약 밖 `ok=false`, 원장 보존 실패, 알 수 없는 사건의 직접 반영, 하루 부분 확정, 저장·재개 불일치, 단일 입력 비교 오염, 필요한 관찰 원문 누락 |

모든 `ok=false`를 건강 경계의 정상 중단으로 포장하지 않는다. 성공한 묶음 안의 개별 `INVALIDATED`, A04 거절, A11 무획득은 일일 실행 오류와 구별한다. 어떤 인물이 거절하거나 절도를 하지 않았다는 이유로 규칙·seed를 결과에 맞춰 변경하지 않는다.

## 9. 코드 근거와 다음 검토

기준 main의 다음 경로와 대조했다.

- [M6-0 승인 계약](../decisions/m6-0-v0.2.md)
- [후보 생성·효용](../../src/simulation/decision/decision_engine.gd), [현행 판단 상수](../../src/simulation/decision/m3_decision_rules.gd)
- [주관적 정보 유효값](../../src/simulation/decision/subjective_fact_index.gd), [요청·절도 수량](../../src/simulation/action/intent_parameterizer.gd)
- [A04 응답](../../src/simulation/action/response_evaluator.gd), [묶음 자원 경합](../../src/simulation/action/atomic_action_resolver.gd)
- [기존 사회적 반영](../../src/simulation/social/m5_effects.gd), [평가·경험 압력](../../src/simulation/social/m5_appraisal.gd)
- [초기 입력](../../src/simulation/autonomy/m60_scenario.gd), [하루 경계](../../src/simulation/autonomy/m60_checkpoint.gd), [현장·접촉 설정](../../src/simulation/autonomy/m60_config.gd), [고정 현장 공급](../../src/simulation/autonomy/m60_presence_issuer.gd)

B의 다음 검토 대상은 이 문서의 초기 수치·정보·관계·현장·8개 비교 조건과 현행 계약의 적합성이다. 구현·실행 결과에 대한 PASS는 아직 없다. 검토·사용자 결정 이후 실행 입력과 필요한 관찰 수단의 구현 범위를 정한다.
