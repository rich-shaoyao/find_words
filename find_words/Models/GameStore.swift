//
//  GameStore.swift
//  find_words
//
//  The whole game lives here: players, round rotation, the countdown and scoring.
//  Views stay dumb and just render `phase`.
//
//  Built on ObservableObject/@Published rather than the @Observable macro: macro
//  plugins are not loadable on every toolchain, and this keeps the project
//  buildable with a plain `xcodebuild`.
//

import Foundation
import SwiftUI

final class GameStore: ObservableObject {

    // MARK: - Navigation

    @Published var phase: GamePhase = .home

    // MARK: - Setup

    @Published private(set) var players: [Player] = []
    @Published var roundDuration: Int = GameRules.defaultRoundDuration

    // MARK: - Current round

    /// Zero-based index of the round being played.
    @Published private(set) var roundIndex: Int = 0
    @Published private(set) var word: String = ""
    @Published private(set) var timeRemaining: Double = 0
    @Published private(set) var outcome: RoundOutcome?

    // MARK: - Word entry draft

    @Published var draftWord: String = ""
    @Published var entryMessage: String?

    private var timerTask: Task<Void, Never>?
    private var nextTintIndex: Int = 0

    // MARK: - Derived state

    var totalRounds: Int { max(players.count, 1) }

    /// 1-based round number for display, clamped on the game-over screen.
    var roundNumber: Int { min(roundIndex + 1, totalRounds) }

    var describerIndex: Int {
        guard !players.isEmpty else { return 0 }
        return roundIndex % players.count
    }

    /// The player who already described last round hands out the next word.
    var setterIndex: Int {
        guard !players.isEmpty else { return 0 }
        return (roundIndex + players.count - 1) % players.count
    }

    var describer: Player? { player(at: describerIndex) }
    var setter: Player? { player(at: setterIndex) }

    func player(at index: Int) -> Player? {
        players.indices.contains(index) ? players[index] : nil
    }

    func player(id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    var canStartGame: Bool { players.count >= GameRules.minimumPlayers }

    var canAddPlayer: Bool { players.count < GameRules.maximumPlayers }

    var ranking: [Player] {
        players.sorted {
            $0.score == $1.score ? $0.name < $1.name : $0.score > $1.score
        }
    }

    var topScore: Int { players.map(\.score).max() ?? 0 }

    var winners: [Player] { players.filter { $0.score == topScore } }

    var isTie: Bool { winners.count > 1 }

    var isLastRound: Bool { roundIndex >= totalRounds - 1 }

    // MARK: - Player management

    func addPlayer() {
        guard canAddPlayer else { return }
        players.append(
            Player(name: "Player \(players.count + 1)", tintIndex: nextTintIndex)
        )
        nextTintIndex += 1
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
    }

    func rename(id: UUID, to name: String) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].name = name
    }

    // MARK: - Game flow

    func startGame() {
        guard canStartGame else { return }
        for index in players.indices {
            players[index].score = 0
        }
        roundIndex = 0
        prepareRound()
    }

    private func prepareRound() {
        word = ""
        outcome = nil
        draftWord = ""
        entryMessage = nil
        timeRemaining = 0
        phase = .wordEntry
    }

    func lockInWord() {
        let cleaned = draftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else {
            entryMessage = "Pick a word with at least 2 letters."
            return
        }
        word = cleaned
        entryMessage = nil
        draftWord = ""
        phase = .handoff
    }

    func fillRandomWord() {
        draftWord = WordBank.random(excluding: draftWord)
        entryMessage = nil
    }

    /// Called by the Describer once the phone has been handed over.
    func revealWordAndStart() {
        outcome = nil
        timerTask?.cancel()
        timeRemaining = Double(roundDuration)
        phase = .playing
        startCountdown()
    }

    func markGuessed() {
        timerTask?.cancel()
        outcome = .awaitingGuess
        phase = .roundResult
    }

    func assignGuess(to playerID: UUID) {
        guard outcome == .awaitingGuess else { return }
        outcome = .guessed(playerID)
        if let index = players.firstIndex(where: { $0.id == playerID }) {
            players[index].score += 1
        }
    }

    func skipRound() {
        timerTask?.cancel()
        outcome = .skipped
        phase = .roundResult
    }

    func advance() {
        timerTask?.cancel()
        if isLastRound {
            phase = .gameOver
        } else {
            roundIndex += 1
            prepareRound()
        }
    }

    func playAgain() {
        startGame()
    }

    func backToSetup() {
        timerTask?.cancel()
        word = ""
        outcome = nil
        draftWord = ""
        entryMessage = nil
        for index in players.indices {
            players[index].score = 0
        }
        roundIndex = 0
        phase = .setup
    }

    func backToHome() {
        timerTask?.cancel()
        word = ""
        outcome = nil
        draftWord = ""
        entryMessage = nil
        roundIndex = 0
        for index in players.indices {
            players[index].score = 0
        }
        phase = .home
    }

    // MARK: - Countdown

    private func startCountdown() {
        let total = Double(roundDuration)
        let deadline = Date().addingTimeInterval(total)
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else { return }
                let left = deadline.timeIntervalSinceNow
                if left <= 0 {
                    self.timeRemaining = 0
                    self.endWithTimeout()
                    return
                }
                self.timeRemaining = left
            }
        }
    }

    private func endWithTimeout() {
        guard phase == .playing else { return }
        outcome = .timeUp
        phase = .roundResult
    }
}
