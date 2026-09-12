//
//  RoundResultView.swift
//  find_words
//

import SwiftUI

struct RoundResultView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 14) {
            banner

            ScrollView {
                VStack(spacing: 8) {
                    if showsScoreboard {
                        Text("Scoreboard")
                            .font(PartyTheme.strong(13))
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .kerning(1.2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)

                        ForEach(Array(store.ranking.enumerated()), id: \.element.id) { index, player in
                            LeaderboardRow(rank: index + 1, player: player)
                        }
                    } else {
                        guesserGrid
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showsScoreboard {
                Button(store.isLastRound ? "See Final Results" : "Next Round") {
                    store.advance()
                }
                .buttonStyle(PartyButtonStyle(kind: .primary))
            }
        }
        .padding(PartyTheme.screenPadding)
    }

    // MARK: - State helpers

    private var showsScoreboard: Bool {
        if case .awaitingGuess = store.outcome { return false }
        return true
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        switch store.outcome {
        case .awaitingGuess:
            VStack(spacing: 8) {
                Text("🙌").font(.system(size: 56))
                Text("Who got it?")
                    .font(PartyTheme.display(30))
                    .foregroundStyle(.white)
                Text("The word was “\(store.word)”")
                    .font(PartyTheme.regular(16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

        case .guessed(let id):
            VStack(spacing: 8) {
                Text("🎉").font(.system(size: 60))
                Text("\(store.player(id: id)?.displayName ?? "Someone") +1")
                    .font(PartyTheme.display(30))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("The word was “\(store.word)”")
                    .font(PartyTheme.regular(16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

        case .timeUp:
            VStack(spacing: 8) {
                Text("⏰").font(.system(size: 60))
                Text("Time's Up!")
                    .font(PartyTheme.display(30))
                    .foregroundStyle(.white)
                Text("The word was “\(store.word)” — nobody scored.")
                    .font(PartyTheme.regular(16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

        case .skipped:
            VStack(spacing: 8) {
                Text("⏭️").font(.system(size: 60))
                Text("Skipped")
                    .font(PartyTheme.display(30))
                    .foregroundStyle(.white)
                Text("“\(store.word)” stays a secret. Nobody scored.")
                    .font(PartyTheme.regular(16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Guesser picker

    private var guesserGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(store.players) { player in
                GuesserTile(player: player) {
                    Haptics.notify(.success)
                    withAnimation(.snappy) { store.assignGuess(to: player.id) }
                }
            }
        }
    }
}
