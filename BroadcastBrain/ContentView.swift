import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        @Bindable var bindable = store

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: theme.sidebarCollapsed ? 68 : 260)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.bgBase)
        .animation(.easeInOut(duration: 0.2), value: theme.sidebarCollapsed)
        .sheet(isPresented: $bindable.showNewMatchSheet) {
            NewMatchSheet()
                .environment(store)
        }
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
