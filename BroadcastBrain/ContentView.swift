import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(theme.sidebarCollapsed ? 68 : 260)
        } detail: {
            detailView
        }
        .background(Color.bgBase)
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedSurface {
        case .live:     LivePaneView()
        case .squads:   SquadsView()
        case .research: ResearchCenterView()
        case .archive:  ArchivesListView()
        }
    }
}
