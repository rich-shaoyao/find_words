//
//  GameModels.swift
//  find_words
//
//  Value types describing a pass-and-play round of Find Words.
//

import SwiftUI

// MARK: - Player

struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var score: Int
    /// Stable index into `PartyTheme.playerColors` so a player keeps their colour.
    let tintIndex: Int

    init(id: UUID = UUID(), name: String, score: Int = 0, tintIndex: Int) {
        self.id = id
        self.name = name
        self.score = score
        self.tintIndex = tintIndex
    }

    var tint: Color { PartyTheme.playerColor(for: tintIndex) }

    var initials: String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }
}

// MARK: - Flow

enum GamePhase: Equatable {
    case home
    case setup
    case howToPlay
    /// The Word Setter types a secret word.
    case wordEntry
    /// The phone travels from the Setter to the Describer.
    case handoff
    /// The Describer sees the word and the clock is running.
    case playing
    /// The round is over; results and the running leaderboard.
    case roundResult
    case gameOver
}

enum RoundOutcome: Equatable {
    /// "Got it!" was tapped — we still need to know who guessed it.
    case awaitingGuess
    case guessed(UUID)
    case timeUp
    case skipped
}

// MARK: - Rules

enum GameRules {
    static let minimumPlayers = 3
    static let maximumPlayers = 8
    static let defaultRoundDuration = 60
    static let roundDurations = [30, 45, 60, 90]
}

// MARK: - Word bank

/// A small English fallback bank powering the "Surprise me" button, so a setter
/// never gets stuck. Players are still free to type their own words.
enum WordBank {
    static let words: [String] = [
        "Pizza", "Dragon", "Rainbow", "Guitar", "Volcano", "Penguin", "Castle",
        "Balloon", "Robot", "Sandwich", "Pirate", "Mermaid", "Rocket", "Penguin",
        "Bicycle", "Chocolate", "Elephant", "Fireworks", "Giraffe", "Hamburger",
        "Ice Cream", "Jellyfish", "Kangaroo", "Lighthouse", "Mountain", "Ninja",
        "Octopus", "Popcorn", "Quarterback", "Raincoat", "Snowman", "Telescope",
        "Umbrella", "Vampire", "Waterfall", "Xylophone", "Yo-yo", "Zebra",
        "Airport", "Backpack", "Campfire", "Dinosaur", "Elevator", "Festival",
        "Ghost", "Honeycomb", "Igloo", "Jetpack", "Karate", "Ladybug",
        "Mirror", "Noodle", "Oasis", "Parachute", "Quicksand", "Rooster",
        "Saxophone", "Tornado", "Unicorn", "Violin", "Wizard", "Yogurt",
        "Zipper", "Anchor", "Bubblegum", "Cactus", "Dolphin", "Eclipse",
        "Feather", "Glacier", "Hedgehog", "Island", "Jackpot", "Kite",
        "Lantern", "Magnet", "Nebula", "Orchestra", "Puzzle", "Quill"
    ]

    static func random(excluding current: String) -> String {
        let pool = words.filter { $0 != current }
        return pool.randomElement() ?? words.randomElement() ?? "Mystery"
    }
}
