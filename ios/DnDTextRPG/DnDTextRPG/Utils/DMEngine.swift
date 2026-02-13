//
//  DMEngine.swift
//  DnDTextRPG
//
//  AI-powered Dungeon Master — supports multiple AI providers
//

import Foundation

// MARK: - AI Provider

enum AIProvider: Int, CaseIterable {
    case anthropic = 0
    case openAI = 1
    case google = 2

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openAI: return "OpenAI (GPT)"
        case .google: return "Google (Gemini)"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openAI: return "sk-..."
        case .google: return "AIza..."
        }
    }

    var keyURL: String {
        switch self {
        case .anthropic: return "console.anthropic.com"
        case .openAI: return "platform.openai.com/api-keys"
        case .google: return "aistudio.google.com/apikey"
        }
    }

    var userDefaultsKey: String {
        switch self {
        case .anthropic: return "anthropic_api_key"
        case .openAI: return "openai_api_key"
        case .google: return "google_api_key"
        }
    }
}

// MARK: - Age Rating

enum AgeRating: Int, CaseIterable {
    case age9 = 0
    case age12 = 1
    case age16 = 2
    case adult = 3

    var displayName: String {
        switch self {
        case .age9: return "Ages 9+"
        case .age12: return "Ages 12+"
        case .age16: return "Ages 16+"
        case .adult: return "Adult"
        }
    }

    var description: String {
        switch self {
        case .age9: return "Family-friendly, no gore or scary content"
        case .age12: return "Mild peril, light fantasy violence"
        case .age16: return "Fantasy violence, moderate peril"
        case .adult: return "Unrestricted D&D themes"
        }
    }

    var systemPromptRules: String {
        switch self {
        case .age9:
            return """
            STRICT CONTENT RULES (Ages 9+):
            - Keep ALL content suitable for young children
            - NO blood, gore, graphic violence, or body horror
            - NO death descriptions — defeated monsters "flee" or "collapse" or "vanish"
            - NO scary, disturbing, or nightmare-inducing imagery
            - NO references to alcohol, drugs, romance, or adult themes
            - Keep tone light, fun, and encouraging — like a friendly storybook adventure
            - Monsters should be mischievous or silly rather than terrifying
            - Use humor and wonder instead of fear and dread
            """
        case .age12:
            return """
            CONTENT RULES (Ages 12+):
            - Keep content suitable for young teens
            - Mild fantasy violence is OK (sword clashes, spell blasts)
            - NO graphic gore, dismemberment, or torture
            - NO heavy horror or disturbing psychological content
            - NO references to drugs, alcohol abuse, or sexual content
            - Light peril and spooky atmospheres are fine
            - Keep defeated enemies falling or retreating, not gruesome deaths
            """
        case .age16:
            return """
            CONTENT RULES (Ages 16+):
            - Standard fantasy violence is OK
            - Moderate peril and darker themes are acceptable
            - NO extremely graphic gore or torture scenes
            - NO sexual content
            - Dark atmosphere, undead horror, and dramatic tension are fine
            """
        case .adult:
            return """
            CONTENT RULES (Adult):
            - Standard D&D fantasy content with no special restrictions
            - Keep tone appropriate for a classic D&D adventure
            """
        }
    }
}

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

    // MARK: - Provider

    var provider: AIProvider {
        get {
            // Default to Google (Gemini) — free tier available
            if UserDefaults.standard.object(forKey: "ai_provider") == nil {
                return .google
            }
            let raw = UserDefaults.standard.integer(forKey: "ai_provider")
            return AIProvider(rawValue: raw) ?? .google
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ai_provider")
        }
    }

    // MARK: - API Key (per-provider)

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: provider.userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: provider.userDefaultsKey) }
    }

    func apiKey(for provider: AIProvider) -> String? {
        UserDefaults.standard.string(forKey: provider.userDefaultsKey)
    }

    func setApiKey(_ key: String?, for provider: AIProvider) {
        UserDefaults.standard.set(key, forKey: provider.userDefaultsKey)
    }

    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Ad-lib Level

    var adLibLevel: DMAdLibLevel {
        get {
            // Default to Off — user must enable in Settings
            if UserDefaults.standard.object(forKey: "dm_adlib_level") == nil {
                return .off
            }
            let raw = UserDefaults.standard.integer(forKey: "dm_adlib_level")
            return DMAdLibLevel(rawValue: raw) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "dm_adlib_level")
        }
    }

    // MARK: - Age Rating (hardcoded to 9+)

    var ageRating: AgeRating { .age9 }

    // MARK: - Conversation

    func clearHistory() {
        conversationHistory = []
    }

    func ask(_ userMessage: String, context: DMContext, completion: @escaping (String) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            completion("The DM is unavailable. Set your \(provider.displayName) API key in Settings.")
            return
        }

        let systemPrompt = buildSystemPrompt(context: context)

        conversationHistory.append((role: "user", content: userMessage))

        // Trim history
        if conversationHistory.count > maxHistory {
            conversationHistory = Array(conversationHistory.suffix(maxHistory))
        }

        callAI(provider: provider, apiKey: key, system: systemPrompt, messages: conversationHistory) { [weak self] response in
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

        \(ageRating.systemPromptRules)

        CURRENT LOCATION: \(context.roomName) (\(context.roomType))
        \(context.roomDescription)
        Exits: \(context.exits)
        Room cleared: \(context.isCleared ? "Yes" : "No — danger lurks here")

        PARTY:
        \(context.partyStatus)

        INVENTORY:
        \(context.inventorySummary)

        TIME: \(context.gameTime)
        \(context.combatSummary.map { "\nCOMBAT IN PROGRESS:\n\($0)" } ?? "")
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

    // MARK: - AI API Router

    private func callAI(provider: AIProvider, apiKey: String, system: String,
                         messages: [(role: String, content: String)],
                         completion: @escaping (String?) -> Void) {
        switch provider {
        case .anthropic:
            callAnthropic(apiKey: apiKey, system: system, messages: messages, completion: completion)
        case .openAI:
            callOpenAI(apiKey: apiKey, system: system, messages: messages, completion: completion)
        case .google:
            callGoogle(apiKey: apiKey, system: system, messages: messages, completion: completion)
        }
    }

    // MARK: - Anthropic (Claude)

    private func callAnthropic(apiKey: String, system: String,
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

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 300,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else {
                completion(nil)
                return
            }
            completion(text)
        }.resume()
    }

    // MARK: - OpenAI (GPT)

    private func callOpenAI(apiKey: String, system: String,
                             messages: [(role: String, content: String)],
                             completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        var oaiMessages: [[String: String]] = [["role": "system", "content": system]]
        oaiMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 300,
            "messages": oaiMessages
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                completion(nil)
                return
            }
            completion(text)
        }.resume()
    }

    // MARK: - Google (Gemini)

    private func callGoogle(apiKey: String, system: String,
                             messages: [(role: String, content: String)],
                             completion: @escaping (String?) -> Void) {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Gemini uses "contents" array with "parts". System instruction is separate.
        var contents: [[String: Any]] = []
        for msg in messages {
            let role = msg.role == "assistant" ? "model" : "user"
            contents.append(["role": role, "parts": [["text": msg.content]]])
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 300]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                completion(nil)
                return
            }
            completion(text)
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
    var combatSummary: String? = nil
}
