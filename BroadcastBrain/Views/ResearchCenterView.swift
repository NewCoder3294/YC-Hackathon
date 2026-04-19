import SwiftUI

struct ResearchCenterView: View {
    @Environment(AppStore.self) private var store
    @State private var showingNotes = false

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            ) {
                if store.spottingMode != nil {
                    notesToggle
                }
            }

            HStack(spacing: 0) {
                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showingNotes && store.spottingMode != nil {
                    Rectangle().fill(Color.bbBorder).frame(width: 1)
                    notesColumn
                        .frame(width: 360)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(Color.bgBase)
        .animation(.easeInOut(duration: 0.2), value: showingNotes)
    }

    @ViewBuilder
    private var modeContent: some View {
        if store.spottingMode == nil {
            ZStack {
                Color.bgBase
                DottedGrid(
                    dotColor: Color.textPrimary.opacity(0.28),
                    spacing: 22,
                    dotSize: 2.4
                )
                CommentatorStylePickerView()
            }
        } else if store.spottingMode == .stats {
            StatsFirstSpottingBoardView()
        } else if store.spottingMode == .story {
            StoryFirstSpottingBoardView()
        } else if store.spottingMode == .tactical {
            TacticalSpottingBoardView()
        }
    }

    private var notesToggle: some View {
        Button(action: { showingNotes.toggle() }) {
            HStack(spacing: 5) {
                Image(systemName: showingNotes ? "chevron.right" : "note.text")
                    .font(.system(size: 10, weight: .semibold))
                Text(showingNotes ? "HIDE" : "NOTES")
                    .font(Typography.chip)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(showingNotes ? Color.live : Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(showingNotes ? Color.white : Color.textPrimary)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var notesColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOTES")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                Text("autosaved")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }

            TextEditor(text: Binding(
                get: { store.currentSession.notes },
                set: { store.updateNotes($0) }
            ))
            .font(Typography.body)
            .foregroundStyle(Color.textPrimary)
            .scrollContentBackground(.hidden)
            .padding(10)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
        }
        .padding(16)
        .background(Color.bgBase)
    }
}
