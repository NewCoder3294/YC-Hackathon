import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
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
        case .plays:    PlaysSearchView()
        case .playsDB:  PlaysDBView()
        }
    }
}
