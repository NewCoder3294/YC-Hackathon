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
        if let id = store.selectedArchiveId,
           let archived = store.sessionStore.sessions.first(where: { $0.id == id }) {
            ArchiveDetailView(session: archived)
        } else {
            switch store.selectedSurface {
            case .live:     LivePaneView()
            case .research: ResearchCenterView()
            }
        }
    }
}
