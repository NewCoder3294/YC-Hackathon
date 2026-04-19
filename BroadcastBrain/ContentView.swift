import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                detailView
            }
            .background(Color.bgBase)

            if store.showingSetup {
                TeamSetupView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.showingSetup)
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
