//
//  GameOverView.swift
//  find_words
//

import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆")
                .font(.system(size: 72))

            headline

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(store.ranking.enumerated()), id: \.element.id) { index, player in
                        LeaderboardRow(
                            rank: index + 1,
                            player: player,
                            highlight: player.score == store.topScore
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Button("Play Again") {
                    store.playAgain()
                }
                .buttonStyle(PartyButtonStyle(kind: .primary))

                Button("Back to Home") {
                    store.backToHome()
                }
                .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
            }
        }
        .padding(PartyTheme.screenPadding)
        .onAppear {
            Haptics.notify(.success)
        }
    }

    private var headline: some View {
        VStack(spacing: 6) {
            if store.isTie {
                Text("It's a tie!")
                    .font(PartyTheme.display(32))
                    .foregroundStyle(.white)
                Text(store.winners.map(\.displayName).joined(separator: " & "))
                    .font(PartyTheme.strong(20))
                    .foregroundStyle(PartyTheme.lemon)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            } else {
                Text("\(store.ranking.first?.displayName ?? "Player") wins!")
                    .font(PartyTheme.display(32))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }

            Text(store.topScore == 1 ? "1 point" : "\(store.topScore) points")
                .font(PartyTheme.regular(16))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}
