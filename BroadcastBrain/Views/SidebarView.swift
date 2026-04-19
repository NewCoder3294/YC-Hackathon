import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    surfaceRow(title: "Live",     systemImage: "dot.radiowaves.left.and.right", surface: .live)
                    surfaceRow(title: "Squads",   systemImage: "person.2",                      surface: .squads)
                    surfaceRow(title: "Research", systemImage: "book",                          surface: .research)
                    surfaceRow(title: "News",     systemImage: "newspaper",                     surface: .news)
                    surfaceRow(title: "Archive",  systemImage: "archivebox",                    surface: .archive)
                    surfaceRow(title: "Plays",    systemImage: "sportscourt",                   surface: .plays)
                    surfaceRow(title: "Plays DB", systemImage: "tray.full",                     surface: .playsDB)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.bgBase)

            Divider().background(Color.bbBorder)

            Button(action: { store.presentSetup() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .foregroundStyle(Color.textMuted)
                        .font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NEW MATCH")
                            .font(Typography.chip)
                            .foregroundStyle(Color.textPrimary)
                        if let title = store.matchCache?.title {
                            Text(title.components(separatedBy: " · ").first ?? title)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.textSubtle)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(Color.bgBase)

            Button(action: { store.newSession() }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.textMuted)
                    Text("New Session")
                        .font(Typography.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(Color.bgBase)
        }
        .background(Color.bgBase)
    }

    private func surfaceRow(title: String, systemImage: String, surface: Surface) -> some View {
        // Archive surface is "selected" whenever the user has navigated there,
        // regardless of whether they're looking at the list or a specific session.
        let selected: Bool = {
            if surface == .archive {
                return store.selectedSurface == .archive
            }
            return store.selectedArchiveId == nil && store.selectedSurface == surface
        }()

        return HStack {
            Image(systemName: systemImage)
                .foregroundStyle(selected ? Color.live : Color.textMuted)
                .frame(width: 18)
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if selected && surface == .live && store.liveState == .listening { LivePill() }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedArchiveId = nil
            store.selectedSurface = surface
        }
    }
}
