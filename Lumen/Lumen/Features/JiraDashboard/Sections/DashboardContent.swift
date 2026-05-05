import SwiftUI

/// 대시보드 탭의 본문 — 3-column past/present/future + 하단 trend chart.
/// 헤더는 통합 JiraDashboardView가 한 번만 그리므로 여기엔 없다.
struct DashboardContent: View {
    let data: JiraDashboardData
    @Binding var selectedProject: String

    var body: some View {
        VStack(spacing: 0) {
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
