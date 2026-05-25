---
name: Lumen
colors:
  primary: "#7B6BFF"
  primary-soft: "#B5A8FF"
  secondary: "#FFB454"
  background: "#16122A"
  surface: "rgba(255, 255, 255, 0.04)"
  text-primary: "#F2EEFF"
  text-secondary: "#B6AED6"
  text-muted: "#736C90"
typography:
  family: "System Default (.SF NS)"
  body: { size: "11px", weight: 400 }
  kbd: { size: "10px", weight: 500 }
  title: { size: "16px", weight: 600 }
rounded:
  window: "16px"
  card: "10px"
  row: "8px"
  kbd: "4px"
  appTile: "6px"
---

# Design System: Lumen

Lumen은 메뉴바에서 활성화되는 단일 패널 정책의 macOS용 런처 및 유틸리티 앱입니다. 복잡한 UI 요소를 최소화하고 작업의 맥락을 끊지 않는 투명 및 글래스모피즘(Glassmorphism) 기반 디자인을 따릅니다.

## 1. Visual Theme & Atmosphere
- **Atmosphere**: 어둡고 깊은 우주 느낌의 배경(`##16122A`) 위에 보라빛(`Accent.violet`)과 앰버(`Accent.amber`) 그라데이션 광원을 배치하여 시각적인 집중도를 높이고 프리미엄한 감성을 제공합니다.
- **Glassmorphism**: 패널 배경은 약 `72%` 불투명도의 반투명 재질과 시스템 블러를 결합하여 흐릿하면서도 뒷배경과 자연스럽게 녹아듭니다.

## 2. Color Palette & Semantic Roles
- **BG (Backgrounds)**
  - `window`: `#16122A` (opacity 72%) - 전체 패널 배경.
  - `card`: `#FFFFFF` (opacity 4%) - 정보 카드 섹션 배경.
  - `rowActive`: `#FFB454` (opacity 10%) - 항목 호버/활성화 배경.
  - `sidePanel`: `#FFFFFF` (opacity 2%) - 사용량 및 히스토리 사이드 패널.
  
- **Accent (Brand Colors)**
  - `violet`: `#7B6BFF` - 기본 브랜드 컬러, 메인 강조용.
  - `violetSoft`: `#B5A8FF` - 텍스트 링크 및 마일드한 강조.
  - `amber`: `#FFB454` - 게이지 활성화 마감 및 엔드포인트 도트.
  
- **Text Color**
  - `primary`: `#F2EEFF` - 일반 본문 텍스트.
  - `secondary`: `#B6AED6` - 레이블 및 비강조 본문.
  - `muted`: `#736C90` - 캡션 및 플레이스홀더 성격의 정보.

## 3. Typography Rules
- **Font Family**: macOS 기본 시스템 샌프란시스코 폰트 사용.
- **Title (16px, Semibold)**: 주요 메트릭 및 통계 수치 강조.
- **Section Label (10px, Medium, Tracking 1.0, Uppercase)**: 정보 구획 명칭.
- **Body & Row (11px, Regular)**: 일반 리스트 행 및 결과 텍스트.
- **Kbd / Small (10px, Medium)**: 키보드 단축키 및 부가 지표.

## 4. Component Styles
- **Information Card**: `card` 배경, `stroke` (보라 10% 불투명도) 보더, `Radius.card` (10px) 라운딩 처리.
- **List Row**: `row` 라운딩 (8px), 호버 시 `rowActive` 채우기 및 `Accent.amber` 스트로크 처리.
- **Sparkline Chart**: `Accent.violet` 페이드 그라데이션 채우기 영역, `Accent.violet`에서 `Accent.amber`로 흘러가는 2.5 두께의 소프트 라인.

## 5. Do's and Don'ts
- **NEVER**: 순수 흰색 및 검은색을 베이스로 사용하여 화면 대비가 너무 튀거나 흐려지게 하지 말 것.
- **ALWAYS**: 둥근 모서리 곡률(`16px` / `10px` / `8px`)을 대조군 없이 혼용하지 말고 지정된 토큰을 유지할 것.
- **ALWAYS**: UI/UX가 반응적이도록 애니메이션과 호버 효과를 정밀하게 줄 것.
