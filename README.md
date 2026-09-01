# game

가상의 중세~르네상스 난세에서 한 개인의 선택과 변화가 주변 인물과 역사에 영향을 주는 개인 중심 시뮬레이션 게임 프로젝트다.

M0 기반 구현과 Linux·Windows 자동 검증을 완료했으며, Windows Godot 편집기에서의 수동 `F5` 실행도 확인했다. 이후 목표는 방대한 세계나 콘텐츠를 만드는 것이 아니라, 다음 인과 순환이 작은 범위에서 실제로 성립하는지 확인하는 것이다.

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
STATUS = M0 PASS
IMPLEMENTATION = PROJECT SKELETON / SMOKE TEST COMPLETE
AUTOMATED_VERIFICATION = LINUX + WINDOWS HEADLESS PASS
GUI_VERIFICATION = WINDOWS EDITOR F5 PASS / 2026-09-01
FIRST_PROTOTYPE = DROUGHT / PROVISIONAL
ENGINE = GODOT 4.7.2 STABLE STANDARD
LANGUAGE = STATICALLY TYPED GDSCRIPT
M1 = NOT AUTHORIZED
```

NPC, 가뭄, 자원 및 판단 시스템은 아직 구현하지 않았다.

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

## M0 범위

M0에는 다음만 포함한다.

- Godot 프로젝트 골격
- 정적 타입 경고 정책
- 최소 부팅 화면
- Headless smoke test
- Linux·Windows 자동 검증

다음 단계인 M1 상태 모델은 별도의 구현 승인이 있기 전까지 시작하지 않는다.
