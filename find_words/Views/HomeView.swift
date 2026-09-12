//
//  HomeView.swift
//  find_words
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text("🎉")
                    .font(.system(size: 76))

                Text("FIND WORDS")
                    .font(PartyTheme.display(46))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

                Text("One word. One describer.\nEveryone else guesses.")
                    .font(PartyTheme.regular(18))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: 14) {
                Button("Start a Game") {
                    store.phase = .setup
                }
                .buttonStyle(PartyButtonStyle(kind: .primary))

                Button("How to Play") {
                    store.phase = .howToPlay
                }
                .buttonStyle(PartyButtonStyle(kind: .soft))

                Text("Pass & Play · \(GameRules.minimumPlayers)–\(GameRules.maximumPlayers) players")
                    .font(PartyTheme.regular(13))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 2)
            }
        }
        .padding(PartyTheme.screenPadding)
    }
}
