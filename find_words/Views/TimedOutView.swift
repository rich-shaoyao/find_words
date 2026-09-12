//
//  TimedOutView.swift
//  find_words
//
//  The clock hit zero. Counts as an unfinished word, then moves on by itself.
//

import SwiftUI

struct TimedOutView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("⏰")
                .font(.system(size: 82))

            Text("Time's Up!")
                .font(PartyTheme.display(42))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                Text("The word was “\(store.word)”")
                    .font(PartyTheme.regular(18))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                Text(store.isLastWord ? "That was the last word." : "Nobody scored this one.")
                    .font(PartyTheme.strong(15))
                    .foregroundStyle(PartyTheme.lemon)
            }

            Spacer()

            Button(store.isLastWord ? "See Results" : "Next Word") {
                store.continueAfterTimeout()
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
        .contentShape(Rectangle())
        .onTapGesture { store.continueAfterTimeout() }
    }
}
