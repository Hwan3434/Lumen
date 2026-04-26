import SwiftUI

/// Jira 대시보드 메인 뷰. 1160×840pt 글래스 패널.
///
/// 레이아웃: 56pt 헤더 → 3-column body (past 280 / present 480 / future 320)
///         → 102pt 하단 trend 차트.
///
/// 시간 축(과거 / 현재 / 미래)을 공간에 그대로 매핑해 사용자가 클릭 없이
/// 시선만 옮겨 정보를 스캔할 수 있게 한다.
struct JiraDashboardView: View {
    private var service: JiraService { JiraService.shared }
    @State private var selectedProject: String = PresentColumn.allKey

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)

            if service.isLoading && service.data == nil {
                JiraFullPanelLoading()
            } else if let msg = service.errorMessage, service.data == nil {
                JiraFullPanelError(message: msg) {
                    Task { await service.fetch(force: true) }
                }
            } else if let data = service.data {
                content(data)
            } else {
                JiraFullPanelEmpty()
            }
        }
        .frame(width: 1160, height: 840)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
        .onAppear { Task { await service.fetch() } }
    }

    @ViewBuilder
    private func content(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            JiraHeader(
                lastUpdated: data.lastUpdated,
                refreshing: service.isLoading,
                onRefresh: { Task { await service.fetch(force: true) } }
            )
            LumenHairline()
            HStack(spacing: 0) {
                PastColumn(data: data)
                Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                PresentColumn(data: data, selectedProject: $selectedProject)
                Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                FutureColumn(data: data)
            }
            .frame(maxHeight: .infinity)
            TrendChart(
                created: data.createdLast30,
                completed: data.completedLast30
            )
        }
    }
}
