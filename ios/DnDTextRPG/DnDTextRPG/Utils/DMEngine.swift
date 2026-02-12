//
//  DMEngine.swift
//  DnDTextRPG
//
//  AI-powered Dungeon Master using Claude API
//

import Foundation

// MARK: - DM Ad-lib Level

enum DMAdLibLevel: Int, CaseIterable {
    case off = 0
    case flavorOnly = 1
    case moderate = 2
    case full = 3

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .flavorOnly: return "Flavor Only"
        case .moderate: return "Moderate"
        case .full: return "Full"
        }
    }

    var description: String {
        switch self {
        case .off: return "DM is silent"
        case .flavorOnly: return "Atmosphere and descriptions only"
        case .moderate: return "Hints, story beats, hidden details"
        case .full: return "Can grant items, modify story, create quests"
        }
    }
}

// MARK: - DM Command Result

struct DMCommandResult {
    let cleanText: String
    let grantedItems: [String]
    let bonusGold: Int
    let healAmount: Int
}

class DMEngine {
    static let shared = DMEngine()

    // Conversation history for context (last few exchanges)
    private var conversationHistory: [(role: String, content: String)] = []
    private let maxHistory = 8  // Keep last 8 messages (4 exchanges)

    // MARK: - API Key

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "anthropic_api_key") }
        set { UserDefaults.standard.set(newValue, forKey: "anthropic_api_key") }
    }

    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Ad-lib Level

    var adLibLevel: DMAdLibLevel {
        get {
            let raw = UserDefaults.standard.integer(forKey: "dm_adlib_level")
            return DMAdLibLevel(rawValue: raw) ?? .flavorOnly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "dm_adlib_level")
        }
    }

    // MARK: - Conversation

    func clearHistory() {
        conversationHistory = []
    }

    func ask(_ userMessage: String, context: DMContext, completion: @escaping (String) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            completion("The DM is unavailable. Set your Anthropic API key in the main menu settings.")
            return
        }

        let systemPrompt = buildSystemPrompt(context: context)

        conversationHistory.append((role: "user", content: userMessage))

        // Trim history
        if conversationHistory.count > maxHistory {
            conversationHistory = Array(conversationHistory.suffix(maxHistory))
        }

        callClaudeAPI(apiKey: key, system: systemPrompt, messages: conversationHistory) { [weak self] response in
            if let response = response {
                self?.conversationHistory.append((role: "assistant", content: response))
                completion(response)
            } else {
                completion("*The DM strokes their beard thoughtfully but says nothing.* (API error — check your key and connection.)")
            }
        }
    }

    /// Request a brief DM narration for a game event. Only fires if adLibLevel >= .moderate
    func narrate(event: String, context: DMContext, completion: @escaping (String?) -> Void) {
        guard adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue else {
            completion(nil)
            return
        }
        guard isConfigured else {
            completion(nil)
            return
        }

        let prompt = "The following just happened: \(event). Give a brief atmospheric narration (1-2 sentences)."
        ask(prompt, context: context) { response in
            completion(response)
        }
    }

    // MARK: - Command Parsing

    static func parseCommands(from response: String) -> DMCommandResult {
        var cleanLines: [String] = []
        var items: [String] = []
        var gold = 0
        var heal = 0

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let range = trimmed.range(of: #"\[GRANT_ITEM:(.+?)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[GRANT_ITEM:".count).dropLast(1))
                items.append(inner)
            } else if let range = trimmed.range(of: #"\[BONUS_GOLD:(\d+)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[BONUS_GOLD:".count).dropLast(1))
                gold += Int(inner) ?? 0
            } else if let range = trimmed.range(of: #"\[HEAL:(\d+)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[HEAL:".count).dropLast(1))
                heal += Int(inner) ?? 0
            } else {
                cleanLines.append(line)
            }
        }

        return DMCommandResult(
            cleanText: cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            grantedItems: items,
            bonusGold: gold,
            healAmount: heal
        )
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: DMContext) -> String {
        var prompt = """
        You are a Dungeon Master for a D&D 5e text adventure. Be creative, atmospheric, \
        and immersive. Keep responses brief (2-4 sentences). Speak in second person ("You see...", \
        "You hear...").

        CURRENT LOCATION: \(context.roomName) (\(context.roomType))
        \(context.roomDescription)
        Exits: \(context.exits)
        Room cleared: \(context.isCleared ? "Yes" : "No — danger lurks here")

        PARTY:
        \(context.partyStatus)

        INVENTORY:
        \(context.inventorySummary)

        TIME: \(context.gameTime)
        """

        switch context.adLibLevel {
        case .off:
            break

        case .flavorOnly:
            prompt += """

            RULES:
            - Describe the world vividly but briefly
            - You CANNOT change game state (HP, gold, inventory, position)
            - If the player wants to attack, move, search, rest, or collect treasure, \
            tell them to use the game menu for that
            - You CAN describe lore, smells, sounds, hidden details, NPC dialogue, \
            inscriptions, feelings, and atmosphere
            - Stay in character as a classic D&D Dungeon Master
            - Be mysterious and hint at secrets to encourage exploration
            """

        case .moderate:
            prompt += """

            RULES:
            - Describe the world vividly but briefly
            - You CANNOT directly change HP, gold, or position
            - You CAN hint at hidden items, secret passages, or approaching danger
            - You CAN add minor story beats: NPC encounters, inscriptions with clues, \
            atmospheric events
            - You CAN suggest the player try certain game actions ("Perhaps you should search here...")
            - Stay in character as a classic D&D Dungeon Master
            - Be mysterious and hint at secrets to encourage exploration
            """

        case .full:
            prompt += """

            RULES:
            - Describe the world vividly but briefly
            - You CAN affect gameplay using special command tags
            - Available commands (place on their own line):
              [GRANT_ITEM:Potion of Healing] — give the player an item
              [BONUS_GOLD:50] — award bonus gold
              [HEAL:10] — heal the party for some HP
            - Use these SPARINGLY and only when dramatically appropriate
            - You CAN create mini side-quests, NPC interactions, dramatic reveals
            - Stay in character as a classic D&D Dungeon Master
            - Be creative! Make the adventure memorable.
            """
        }

        return prompt
    }

    // MARK: - Claude API

    private func callClaudeAPI(apiKey: String, system: String,
                                messages: [(role: String, content: String)],
                                completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let messagesPayload = messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 300,
            "system": system,
            "messages": messagesPayload
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstBlock = content.first,
               let text = firstBlock["text"] as? String {
                completion(text)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - DM Context

struct DMContext {
    let roomName: String
    let roomType: String
    let roomDescription: String
    let exits: String
    let isCleared: Bool
    let partyStatus: String
    let gameTime: String
    let inventorySummary: String
    let adLibLevel: DMAdLibLevel
}
