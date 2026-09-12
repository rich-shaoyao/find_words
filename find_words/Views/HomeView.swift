//
//  HomeView.swift
//  find_words
//
//  Title plus the whole settings panel — there are only two settings, so a
//  separate screen would just cost a tap.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)

            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 64))

                Text("FIND WORDS")
                    .font(PartyTheme.display(44))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

                Text("Describe it. Let them guess.")
                    .font(PartyTheme.regular(17))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 10)

            if showSettings {
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            VStack(spacing: 12) {
                Button("Start Game") {
                    store.startGame()
                }
                .buttonStyle(PartyButtonStyle(kind: .primary))

                HStack(spacing: 10) {
                    Button(showSettings ? "Hide Settings" : "Settings") {
                        withAnimation(.snappy) { showSettings.toggle() }
                    }
                    .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))

                    Button("How to Play") {
                        store.phase = .howToPlay
                    }
                    .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
                }

                Text(store.configSummary)
                    .font(PartyTheme.regular(13))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(PartyTheme.screenPadding)
        .onAppear { showSettings = store.homeShowsSettings }
    }

    // MARK: - Settings

    private var settingsPanel: some View {
        VStack(spacing: 14) {
            settingsGroup(title: "Round time") {
                HStack(spacing: 7) {
                    ForEach(GameRules.timePresets, id: \.self) { seconds in
                        ChoiceChip(
                            label: "\(seconds)s",
                            isSelected: !store.durationIsCustom && store.roundDuration == seconds
                        ) {
                            store.selectPresetDuration(seconds)
                        }
                    }
                    ChoiceChip(label: "Custom", isSelected: store.durationIsCustom) {
                        store.selectCustomDuration()
                    }
                }
            }

            if store.durationIsCustom {
                sliderRow(
                    value: Binding(
                        get: { Double(store.roundDuration) },
                        set: { store.setCustomDuration(Int($0.rounded())) }
                    ),
                    range: Double(GameRules.customTimeRange.lowerBound)...Double(GameRules.customTimeRange.upperBound),
                    step: Double(GameRules.customTimeStep),
                    display: "\(store.roundDuration)s"
                )
            }

            settingsGroup(title: "Words this game") {
                HStack(spacing: 7) {
                    ForEach(GameRules.wordPresets, id: \.self) { count in
                        ChoiceChip(
                            label: "\(count)",
                            isSelected: !store.wordsIsCustom && store.totalWords == count
                        ) {
                            store.selectPresetWords(count)
                        }
                    }
                    ChoiceChip(label: "Custom", isSelected: store.wordsIsCustom) {
                        store.selectCustomWords()
                    }
                }
            }

            if store.wordsIsCustom {
                sliderRow(
                    value: Binding(
                        get: { Double(store.totalWords) },
                        set: { store.setCustomWords(Int($0.rounded())) }
                    ),
                    range: Double(GameRules.customWordRange.lowerBound)...Double(GameRules.customWordRange.upperBound),
                    step: 1,
                    display: "\(store.totalWords)"
                )
            }
        }
        .padding(16)
        .background(
            Color.white.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PartyTheme.strong(12))
                .foregroundStyle(.white.opacity(0.8))
                .textCase(.uppercase)
                .kerning(1.1)
            content()
        }
    }

    private func sliderRow(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text("Set precisely")
                    .font(PartyTheme.strong(13))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(display)
                    .font(PartyTheme.strong(15))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("\(Int(range.lowerBound))")
                    .font(PartyTheme.regular(11))
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: value, in: range, step: step)
                    .tint(.white)
                Text("\(Int(range.upperBound))")
                    .font(PartyTheme.regular(11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
