//
//  GameStore.swift
//  find_words
//
//  Whole game state for the single-host mode: settings, the round loop, the
//  countdown, and the one number that matters — how many words were guessed.
//
//  Built on ObservableObject/@Published rather than the @Observable macro, so the
//  project builds with a plain `xcodebuild` on toolchains that cannot load the
//  macro plugin.
//
//  The whole class is @MainActor. Every @Published write here drives a SwiftUI
//  rebuild, and the writes come from background-hopping tasks (the countdown
//  loop, the Correct/Skip flash delay). Without the annotation those tasks ran
//  off the main thread — `Task {}` in a nonisolated method does not hop back —
//  so the UI was rebuilt from a background thread, which made the screen stop
//  responding right after a Correct tap. The annotation makes the tasks inherit
//  the main actor, so publishes land on the main thread where SwiftUI needs
//  them.
//

import Foundation
import SwiftUI

@MainActor
final class GameStore: ObservableObject {

    // MARK: - Navigation

    @Published var phase: GamePhase = .wordEntry

    /// Set by "Settings" on the summary screen so the panel reopens on Home.
    @Published var homeShowsSettings = false

    // MARK: - Configuration

    @Published private(set) var roundDuration: Int = GameRules.defaultTime
    @Published private(set) var durationIsCustom = false
    @Published private(set) var totalWords: Int = GameRules.defaultWords
    @Published private(set) var wordsIsCustom = false

    /// Remembered custom values, so switching back to Custom restores them.
    @Published private(set) var customDuration = GameRules.initialCustomTime
    @Published private(set) var customWords = GameRules.initialCustomWords

    // MARK: - Live round

    /// Words used up so far — correct, skipped and timed out all count.
    @Published private(set) var wordsPlayed: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var word: String = ""
    @Published private(set) var timeRemaining: Double = 0
    @Published private(set) var flash: RoundFlash?
    @Published private(set) var endedEarly = false

    // MARK: - Word entry draft

    @Published var draftWord: String = ""
    @Published var entryMessage: String?

    private var timerTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isResolving = false

    // MARK: - Lifecycle

    init() {
        loadConfig()
    }

    // MARK: - Derived state

    /// 1-based index of the word being played right now.
    var roundNumber: Int { min(wordsPlayed + 1, totalWords) }

    var isLastWord: Bool { wordsPlayed + 1 >= totalWords }

    var canStartRound: Bool {
        draftWord.trimmingCharacters(in: .whitespacesAndNewlines).count >= GameRules.minimumWordLength
    }

    /// Share of played words that were guessed, 0...1.
    var accuracy: Double {
        wordsPlayed == 0 ? 0 : Double(correctCount) / Double(wordsPlayed)
    }

    var configSummary: String {
        let noun = totalWords == 1 ? "word" : "words"
        return "\(totalWords) \(noun) · \(roundDuration)s each"
    }

    // MARK: - Configuration

    func selectPresetDuration(_ seconds: Int) {
        roundDuration = seconds
        durationIsCustom = false
        persistConfig()
    }

    func selectCustomDuration() {
        roundDuration = customDuration
        durationIsCustom = true
        persistConfig()
    }

    func setCustomDuration(_ seconds: Int) {
        customDuration = clamped(seconds, to: GameRules.customTimeRange)
        roundDuration = customDuration
        durationIsCustom = true
        persistConfig()
    }

    func selectPresetWords(_ count: Int) {
        totalWords = count
        wordsIsCustom = false
        persistConfig()
    }

    func selectCustomWords() {
        totalWords = customWords
        wordsIsCustom = true
        persistConfig()
    }

    func setCustomWords(_ count: Int) {
        customWords = clamped(count, to: GameRules.customWordRange)
        totalWords = customWords
        wordsIsCustom = true
        persistConfig()
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: - Game flow

    func startGame() {
        wordsPlayed = 0
        correctCount = 0
        endedEarly = false
        prepareRound()
    }

    private func prepareRound() {
        timerTask?.cancel()
        timeoutTask?.cancel()
        isResolving = false
        word = ""
        draftWord = ""
        entryMessage = nil
        timeRemaining = 0
        flash = nil
        phase = .wordEntry
    }

    /// The host is done typing: kick off the clock immediately. If the field
    /// is still empty (or too short), fall back to a random word so the tap
    /// always starts the game — matching the "launch and play" home screen.
    func startTimer() {
        guard phase == .wordEntry else { return }
        let cleaned = draftWord.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalWord: String
        if cleaned.count >= GameRules.minimumWordLength {
            finalWord = cleaned
        } else {
            finalWord = WordBank.random(excluding: cleaned)
        }

        word = finalWord
        draftWord = ""
        entryMessage = nil
        timeRemaining = Double(roundDuration)
        phase = .playing
        Haptics.impact(.light)
        startCountdown()
    }

    func fillRandomWord() {
        draftWord = WordBank.random(excluding: draftWord)
        entryMessage = nil
    }

    func markCorrect() { resolveRound(correct: true) }

    func markSkipped() { resolveRound(correct: false) }

    /// Shows a short flash, then advances. `isResolving` stops double taps.
    private func resolveRound(correct: Bool) {
        guard phase == .playing, !isResolving else { return }
        isResolving = true
        timerTask?.cancel()

        flash = correct ? .correct : .skipped
        if correct {
            Haptics.notify(.success)
        } else {
            Haptics.impact(.rigid)
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.flashDuration * 1_000_000_000))
            guard let self else { return }
            self.flash = nil
            self.finishRound(correct: correct)
            self.isResolving = false
        }
    }

    private func finishRound(correct: Bool) {
        isResolving = false
        wordsPlayed += 1
        if correct { correctCount += 1 }

        if wordsPlayed >= totalWords {
            phase = .summary
        } else {
            prepareRound()
        }
    }

    /// The host bailed out mid-game via the ✕ button.
    func finishEarly() {
        timerTask?.cancel()
        timeoutTask?.cancel()
        isResolving = false
        flash = nil
        endedEarly = true
        phase = .summary
    }

    func continueAfterTimeout() {
        guard phase == .timedOut else { return }
        timeoutTask?.cancel()
        finishRound(correct: false)
    }

    func playAgain() {
        startGame()
    }

    func backToHome(showingSettings: Bool = false) {
        timerTask?.cancel()
        timeoutTask?.cancel()
        homeShowsSettings = showingSettings
        isResolving = false
        word = ""
        draftWord = ""
        entryMessage = nil
        flash = nil
        timeRemaining = 0
        wordsPlayed = 0
        correctCount = 0
        endedEarly = false
        phase = .wordEntry
    }

    // MARK: - Countdown

    private func startCountdown() {
        timerTask?.cancel()
        let deadline = Date().addingTimeInterval(Double(roundDuration))

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else { return }
                let left = deadline.timeIntervalSinceNow
                if left <= 0 {
                    self.timeRemaining = 0
                    self.timeDidExpire()
                    return
                }
                self.timeRemaining = left
            }
        }
    }

    private func timeDidExpire() {
        guard phase == .playing, !isResolving else { return }
        timerTask?.cancel()
        phase = .timedOut
        Haptics.notify(.warning)

        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.timeoutLinger * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.continueAfterTimeout()
        }
    }

    // MARK: - Persistence

    private enum Keys {
        static let duration = "fw.roundDuration"
        static let durationIsCustom = "fw.durationIsCustom"
        static let words = "fw.totalWords"
        static let wordsIsCustom = "fw.wordsIsCustom"
        static let customDuration = "fw.customDuration"
        static let customWords = "fw.customWords"
    }

    private func loadConfig() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.duration) != nil else { return }

        roundDuration = clamped(defaults.integer(forKey: Keys.duration), to: GameRules.customTimeRange)
        durationIsCustom = defaults.bool(forKey: Keys.durationIsCustom)
        totalWords = clamped(defaults.integer(forKey: Keys.words), to: GameRules.customWordRange)
        wordsIsCustom = defaults.bool(forKey: Keys.wordsIsCustom)

        let savedCustomDuration = defaults.integer(forKey: Keys.customDuration)
        if GameRules.customTimeRange.contains(savedCustomDuration) {
            customDuration = savedCustomDuration
        }

        let savedCustomWords = defaults.integer(forKey: Keys.customWords)
        if GameRules.customWordRange.contains(savedCustomWords) {
            customWords = savedCustomWords
        }
    }

    private func persistConfig() {
        let defaults = UserDefaults.standard
        defaults.set(roundDuration, forKey: Keys.duration)
        defaults.set(durationIsCustom, forKey: Keys.durationIsCustom)
        defaults.set(totalWords, forKey: Keys.words)
        defaults.set(wordsIsCustom, forKey: Keys.wordsIsCustom)
        defaults.set(customDuration, forKey: Keys.customDuration)
        defaults.set(customWords, forKey: Keys.customWords)
    }
}
