//
//  SettingsView.swift
//  find_words
//
//  Only two settings, so they live on one screen and both are always visible.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                RoundIconButton(systemName: "chevron.left") {
                    store.phase = .wordEntry
                }
                Spacer(minLength: 0)
                RoundPill(text: "Settings")
                Spacer(minLength: 0)
                Color.clear.frame(width: 42, height: 42)
            }

            ScrollView {
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
            .scrollBounceBehavior(.basedOnSize)

            Button("Done") {
                store.phase = .wordEntry
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
    }

    // MARK: - Pieces

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
                Spacer(minLength: 0)
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
