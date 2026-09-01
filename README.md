# game

가상의 중세~르네상스 난세에서 한 개인의 선택과 변화가 주변 인물과 역사에 영향을 주는 개인 중심 시뮬레이션 게임 프로젝트다.

M0 기반, M1 상태 모델 및 M2 하루·식량 진행기를 완료했다. Linux·Windows 자동 검증과 Windows Godot 편집기의 수동 `F5` 실행도 확인했다. M3 최초 판단 엔진은 결과를 유도하지 않고 관찰하는 계약까지만 승인됐다. 이후 목표는 방대한 세계나 콘텐츠를 만드는 것이 아니라, 다음 인과 순환이 작은 범위에서 실제로 성립하는지 확인하는 것이다.

> 인물의 성향·상태·관계·기억 → 판단과 선택 → 사건의 결과 → 인물과 세계의 변화 → 이후의 다른 판단

## 장기 방향

- 배경은 가상의 중세~르네상스 판타지 세계다.
- 시대별로 큰 역사적 상황과 기준 역사인 `정사`가 존재한다.
- 정사는 강제되는 캐논이 아니라, 초기 조건에서 가장 그럴듯했던 기준 역사다.
- 플레이가 시작되면 플레이어와 NPC의 선택에 따라 역사는 달라질 수 있다.
- 플레이어와 NPC는 같은 세계 규칙에 묶인다.
- 플레이어는 능력치 특혜보다 더 세밀한 선택권과 정보 전달상의 특혜를 갖는다.
- 성향에 맞는 선택에는 이점이, 성향을 거스르는 선택에는 비용이 생긴다.
- 의미 있는 선택과 경험은 인물의 성향·관계·기억을 장기적으로 바꿀 수 있다.
- 단일 연대기 저장을 기본 방향으로 삼는다.
- 플레이어 사망 시 관계가 깊은 자녀·동료·부하로 이어가거나 연대기를 끝낼 수 있다.
- 생성형 AI나 LLM은 핵심 판단에 필수 요소가 아니다.

## 첫 잠정 프로토타입

첫 프로토타입은 `마을 1개·인간 NPC 60명`을 상한 범위로 삼는다. 최초 검증 사건은 가뭄이다.

세부 범위와 검증 기준은 [가뭄 프로토타입 설계](docs/drought-prototype-v0.md)에 기록한다.

## 현재 상태

```text
STATUS = M0 PASS / M1 PASS / M2 PASS
IMPLEMENTATION = FOUNDATION + STATE MODEL / SERIALIZATION + TIME / FOOD / HUNGER / HEALTH
AUTOMATED_VERIFICATION = LOCAL + LINUX + WINDOWS PASS
GUI_VERIFICATION = WINDOWS EDITOR F5 PASS / 2026-09-01
FIRST_PROTOTYPE = DROUGHT / PROVISIONAL
ENGINE = GODOT 4.7.2 STABLE STANDARD
LANGUAGE = STATICALLY TYPED GDSCRIPT
M1 = COMPLETE / PASS
M2 = COMPLETE / PASS
M3 = CONTRACT APPROVED / DETAILED SPEC NOT APPROVED / IMPLEMENTATION NOT AUTHORIZED
```

M1은 세 명의 기준 인물·가구·방향성 관계·사건·주관적 정보·기억을 정적 타입 상태로 표현한다. canonical JSON, SHA-256 상태 해시, 엄격한 ID·참조 검증과 M1-T01~T10을 포함한다.

M2는 schema 2의 자원 저장소와 거래 원장, 원자적 하루 진행, 결정론적 가구 내 식량 배분, 굶주림·건강 변화를 구현한다. 세 가구·여덟 명 fixture를 10일 진행하면 초기 식량 181 중 81을 소비하고 공동창고 100만 남는다. NPC 판단, 가뭄·생산·수확, 촌장 배급 결정, 절도 및 UI는 아직 구현하지 않았다.

M3 계약은 `A00 현재 행동 유지`, `A04 도움 요청`, `A11 절도`의 후보와 효용을 같은 규칙으로 계산하되, 특정 행동·효용 방향·이야기 결과를 합격 조건으로 삼지 않는다. 계산 정확성, 결정론, 주관적 정보 경계, 입력 상태 불변성과 감사 가능성만 기계적으로 판정한다. 반대 조건에서 나온 행동과 점수 변화는 정답이 아니라 관찰 결과로 기록한다. 세부 schema·수치·fixture와 코드는 후속 승인 전까지 작성하지 않는다.

Windows 편집기 실행 증거는 [M0 Windows GUI 검증 기록](docs/evidence/m0-windows-gui-2026-09-01.md)에 보존한다.

## 요구 환경

- [Godot 4.7.2 stable Standard](https://godotengine.org/download/archive/4.7.2-stable/)
- 최초 실행 대상: Windows x86_64
- C#/.NET 빌드가 아닌 Standard 빌드

프로토타입이 끝날 때까지 엔진 버전을 임의로 업그레이드하지 않는다.

## Windows에서 실행

1. Godot 4.7.2 Standard를 내려받아 압축을 푼다.
2. Godot 편집기에서 이 저장소의 `project.godot`을 연다.
3. `F6`이 아니라 `F5`로 프로젝트를 실행한다.

현재 화면에는 M0 기반 상태와 엔진 버전만 표시된다.

## Headless smoke test

저장소 루트에서 Godot의 콘솔 실행 파일 경로를 지정한다.

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path . --script res://tests/smoke_test.gd
```

성공하면 다음 형식의 메시지와 종료 코드 `0`을 반환한다.

```text
M0_SMOKE_PASS engine=4.7.2.stable.official...
```

메인 프로젝트 부팅도 별도로 확인할 수 있다.

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path . --quit-after 1
```

GitHub Actions는 공식 Godot 4.7.2 Standard 배포물의 SHA-256을 확인한 뒤 Linux와 Windows에서 두 검사를 모두 실행한다.

## M1 상태 모델 시험

Godot이 새 `class_name`을 등록하도록 headless editor scan을 한 번 수행한 뒤 M1 시험을 실행한다.

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --editor --path . --quit
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path . --script res://tests/m1_test_runner.gd
```

성공하면 `M1 PASS`와 종료 코드 `0`을 반환한다. frozen fixture의 canonical state SHA-256은 다음과 같다.

```text
6c581e746efb0c2fff6f81bc939ef84a0b60fd6021a94c79344de5d9d431926d
```

## M0 범위

M0에는 다음만 포함한다.

- Godot 프로젝트 골격
- 정적 타입 경고 정책
- 최소 부팅 화면
- Headless smoke test
- Linux·Windows 자동 검증

## M1 범위

M1에는 다음만 포함한다.

- `RefCounted` 기반 정적 타입 상태 모델
- 문자열 ID와 방향성 관계
- 세 명의 기준 fixture
- canonical JSON과 SHA-256 상태 해시
- JSON 저장 문자열의 검증·복원
- M1-T01~T10 자동 시험

## M2 시간·자원 시험

M1 시험과 같은 방식으로 editor scan 후 M2 시험을 실행한다.

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --editor --path . --quit
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path . --script res://tests/m2_test_runner.gd
```

성공하면 `M2 PASS`와 종료 코드 `0`을 반환한다. day-10 schema 2 상태의 frozen SHA-256은 다음과 같다.

```text
4a8aebeacebf9d9e63dce45fb8de73e46722ca6918089609e3e581c5e73ba26e
```

## M2 범위

M2에는 다음만 포함한다.

- schema 1 동결 직렬화와 schema 2 시간·자원 상태의 명시적 분리
- 식량 저장소, transfer·consumption 거래와 원장 대조
- 정수 비례 배분 및 날짜별 나머지 시작점 순환
- 굶주림과 지연된 건강 피해
- 실패 시 원본을 보존하는 원자적 하루 진행
- 세 가구·여덟 명의 10일 fixture
- M2-T01~T12 및 M2-R01~R08 자동 시험

M2의 계약과 구현 명세는 설계 결정 19·20으로 고정했다. M2는 NPC 판단, 가뭄, 생산, 촌장 배급 판단, 절도, 정보 전파, 기억 변화 또는 플레이 UI를 포함하지 않는다.
