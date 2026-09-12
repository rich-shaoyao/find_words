//
//  PlayerSetupView.swift
//  find_words
//

import SwiftUI

struct PlayerSetupView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 16) {
            header
            playerList
            durationSection

            Button(startButtonTitle) {
                store.startGame()
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
            .disabled(!store.canStartGame)
            .opacity(store.canStartGame ? 1 : 0.5)
        }
        .padding(PartyTheme.screenPadding)
        .onAppear {
            if store.players.isEmpty {
                for _ in 0..<GameRules.minimumPlayers {
                    store.addPlayer()
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                RoundIconButton(systemName: "chevron.left") {
                    store.phase = .home
                }
                Spacer()
                RoundPill(text: "\(store.players.count) players")
                Spacer()
                Color.clear.frame(width: 42, height: 42)
            }

            Text("Who's playing?")
                .font(PartyTheme.display(34))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("Tap a name to change it.")
                .font(PartyTheme.regular(15))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var playerList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(store.players) { player in
                    playerRow(player)
                }

                if store.canAddPlayer {
                    Button {
                        withAnimation(.snappy) { store.addPlayer() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Player")
                        }
                        .font(PartyTheme.strong(17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Color.white.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(name: player.displayName, tint: player.tint, diameter: 42)

            TextField("Name", text: nameBinding(for: player.id))
                .font(PartyTheme.strong(19))
                .foregroundStyle(PartyTheme.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if store.players.count > GameRules.minimumPlayers {
                Button {
                    withAnimation(.snappy) { store.removePlayer(id: player.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(PartyTheme.coral)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var durationSection: some View {
        VStack(spacing: 8) {
            Text("Round length")
                .font(PartyTheme.strong(13))
                .foregroundStyle(.white.opacity(0.85))
                .textCase(.uppercase)
                .kerning(1)

            HStack(spacing: 8) {
                ForEach(GameRules.roundDurations, id: \.self) { duration in
                    durationChip(duration)
                }
            }
        }
    }

    private func durationChip(_ duration: Int) -> some View {
        let isSelected = store.roundDuration == duration
        return Button {
            store.roundDuration = duration
        } label: {
            Text("\(duration)s")
                .font(PartyTheme.strong(15))
                .foregroundStyle(isSelected ? PartyTheme.ink : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.16)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var startButtonTitle: String {
        store.canStartGame
            ? "Start · \(store.players.count) rounds"
            : "Need \(GameRules.minimumPlayers) players"
    }

    private func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { store.players.first(where: { $0.id == id })?.name ?? "" },
            set: { store.rename(id: id, to: $0) }
        )
    }
}
