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
rounded: { xs: 6, sm: 8, md: 12, lg: 16, xl: 22, 2xl: 28 }
---

# Design System: Lumen (Still)

Lumen의 UI는 개인 디자인 시스템 **Still**을 따릅니다. 원본은 위 `source`의 Design System 아티팩트이고, 값과 규칙은 원본이 항상 우선입니다. 이 문서는 Lumen에 어떻게 옮겼는지만 적습니다.

## 1. 코드 위치
- `Lumen/Lumen/DesignSystem/LumenTokens.swift`: 모든 토큰. 색(`LumenTokens.Palette`), 간격(`Space`), 반경(`Radius`), 모션(`Motion`), 상태(`State`), 글자(`LumenTextStyle`, `LumenFont`, `.lumenText`), 깊이(`.lumenCard`, `.lumenPopover`, `LumenPanelBackground`).
- `Lumen/Lumen/DesignSystem/LumenComponents.swift`: Still 컴포넌트 명세를 옮긴 부품. `LumenIcon`, `LumenButtonStyle`, `LumenIconButton`, `LumenBadge`, `LumenBanner`, `LumenSegmentedControl`, `LumenListRowStyle`, `LumenSwitchStyle`, `.lumenFieldChrome`.
- `Lumen/Lumen/DesignSystem/Fonts/`: SUIT, Geist Mono(원본 woff2를 TTF로 변환, OFL 라이선스 동봉). 앱 시작 시 `LumenFont.register()`로 등록합니다.
- `Lumen/Lumen/Assets.xcassets/Icons/`: Lucide 아이콘(`lucide-<이름>`, 선 굵기 1.5, 템플릿 이미지). 라이선스는 `DesignSystem/Icons/Lucide-LICENSE.txt`.

## 2. 규칙
- **값은 토큰으로만.** 뷰에서 RGB, 글자 크기, 반경을 새로 만들지 않습니다. 필요한 값이 없으면 Still 원본에 있는지 먼저 확인합니다.
- **테마는 시스템 설정을 따릅니다.** 모든 색은 다크·라이트 값을 함께 가진 동적 색이라 macOS 외관이 바뀌면 자동으로 따라갑니다.
- **패널은 불투명합니다.** 떠 있는 패널은 `bg` + `border-subtle`, 반경 `xl`(22, 연속 곡률). 그림자는 NSPanel의 `hasShadow`가 맡습니다. 글래스·광원·그라디언트는 쓰지 않습니다.
- **brand(틸)는 한 화면에 한 곳만** 강조합니다. 선택된 행, 주요 버튼, 오늘 날짜 같은 자리입니다.
- **상태는 색만으로 구분하지 않습니다.** Jira 상태는 할 일(무채색) · 진행 중(`info`) · 완료(`success`)이고 항상 아이콘과 글자를 함께 붙입니다. 상태에 brand를 쓰지 않습니다.
- **차트·분류 색은 `chart-1`부터 순서대로** 씁니다(Jira 프로젝트, 캘린더 종류). 다섯을 넘으면 `chartOther`. 계열 색은 점·선·막대에만 쓰고 글자는 `ink` 계열입니다.
- **아이콘은 Lucide만.** 크기는 16 / 20 / 24. 예외: 메뉴바의 날짜 숫자 아이콘(`17.square.fill`)은 Lucide에 없어 SF Symbol을 씁니다.
- **모션**은 150 / 240 / 360ms와 Still 곡선(`Motion.easeOut/easeIn/easeMove`)만 씁니다. 반복 애니메이션(스피너, 반짝임)은 쓰지 않습니다.
- **보이스**는 해요체입니다. 날짜 `2026. 10. 17 (토)`, 시간 `오후 2:30`, 범위는 반각 대시(`–`)를 씁니다.
