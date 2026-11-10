---
name: Lumen
system: Still
source: https://claude.ai/artifact/C5wzMuhnZkpxFd4TUVR2TA
colors:
  bg: { dark: "#0a0a0b", light: "#ffffff" }
  surface: { dark: "#141415", light: "#f5f5f7" }
  surface-raised: { dark: "#1c1c1e", light: "#ffffff" }
  border-subtle: { dark: "#2c2c2e", light: "#e5e5ea" }
  ink: { dark: "#f5f5f7", light: "#111113" }
  ink-muted: { dark: "#a1a1a6", light: "#5d5d63" }
  ink-faint: { dark: "#8a8a90", light: "#6e6e73" }
  brand: { dark: "#2fd3b5", light: "#0a7466" }
typography:
  sans: "SUIT Variable"
  mono: "Geist Mono"
  body: { size: "16px", lineHeight: "26px", weight: 400 }
  label: { size: "14px", lineHeight: "20px", weight: 500 }
  caption: { size: "12px", lineHeight: "16px", weight: 400 }
rounded: { xs: 6, sm: 8, md: 12, lg: 16, xl: 22 }
---

# Design System: Lumen (Still)

Lumen의 UI는 개인 디자인 시스템 **Still**을 따릅니다. 원본은 위 `source`의 Design System 아티팩트이고, 값과 규칙은 원본이 항상 우선입니다. 이 문서는 Lumen에 어떻게 옮겼는지와 Lumen만의 예외를 적습니다.

## 1. 코드 위치
모두 `Lumen/Lumen/DesignSystem/` 아래에 있습니다.

- `LumenTokens.swift`: 색(`LumenTokens.Palette`), 간격(`Space`), 반경(`Radius`), 모션(`Motion`), 상태(`State`), `LumenShape`.
- `LumenTypography.swift`: 글자(`LumenTextStyle`, `LumenWeight`, `LumenFont`, `.lumenText`).
- `LumenSurface.swift`: 깊이(`.lumenCard`, `.lumenElevation`), 구분선(`LumenHairline`), 패널 바탕(`LumenPanelBackground`, `.lumenPanel`, `LumenGlassFill`).
- `LumenDensity.swift`: 밀도·테마·글래스 값과 저장(`LumenUIStore`, `LumenDensity`, `LumenAppearance`, `LumenGlass`).
- 부품: `LumenIcon.swift`, `LumenButton.swift`(`LumenButtonStyle`, `LumenIconButton`), `LumenStatus.swift`(`LumenBadge`, `LumenBanner`, `LumenDot`), `LumenControls.swift`(`LumenSegmentedControl`, `LumenSwitchStyle`, `LumenRadioGroup`), `LumenList.swift`(`LumenListRowStyle`, `LumenSectionLabel`, `LumenEmptyState`, `LumenEmptyCard`), `LumenForm.swift`(`LumenHint`, `LumenSettingRow`, `LumenLabeledField`, `LumenTextField`, `.lumenFieldChrome`), `LumenInput.swift`(`LumenInputField`, `LumenTextArea`), `LumenChrome.swift`(`WindowDragArea`, `LumenPanelHeader`, `LumenKbd`, `LumenFooterBar`), `LumenToast.swift`, `LumenDateFormat.swift`(`LumenTime`, `LumenDateFormat`).
- 설정 탭 뼈대는 디자인 시스템 밖 `Features/Settings/SettingsFormParts.swift`(`SettingsTabContent`, `SettingsSection`, `SwitchRow`)에 있습니다.
- `Fonts/`: SUIT, Geist Mono(원본 woff2를 TTF로 변환, OFL 라이선스 동봉). 앱 시작 시 `LumenFont.register()`로 등록합니다.
- `Lumen/Lumen/Assets.xcassets/Icons/`: Lucide 아이콘(`lucide-<이름>`, 선 굵기 1.5, 템플릿 이미지). 라이선스는 `DesignSystem/Icons/Lucide-LICENSE.txt`.

## 2. 규칙
- **값은 토큰으로만.** 뷰에서 RGB, 글자 크기, 반경, 간격 숫자를 새로 만들지 않습니다. 필요한 값이 없으면 Still 원본에 있는지 먼저 확인하고, 있으면 그 값으로 토큰을 더합니다.
  - **예외 하나: `Palette.hover`.** 줄과 조용한(ghost) 버튼에 마우스를 올렸을 때 덧씌우는 반투명 막입니다(다크 흰색 6%, 라이트 `ink` 5%). Still에는 hover 색이 없고 줄에 `surface-raised`, 버튼에 `surface`를 깔라고 합니다. 그런데 Lumen은 같은 부품을 `bg`, `surface`, `surface-raised` 위에 모두 올리고, 라이트에서는 `bg`와 `surface-raised`가 같은 흰색이라 불투명 색으로는 hover가 안 보이는 자리가 생깁니다. 새 hover 채움도 `Palette.hover`를 씁니다. 불투명한 면 색을 쓰지 않습니다.
- **테마와 패널 배경은 3장을 따릅니다.** 모든 색은 다크·라이트 값을 함께 가진 동적 색이라 외관이 바뀌면 따라갑니다.
- **떠 있는 패널은 `.lumenPanel()` 하나로 그립니다.** 반경 `xl`(22, 연속 곡률), `border-subtle` 테두리, 배경은 글래스(3장). 그림자는 NSPanel의 `hasShadow`가 맡습니다. 광원·그라디언트는 쓰지 않습니다.
- **brand(틸)는 한 화면에 한 곳만** 강조합니다. 선택된 행, 주요 버튼, 오늘 날짜 같은 자리입니다.
- **상태는 색만으로 구분하지 않습니다.** 일정 항목의 상태는 할 일(무채색) · 진행 중(`info`) · 완료(`success`)이고 항상 아이콘과 글자를 함께 붙입니다. 상태에 brand를 쓰지 않습니다. 경고 값에는 `triangle-alert` 아이콘을 붙입니다.
- **차트·분류 색은 `chart-1`부터 순서대로** 씁니다(일정 묶음: 캘린더 하나, Jira 프로젝트 하나 등. `ScheduleStore.groupColors`가 켜진 플러그인 순서대로 배정). 다섯을 넘으면 `chartOther`. 계열 색은 점·선·막대에만 쓰고 글자는 `ink` 계열입니다. 차트 영역 채움은 `brandSoft`입니다(Still 규칙).
- **아이콘은 Lucide만.** 크기는 `LumenIcon.Size`(Still 16 / 20 / 24, 촘촘한 밀도에서 함께 줄어듦). 메뉴바와 메뉴 아이콘은 밀도와 상관없이 16입니다(`LumenIcon.nsImage`). 예외: 메뉴바의 날짜 숫자 아이콘(`17.square.fill`)은 Lucide에 없어 SF Symbol을 씁니다.
- **모션**은 150 / 240 / 360ms와 Still 곡선(`Motion.easeOut`, `Motion.easeMove`)만 씁니다. 반복 애니메이션(스피너, 반짝임)은 쓰지 않습니다.
- **보이스**는 해요체입니다. 날짜 `2026. 10. 17 (토)`, 시간 `오후 2:30`, 범위는 반각 대시(`–`)를 씁니다. 날짜 글은 `LumenDateFormat`에, 상대 시간("방금", "어제 오후 2:30")은 `LumenTime.relative`에 더합니다. 뷰에 따로 `DateFormatter`를 두지 않습니다.

## 3. 화면 밀도, 배경 글래스, 테마 (설정 > UI)
모두 고르는 즉시 반영돼요. 값은 `LumenUIStore`(Observation)에 있고, 토큰을 읽는 화면은 바뀔 때 알아서 다시 그려져요. 열려 있는 패널 크기는 `PanelWindowController.applyDensityToPanels()`가 맞춰요.

- **밀도 4단계** (`LumenDensity`)

| 단계 | 글자(목록 제목/보조) | 간격 | 창 크기 |
|---|---|---|---|
| 아주 촘촘하게 (`compact`) | 13 / 11px — Still 밖 예외 | Still의 0.5배 | 예전 Lumen 크기 |
| 촘촘하게 (`cozy`, 기본값) | 14 / 12px — Still 단계 안 | 0.67배 | 예전 크기에 가깝게 |
| 보통 (`regular`) | Still 그대로 | 0.75배 | 중간 |
| 넓게 (`spacious`) | Still 그대로 | Still 그대로 | Still 크기 |

- 줄인 세 단계의 간격은 8 미만이면 2 단위, 그 이상이면 4 단위로 맞춰요. 넓게는 맞추지 않고 Still 값을 그대로 써요.
- 뷰에서는 숫자를 직접 쓰지 않고 토큰만 써요. 간격은 `Space.*` / `Space.scaled(n)`, 창·열 너비와 헤더 높이 같은 큰 치수는 `Space.size(n)`, 아이콘은 `LumenIcon.Size.*.points`, 창 크기는 `Constants.*WindowSize`예요. `n`에는 넓게(Still) 기준 값을 적어요.
- **밀도에 따라 달라지는 값은 `static let`이나 저장 프로퍼티에 담지 않아요.** 한 번 계산돼 고정되면 밀도를 바꿔도 그대로예요. 고정 숫자(예: 달력 막대 사이 2pt)만 `let`으로 둬요.
- 반경과 색은 모든 밀도에서 같아요. 그림자 여유 공간도 간격 토큰이 아니에요. 그림자는 밀도에 따라 줄지 않으므로, 패널 안에서 그림자를 직접 그리는 뷰는 고정 여백을 둬요(`ToastBody.shadowRoom`).
- **배경 글래스** (`LumenGlass`, `LumenGlassFill`): 떠 있는 패널과 설정 창에 적용해요. 투명도를 슬라이더로 0~80% 사이에서 골라요(기본 70%, 0%면 끔). 시스템 블러 위에 `bg`를 (1 − 투명도) 불투명도로 깔아요. 글래스가 켜져 있으면 패널 안 사이드바·하단 바는 면을 따로 깔지 않고 구분선으로만 나눠요(`Palette.panelSurface`). 리소스 모니터(`.lumenPanel(glass: false)`)와 카드·팝오버·입력창은 불투명 그대로예요.
- **테마** (`LumenAppearance`): 시스템 설정 따름 / 다크(기본값) / 라이트. `NSApp.appearance`를 바꿔요.

## 4. 공통 부품 쓰는 법
새 화면은 아래 부품부터 찾아요. 같은 모양을 뷰마다 다시 만들지 않아요.

| 부품 | 쓰는 곳 |
|---|---|
| `.lumenPanel(glass:)` | 떠 있는 패널의 루트 뷰에 한 번. 크기가 고정된 패널(일정, 리소스 모니터)은 `.frame(width:height:)`를 그 앞에 둬요 |
| `LumenPanelHeader(icon:title:accessory:trailing:)` | 패널 맨 위 줄. 빈 곳을 끌면 창이 움직여요. 누를 수 있는 것은 `trailing`에만 둬요. 나머지는 끌기를 위해 클릭을 받지 않아요 |
| `Space.panelHeader` | 패널 머리 줄 높이. 옆에 줄을 맞춰야 하는 머리(노트 사이드바)도 이 값을 써요 |
| `LumenFooterBar` | 패널 아래 단축키 안내 줄. 실제로 동작하는 키만 적어요 |
| `LumenHairline(.vertical)` | 열 사이 1px 구분선 |
| `Space.rowY` | 목록 줄, 설정 줄의 세로 여백 |
| `.lumenRowTitle(selected:style:)` | 고를 수 있는 줄의 제목 글자 |
| `LumenIconButton(...).inRow()` | 한 줄짜리 목록 줄 안의 아이콘 버튼 |
| `LumenEmptyCard(icon:text:detail:tone:)` | 카드 목록이 비었을 때 그 자리. 화면 전체가 비었으면 `LumenEmptyState` |
| `LumenHint(_:)` | 설정 묶음이나 입력 칸 아래 도움말 |
| `LumenSettingRow(title:description:) { 컨트롤 }` | 왼쪽 제목, 오른쪽 컨트롤. 여백과 카드는 없어요. 한 카드에 한 줄이면 `.padding(Space.pad).lumenCard()`, 여러 줄이면 `Space.rowY` 여백과 `LumenHairline` |
| `LumenLabeledField(label:hint:) { LumenTextField(...) }` | 라벨이 붙은 테두리 입력 칸. `LumenTextField(focus:)`는 호출한 쪽이 포커스를 옮겨야 할 때만 넘겨요 |
| `LumenInputField` | 패널 맨 위의 테두리 없는 검색 입력. AppKit 기반이라 패널의 첫 응답자 처리와 가운데 placeholder가 맞아요. `LumenTextField`와 합치지 않아요 |
| `SettingsTabContent { SettingsSection … }` | 설정 탭 본문(배치만). 바로 저장되는 탭은 각자 `.onAppear { action.hideActionBar() }` |

- 여러 모양을 받는 부품은 기본 칸을 기본값 클로저(`= { EmptyView() }`)로 받아요. 조건부 확장 init을 따로 만들지 않아요.
- 줄 안의 배지가 글자를 잘라 먹으면 배지에 `.fixedSize()`를 주고 제목이 두 줄로 내려가게 해요(일정 목록 줄).
