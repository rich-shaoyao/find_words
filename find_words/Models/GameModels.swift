//
//  GameModels.swift
//  find_words
//
//  Types for a single-host guessing game: one person holds the phone, types a
//  word, describes it out loud, and taps Correct or Skip.
//

import Foundation

// MARK: - Flow

enum GamePhase: Equatable {
    case settings
    case howToPlay
    /// Entry screen and de-facto home: type a word, then start the clock.
    case wordEntry
    /// The clock is running.
    case playing
    /// The clock hit zero.
    case timedOut
    /// Final score.
    case summary
}

/// Short-lived feedback drawn on top of the playing screen.
enum RoundFlash: Equatable {
    case correct
    case skipped
}

// MARK: - Rules

enum GameRules {
    // Round length
    static let timePresets = [10, 20, 30, 60]
    static let customTimeRange = 5...300
    static let customTimeStep = 5
    static let defaultTime = 30
    static let initialCustomTime = 45

    // Words per game
    static let wordPresets = [5, 10, 15, 20]
    static let customWordRange = 1...50
    static let defaultWords = 10
    static let initialCustomWords = 10

    /// A word must be at least this long before its round can start.
    static let minimumWordLength = 2

    /// How long the "Time's up!" screen lingers before moving on.
    static let timeoutLinger: Double = 1.8

    /// How long the Correct / Skip flash stays up.
    static let flashDuration: Double = 0.45
}

// MARK: - Word bank

/// A small English fallback bank powering the "Surprise me" button, so the host
/// never gets stuck. Typing your own word is still the main path.
enum WordBank {
    static let words: [String] = [
        "Pizza", "Dragon", "Rainbow", "Guitar", "Volcano", "Penguin", "Castle",
        "Balloon", "Robot", "Sandwich", "Pirate", "Mermaid", "Rocket", "Bicycle",
        "Chocolate", "Elephant", "Fireworks", "Giraffe", "Hamburger", "Ice Cream",
        "Jellyfish", "Kangaroo", "Lighthouse", "Mountain", "Ninja", "Octopus",
        "Popcorn", "Quarterback", "Raincoat", "Snowman", "Telescope", "Umbrella",
        "Vampire", "Waterfall", "Xylophone", "Yo-yo", "Zebra", "Airport",
        "Backpack", "Campfire", "Dinosaur", "Elevator", "Festival", "Ghost",
        "Honeycomb", "Igloo", "Jetpack", "Karate", "Ladybug", "Mirror",
        "Noodle", "Oasis", "Parachute", "Quicksand", "Rooster", "Saxophone",
        "Tornado", "Unicorn", "Violin", "Wizard", "Yogurt", "Zipper",
        "Anchor", "Bubblegum", "Cactus", "Dolphin", "Eclipse", "Feather",
        "Glacier", "Hedgehog", "Island", "Jackpot", "Kite", "Lantern",
        "Magnet", "Nebula", "Orchestra", "Puzzle", "Quill", "Sunflower"
    ]

    static func random(excluding current: String) -> String {
        let pool = words.filter { $0 != current }
        return pool.randomElement() ?? words.randomElement() ?? "Mystery"
    }
}
