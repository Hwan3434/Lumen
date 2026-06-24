# Agent Guidelines: Lumen

이 문서(`AGENTS.md`)는 Google Antigravity AI 에이전트가 이 프로젝트(Lumen)를 분석하고 코드를 변경할 때 준수해야 하는 전역 지침입니다.

## 1. 프로젝트 아키텍처 및 기술 스택
- **Language & Framework**: SwiftUI (현재 Xcode 프로젝트 설정 기준 `SWIFT_VERSION = 5.0`, `MACOSX_DEPLOYMENT_TARGET = 26.2`).
- **Package Manager**: Swift Package Manager. Sparkle 자동 업데이트 및 MarkdownUI를 사용합니다.
- **Project Structure**:
  - `Lumen/Lumen/Core`: 앱 인프라, 키체인 자격증명 보관소 (`CredentialsStore`), 디렉터리 경로 (`LumenStorage`).
  - `Lumen/Lumen/DesignSystem`: 디자인 토큰 (`LumenTokens`), 커스텀 컴포넌트 (`LumenChrome`, `LumenInput`).
  - `Lumen/Lumen/Features`: 번역, 메모, 클립보드, 설정창 화면 구성 요소.
  - `Lumen/Lumen/Search`: 메인 검색 창 뷰 및 사용량 정보 패널 (`UsagePanelView`).
  - `Lumen/Lumen/Services`: 백그라운드 데이터 수집 서비스 (`AntigravityUsageService`, `OpenAIService`, `JiraService`).

## 2. 코드 스타일 및 구현 규칙
- **SwiftUI & State**: `@Observable` 매크로와 `Observation` 프레임워크를 기반으로 상태를 관리합니다. 불필요한 `@StateObject` 또는 `@ObservedObject` 사용을 피하십시오.
- **Concurrency**: `async/await` 및 `Task`를 기본 비동기 패턴으로 채택합니다. MainActor 격리가 필요한 UI 변경점은 확실히 `@MainActor` 혹은 `MainActor.run`으로 묶어야 합니다.
- **Clean Compilations**: Xcode 프로젝트 파일(`project.pbxproj`)을 임의로 변경하지 말고, 새로운 파일을 생성하거나 추가할 때 기존 폴더 구조에 맞추어 Xcode 타겟에 정확히 포함되도록 하십시오.
- **Maintain Documentation**: 변경과 직접 관련되지 않은 기존 주석, docstring, 그리고 마크업 문서는 손상되지 않도록 있는 그대로 보존해야 합니다.

## 3. 리소스 및 최적화
- **CPU & Memory**: 본 앱은 메뉴바 상주형 백그라운드 런처이므로 주기적인 파일 시스템 조회 시 캐시(`mtime` 기반 증분 동기화 등)를 활용하여 배터리 소모를 극대화로 줄여야 합니다.
- **Design Tokens**: UI 요소를 추가할 때는 반드시 `DESIGN.md` 및 `LumenTokens`에 사전 정의된 토큰을 조합하십시오. 하드코딩된 RGB 또는 HSL 값을 즉흥적으로 사용하지 마십시오.

## 4. 자격증명 관리 및 테스트
- 사용자의 API 키나 개인 정보는 코드 내에 절대 하드코딩해서는 안 됩니다. 현재 자가서명 빌드 정책상 Jira 자격증명은 `SecretStore` 파일 저장소에 저장하며, 이는 암호화가 아니라 로컬 파일 난독화와 owner-only 권한(`0600`)에 의존합니다.
- Xcode DerivedData로 인한 빌드 이슈 발생 시 `DerivedData/` 디렉터리를 청소하고 다시 빌드하는 절차를 권장하십시오.
