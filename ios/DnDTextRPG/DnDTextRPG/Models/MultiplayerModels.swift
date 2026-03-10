//
//  MultiplayerModels.swift
//  DnDTextRPG
//
//  Models for Game Center Turn-Based Multiplayer
//

import Foundation

// MARK: - Match Phase

enum MultiplayerPhase: String, Codable {
    case characterCreation
    case exploring
    case combat
    case victory
    case gameOver
    case abandoned
}

// MARK: - Player Slot

struct PlayerSlot: Codable {
    var gamePlayerID: String
    var displayName: String
    var characterId: UUID?
    var controlledCharacterIds: [UUID]  // Host can control multiple characters (human + AI)
    var isPartyLeader: Bool
    let slotIndex: Int
    var needsConfirmation: Bool  // true = placeholder character awaiting remote player confirmation

    init(gamePlayerID: String, displayName: String, characterId: UUID? = nil,
         controlledCharacterIds: [UUID] = [], isPartyLeader: Bool, slotIndex: Int,
         needsConfirmation: Bool = false) {
        self.gamePlayerID = gamePlayerID
        self.displayName = displayName
        self.characterId = characterId
        self.controlledCharacterIds = controlledCharacterIds
        self.isPartyLeader = isPartyLeader
        self.slotIndex = slotIndex
        self.needsConfirmation = needsConfirmation
    }

    // Backward-compatible decoding for existing match data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamePlayerID = try container.decode(String.self, forKey: .gamePlayerID)
        displayName = try container.decode(String.self, forKey: .displayName)
        characterId = try container.decodeIfPresent(UUID.self, forKey: .characterId)
        controlledCharacterIds = try container.decode([UUID].self, forKey: .controlledCharacterIds)
        isPartyLeader = try container.decode(Bool.self, forKey: .isPartyLeader)
        slotIndex = try container.decode(Int.self, forKey: .slotIndex)
        needsConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsConfirmation) ?? false
    }
}

// MARK: - Recent Action

struct MultiplayerAction: Codable {
    let timestamp: Date
    let playerName: String
    let description: String
}

// MARK: - Party Chat Message

struct PartyChatMessage: Codable {
    let timestamp: Date
    let senderName: String
    let message: String
    let isAI: Bool  // true if from DM or NPC AI
    var spoken: Bool = false  // true once TTS has read this message

    enum CodingKeys: String, CodingKey {
        case timestamp, senderName, message, isAI
    }
}

// MARK: - Multiplayer Match State

struct MultiplayerMatchState: Codable {
    static let schemaVersion = 1
    static let maxRecentActions = 20
    static let maxAdventureLogEntries = 50
    static let maxChatMessages = 30

    let version: Int
    let matchId: String

    // Player mapping
    var players: [PlayerSlot]
    var activePlayerID: String

    // Match phase
    var phase: MultiplayerPhase

    // Game state (reuses existing Codable models)
    var party: [Character]
    var dungeon: Dungeon
    var gameTimeMinutes: Int
    var adventureLog: [String]
    var monstersSlain: Int
    var combatsWon: Int
    var torchLit: Bool
    var torchTurnsRemaining: Int

    // Combat state (nil when not in combat)
    var combat: Combat?

    // Recent actions for catch-up display
    var recentActions: [MultiplayerAction]

    // Party chat log
    var partyChatLog: [PartyChatMessage]

    // Dungeon info
    var dungeonLevel: Int

    init(version: Int, matchId: String, players: [PlayerSlot], activePlayerID: String,
         phase: MultiplayerPhase, party: [Character], dungeon: Dungeon, gameTimeMinutes: Int,
         adventureLog: [String], monstersSlain: Int, combatsWon: Int, torchLit: Bool,
         torchTurnsRemaining: Int, combat: Combat?, recentActions: [MultiplayerAction],
         partyChatLog: [PartyChatMessage] = [], dungeonLevel: Int) {
        self.version = version
        self.matchId = matchId
        self.players = players
        self.activePlayerID = activePlayerID
        self.phase = phase
        self.party = party
        self.dungeon = dungeon
        self.gameTimeMinutes = gameTimeMinutes
        self.adventureLog = adventureLog
        self.monstersSlain = monstersSlain
        self.combatsWon = combatsWon
        self.torchLit = torchLit
        self.torchTurnsRemaining = torchTurnsRemaining
        self.combat = combat
        self.recentActions = recentActions
        self.partyChatLog = partyChatLog
        self.dungeonLevel = dungeonLevel
    }

    // Backward-compatible decoding for existing match data without partyChatLog
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        matchId = try container.decode(String.self, forKey: .matchId)
        players = try container.decode([PlayerSlot].self, forKey: .players)
        activePlayerID = try container.decode(String.self, forKey: .activePlayerID)
        phase = try container.decode(MultiplayerPhase.self, forKey: .phase)
        party = try container.decode([Character].self, forKey: .party)
        dungeon = try container.decode(Dungeon.self, forKey: .dungeon)
        gameTimeMinutes = try container.decode(Int.self, forKey: .gameTimeMinutes)
        adventureLog = try container.decode([String].self, forKey: .adventureLog)
        monstersSlain = try container.decode(Int.self, forKey: .monstersSlain)
        combatsWon = try container.decode(Int.self, forKey: .combatsWon)
        torchLit = try container.decode(Bool.self, forKey: .torchLit)
        torchTurnsRemaining = try container.decode(Int.self, forKey: .torchTurnsRemaining)
        combat = try container.decodeIfPresent(Combat.self, forKey: .combat)
        recentActions = try container.decode([MultiplayerAction].self, forKey: .recentActions)
        partyChatLog = try container.decodeIfPresent([PartyChatMessage].self, forKey: .partyChatLog) ?? []
        dungeonLevel = try container.decode(Int.self, forKey: .dungeonLevel)
    }

    // MARK: - Serialization

    /// Encode to compressed data for GKTurnBasedMatch (must fit in 64KB)
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(self)
        return try (json as NSData).compressed(using: .zlib) as Data
    }

    /// Decode from compressed match data
    static func decoded(from data: Data) throws -> MultiplayerMatchState {
        let json = try (data as NSData).decompressed(using: .zlib) as Data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MultiplayerMatchState.self, from: json)
    }

    // MARK: - Helpers

    /// Trim logs to keep size under 64KB
    mutating func trimForTransfer() {
        if adventureLog.count > Self.maxAdventureLogEntries {
            adventureLog = Array(adventureLog.suffix(Self.maxAdventureLogEntries))
        }
        if recentActions.count > Self.maxRecentActions {
            recentActions = Array(recentActions.suffix(Self.maxRecentActions))
        }
        if partyChatLog.count > Self.maxChatMessages {
            partyChatLog = Array(partyChatLog.suffix(Self.maxChatMessages))
        }
    }

    /// Add a recent action and trim
    mutating func addAction(playerName: String, description: String) {
        recentActions.append(MultiplayerAction(
            timestamp: Date(),
            playerName: playerName,
            description: description
        ))
        if recentActions.count > Self.maxRecentActions {
            recentActions.removeFirst()
        }
    }

    /// Add a chat message and trim
    mutating func addChatMessage(senderName: String, message: String, isAI: Bool = false) {
        partyChatLog.append(PartyChatMessage(
            timestamp: Date(),
            senderName: senderName,
            message: message,
            isAI: isAI
        ))
        if partyChatLog.count > Self.maxChatMessages {
            partyChatLog.removeFirst()
        }
    }

    /// Re-link combat party references after decoding
    mutating func relinkCombat() {
        combat?.relinkParty(party)
    }
}
