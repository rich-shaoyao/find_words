//
//  HandoffView.swift
//  find_words
//

import SwiftUI

struct HandoffView: View {
    @EnvironmentObject private var store: GameStore

    private var describerName: String {
        store.describer?.displayName ?? "Player"
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text("🤫")
                .font(.system(size: 88))

            VStack(spacing: 10) {
                Text("Pass the phone to")
                    .font(PartyTheme.regular(18))
                    .foregroundStyle(.white.opacity(0.9))

                RoleCaption(
                    role: "Describer",
                    name: describerName,
                    tint: store.describer?.tint ?? PartyTheme.sky,
                    size: 38
                )
            }

            Text("Everyone else — no peeking!")
                .font(PartyTheme.strong(15))
                .foregroundStyle(PartyTheme.lemon)

            Spacer()

            Button("I'm \(describerName) · Show Me") {
                store.revealWordAndStart()
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
    }
}
