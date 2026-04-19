import SwiftUI

/// Modal form presented when the commentator starts a new match session.
/// Captures sport, teams, tournament, and venue — saved as a `Match` on the
/// new `Session`.
struct NewMatchSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sport: Sport = .soccer
    @State private var homeTeam: String = ""
    @State private var awayTeam: String = ""
    @State private var tournament: String = ""
    @State private var venue: String = ""
    @State private var matchDate: Date = Date()
    @State private var hasDate: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            form
            footer
        }
        .frame(width: 520)
        .background(Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.live)
            Text("NEW MATCH")
                .font(Typography.sectionHead)
                .foregroundStyle(Color.textPrimary)
                .tracking(0.6)
            Spacer()
            Button(action: { store.showNewMatchSheet = false; dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSubtle)
                    .padding(6)
                    .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.bgSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            field("SPORT") {
                HStack(spacing: 6) {
                    ForEach(primarySports, id: \.self) { option in
                        sportPill(option)
                    }
                    Menu {
                        ForEach(Sport.allCases.filter { !primarySports.contains($0) }, id: \.self) { s in
                            Button(s.displayName) { sport = s }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(primarySports.contains(sport) ? "More" : sport.displayName.uppercased())
                                .font(Typography.chip)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(!primarySports.contains(sport) ? Color.textPrimary : Color.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(!primarySports.contains(sport) ? Color.live.opacity(0.12) : Color.bgSubtle,
                                    in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                !primarySports.contains(sport) ? Color.live : Color.bbBorder,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            HStack(spacing: 14) {
                field("HOME TEAM") {
                    textField("Argentina", text: $homeTeam)
                }
                field("AWAY TEAM") {
                    textField("France", text: $awayTeam)
                }
            }

            field("TOURNAMENT") {
                textField("2022 World Cup Final", text: $tournament)
            }

            field("VENUE") {
                textField("Lusail Stadium · Lusail, Qatar", text: $venue)
            }

            field("MATCH DATE") {
                HStack(spacing: 10) {
                    Toggle(isOn: $hasDate) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    if hasDate {
                        DatePicker("", selection: $matchDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    } else {
                        Text("Not set")
                            .font(Typography.chip)
                            .foregroundStyle(Color.textSubtle)
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider().background(Color.bbBorder)
            HStack(spacing: 10) {
                Button(action: { store.showNewMatchSheet = false; dismiss() }) {
                    Text("CANCEL")
                        .font(Typography.chip)
                        .tracking(0.6)
                        .foregroundStyle(Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.bgSubtle)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                        Text("CREATE MATCH")
                            .font(Typography.chip)
                            .tracking(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(Color.textPrimary)
                    .background(canSubmit ? Color.live : Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color.bgSubtle)
    }

    private var canSubmit: Bool {
        !homeTeam.trimmingCharacters(in: .whitespaces).isEmpty
            && !awayTeam.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var primarySports: [Sport] {
        [.soccer, .basketball, .baseball, .americanFootball, .hockey]
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .tracking(1.4)
            content()
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
    }

    private func sportPill(_ s: Sport) -> some View {
        Button(action: { sport = s }) {
            Text(s.displayName.uppercased())
                .font(Typography.chip)
                .tracking(0.5)
                .foregroundStyle(sport == s ? Color.textPrimary : Color.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(sport == s ? Color.live.opacity(0.15) : Color.bgSubtle,
                            in: Capsule())
                .overlay(
                    Capsule().stroke(
                        sport == s ? Color.live : Color.bbBorder,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard canSubmit else { return }
        let match = Match(
            sport: sport,
            homeTeam: homeTeam.trimmingCharacters(in: .whitespaces),
            awayTeam: awayTeam.trimmingCharacters(in: .whitespaces),
            tournament: tournament.trimmingCharacters(in: .whitespaces),
            venue: venue.trimmingCharacters(in: .whitespaces),
            matchDate: hasDate ? matchDate : nil
        )
        store.createSession(from: match)
        dismiss()
    }
}
