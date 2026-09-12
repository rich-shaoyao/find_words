//
//  WordEntryView.swift
//  find_words
//
//  The host types the word here. Tapping Start Timer is what starts the clock —
//  not typing — so the countdown never begins while they are still on the keyboard.
//

import SwiftUI

struct WordEntryView: View {
    @EnvironmentObject private var store: GameStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            header
            privacyCard
            wordField
            surpriseButton
            Spacer(minLength: 0)
            startButton
        }
        .padding(PartyTheme.screenPadding)
        // TEMP DIAGNOSIS: autofocus disabled
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            RoundPill(text: "Word \(store.roundNumber) of \(store.totalWords)")
            Spacer(minLength: 0)
            ScorePill(count: store.correctCount)
        }
    }

    private var privacyCard: some View {
        HStack(spacing: 10) {
            Text("👀")
                .font(.system(size: 26))
            Text("Don't let anyone else see this screen")
                .font(PartyTheme.strong(15))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.white.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
    }

    private var wordField: some View {
        VStack(spacing: 9) {
            TextField("Your word", text: Binding(
                get: { store.draftWord },
                set: {
                    store.draftWord = $0
                    store.entryMessage = nil
                }
            ))
            .font(PartyTheme.display(34))
            .foregroundStyle(PartyTheme.ink)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFieldFocused)
            .onSubmit { store.startTimer() }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: PartyTheme.cardRadius, style: .continuous)
            )

            if let message = store.entryMessage {
                Text(message)
                    .font(PartyTheme.strong(14))
                    .foregroundStyle(PartyTheme.lemon)
            } else {
                Text("e.g. Volcano · Mermaid · Jetpack")
                    .font(PartyTheme.regular(13))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    private var surpriseButton: some View {
        Button {
            store.fillRandomWord()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                Text("Surprise me")
            }
        }
        .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
    }

    private var startButton: some View {
        Button {
            isFieldFocused = false
            store.startTimer()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Start Timer")
            }
        }
        .buttonStyle(PartyButtonStyle(kind: .primary))
        .disabled(!store.canStartRound)
        .opacity(store.canStartRound ? 1 : 0.45)
        .animation(.snappy(duration: 0.2), value: store.canStartRound)
    }
}
