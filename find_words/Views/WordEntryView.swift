//
//  WordEntryView.swift
//  find_words
//

import SwiftUI

struct WordEntryView: View {
    @EnvironmentObject private var store: GameStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            RoundPill(text: "Round \(store.roundNumber) of \(store.totalRounds)")

            RoleCaption(
                role: "Word Setter",
                name: store.setter?.displayName ?? "Player",
                tint: store.setter?.tint ?? PartyTheme.sky
            )

            Text("Type a secret word. Keep the screen to yourself — then pass the phone to \(store.describer?.displayName ?? "the describer").")
                .font(PartyTheme.regular(16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            wordField

            if let message = store.entryMessage {
                Text(message)
                    .font(PartyTheme.strong(14))
                    .foregroundStyle(PartyTheme.lemon)
            }

            Button {
                store.fillRandomWord()
            } label: {
                Label("Surprise me", systemImage: "dice.fill")
            }
            .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))

            Spacer(minLength: 0)

            Button("Lock It In") {
                isFieldFocused = false
                store.lockInWord()
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
        .onAppear { isFieldFocused = true }
    }

    private var wordField: some View {
        VStack(spacing: 10) {
            TextField("Your word", text: Binding(
                get: { store.draftWord },
                set: {
                    store.draftWord = $0
                    store.entryMessage = nil
                }
            ))
            .font(PartyTheme.display(36))
            .foregroundStyle(PartyTheme.ink)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isFieldFocused)
            .onSubmit { store.lockInWord() }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: PartyTheme.cardRadius, style: .continuous))

            Text("e.g. Pizza · Volcano · Mermaid")
                .font(PartyTheme.regular(13))
                .foregroundStyle(.white.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}
