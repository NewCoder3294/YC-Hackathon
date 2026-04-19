import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    surfaceRow(title: "Live",     systemImage: "dot.radiowaves.left.and.right", surface: .live)
                    surfaceRow(title: "Research", systemImage: "book",                          surface: .research)
                }

                Section("ARCHIVES") {
                    ForEach(store.sessionStore.sessions) { session in
                        ArchiveRow(session: session, isSelected: store.selectedArchiveId == session.id)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedArchiveId = session.id }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.bgBase)

            Divider().background(Color.bbBorder)

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
        let selected = store.selectedArchiveId == nil && store.selectedSurface == surface
        return HStack {
            Image(systemName: systemImage)
                .foregroundStyle(selected ? Color.live : Color.textMuted)
                .frame(width: 18)
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if selected && surface == .live { LivePill() }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedArchiveId = nil
            store.selectedSurface = surface
        }
    }
}

struct ArchiveRow: View {
    let session: Session
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(Typography.statLabel)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                if !session.statCards.isEmpty {
                    Text("·").foregroundStyle(Color.textSubtle)
                    Text("\(session.statCards.count) cards")
                        .font(Typography.chip)
                        .foregroundStyle(Color.verified)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.bgHover : Color.clear)
    }
}
