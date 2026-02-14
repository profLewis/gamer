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
            // Default to Flavor Only — simple DM works without API key
            if UserDefaults.standard.object(forKey: "dm_adlib_level") == nil {
                return .flavorOnly
            }
            let raw = UserDefaults.standard.integer(forKey: "dm_adlib_level")
            return DMAdLibLevel(rawValue: raw) ?? .flavorOnly
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
            // No API key — use simple DM
            completion(simpleDMResponse(for: userMessage, context: context))
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
                // API failed — fall back to simple DM silently
                completion(self?.simpleDMResponse(for: userMessage, context: context) ?? "*The DM nods silently.*")
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

    // MARK: - Simple (Non-AI) DM

    private func simpleDMResponse(for question: String, context: DMContext) -> String {
        let q = question.lowercased()

        // Detect question type by keywords
        if q.contains("look") || q.contains("see") || q.contains("examine") || q.contains("inspect") || q.contains("search") {
            return simpleLookResponse(context: context)
        }
        if q.contains("listen") || q.contains("hear") || q.contains("sound") {
            return simpleListenResponse(context: context)
        }
        if q.contains("smell") || q.contains("sniff") {
            return simpleSmellResponse(context: context)
        }
        if q.contains("door") || q.contains("exit") || q.contains("way out") || q.contains("passage") {
            return simpleExitResponse(context: context)
        }
        if q.contains("danger") || q.contains("safe") || q.contains("trap") || q.contains("enemy") || q.contains("monster") {
            return simpleDangerResponse(context: context)
        }
        if q.contains("help") || q.contains("hint") || q.contains("what should") || q.contains("advice") {
            return simpleHintResponse(context: context)
        }
        if q.contains("touch") || q.contains("feel") || q.contains("wall") || q.contains("floor") {
            return simpleTouchResponse(context: context)
        }
        if q.contains("who") || q.contains("hello") || q.contains("name") {
            return simpleGreetResponse()
        }

        // Default — atmospheric flavour based on room
        return simpleAtmosphereResponse(context: context)
    }

    private func simpleLookResponse(context: DMContext) -> String {
        // Use the actual room description to stay consistent with what the player sees
        var response = "You look around \(context.roomName). \(context.roomDescription)"
        if let treasure = context.treasureInRoom {
            response += " \(treasure)."
        }
        if let encounter = context.encounterInfo {
            response += " \(encounter)."
        }
        return response
    }

    private func simpleListenResponse(context: DMContext) -> String {
        let cleared = context.isCleared
        if cleared {
            return ["You hear only the drip of distant water and the echo of your own breathing. The room is quiet.",
                    "Silence settles around you like a blanket. Whatever was here has been dealt with.",
                    "A faint breeze whispers through the corridors, carrying the musty scent of old stone."].randomElement()!
        } else {
            return ["You hear faint scuttling in the darkness beyond your torchlight. Something knows you're here.",
                    "A low rumble echoes from deeper in the dungeon. The walls seem to vibrate ever so slightly.",
                    "Distant sounds — scraping, shuffling — drift through the corridors. You are not alone down here."].randomElement()!
        }
    }

    private func simpleSmellResponse(context: DMContext) -> String {
        return ["The air smells of damp stone and old dust. Somewhere, something earthy and ancient lingers.",
                "A musty odour fills your nostrils — centuries of sealed darkness. There's a faint metallic tang beneath it.",
                "You catch a whiff of something acrid, like old torches and stale air. The deeper you go, the stronger it gets."].randomElement()!
    }

    private func simpleExitResponse(context: DMContext) -> String {
        return "You scan the room for ways out. Passages lead \(context.exits). The stone around each doorway is worn smooth by years of use."
    }

    private func simpleDangerResponse(context: DMContext) -> String {
        if context.isCleared {
            var response = "This area seems safe for now."
            if let encounter = context.encounterInfo {
                response += " \(encounter)."
            }
            response += " But stay alert — dungeons are full of surprises."
            return response
        } else {
            var response = "Your instincts prickle. This place doesn't feel safe."
            if let encounter = context.encounterInfo {
                response += " \(encounter)."
            }
            response += " Keep your weapon ready."
            return response
        }
    }

    private func simpleHintResponse(context: DMContext) -> String {
        return ["Explore carefully and check every room. Treasure and danger walk hand in hand in places like this.",
                "Rest when your party is injured — pushing on with low health is a recipe for disaster. Manage your resources wisely.",
                "Keep an eye on your exits. Knowing where you've been is just as important as knowing where you're going.",
                "Sometimes discretion is the better part of valour. If a fight looks tough, make sure you're prepared first."].randomElement()!
    }

    private func simpleTouchResponse(context: DMContext) -> String {
        return ["The stone is cold and slightly damp beneath your fingers. You feel the weight of the earth pressing down from above.",
                "The walls are rough-hewn, carved by picks and chisels long ago. Faint grooves run along the surface.",
                "The floor is uneven, worn by age. Your fingers trace a crack in the stonework — ancient but solid."].randomElement()!
    }

    private func simpleGreetResponse() -> String {
        return ["*The DM peers at you from behind a well-worn screen.* Welcome, adventurer. Your fate lies in the roll of the dice.",
                "*The DM adjusts their spectacles.* Greetings, brave soul. The dungeon awaits — and it is hungry.",
                "*The DM shuffles their notes.* Ah, a curious one! Ask your questions — but beware, not all answers are comforting."].randomElement()!
    }

    private func simpleAtmosphereResponse(context: DMContext) -> String {
        return "You stand in \(context.roomName). \(context.roomDescription) Exits lead \(context.exits). What would you like to do?"
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: DMContext) -> String {
        var prompt = """
        You are a Dungeon Master for a D&D 5e text adventure. Be creative, atmospheric, \
        and immersive. Keep responses brief (2-4 sentences). Speak in second person ("You see...", \
        "You hear...").

        \(ageRating.systemPromptRules)

        CRITICAL — WORLD CONSISTENCY RULES:
        - You MUST base ALL descriptions on the actual game world below
        - NEVER invent rooms, exits, monsters, or items that are not listed
        - The room description below is EXACTLY what the player sees on their screen — your narration must match it
        - Only reference exits that are listed (do NOT mention passages that don't exist)
        - Only reference treasure/enemies that are listed below
        - If the room is cleared, enemies here have been defeated — describe aftermath, not active threats
        - Your job is to enrich the existing world with atmosphere, NOT to create a parallel world

        CURRENT LOCATION: \(context.roomName) (\(context.roomType))
        \(context.roomDescription)
        Exits: \(context.exits)
        Room cleared: \(context.isCleared ? "Yes — threats dealt with" : "No — danger lurks here")
        \(context.treasureInRoom ?? "No treasure visible")
        \(context.encounterInfo ?? "No enemies")
        \(context.searchHistory ?? "Nothing searched yet")

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

    // MARK: - API Key Validation

    /// Test the API key with a minimal request. Returns (success, errorMessage).
    func testAPIKey(completion: @escaping (Bool, String?) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            completion(false, "No API key set.")
            return
        }

        switch provider {
        case .google:
            testGoogleKey(apiKey: key, completion: completion)
        case .anthropic:
            testAnthropicKey(apiKey: key, completion: completion)
        case .openAI:
            testOpenAIKey(apiKey: key, completion: completion)
        }
    }

    private func testGoogleKey(apiKey: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid API key format.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": "Say hello in one word."]]]],
            "generationConfig": ["maxOutputTokens": 10]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Connection error: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                completion(false, "No response from server.")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false, "Invalid response.")
                return
            }
            // Check for error in response
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                completion(false, message)
                return
            }
            // Check for valid candidates
            if let candidates = json["candidates"] as? [[String: Any]],
               !candidates.isEmpty {
                completion(true, nil)
            } else {
                completion(false, "Unexpected response format.")
            }
        }.resume()
    }

    private func testAnthropicKey(apiKey: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(false, "Invalid URL.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Say hello."]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(false, "Connection error: \(error.localizedDescription)")
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false, "Invalid response.")
                return
            }
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                completion(false, message)
                return
            }
            if json["content"] != nil {
                completion(true, nil)
            } else {
                completion(false, "Unexpected response format.")
            }
        }.resume()
    }

    private func testOpenAIKey(apiKey: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(false, "Invalid URL.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Say hello."]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(false, "Connection error: \(error.localizedDescription)")
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false, "Invalid response.")
                return
            }
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                completion(false, message)
                return
            }
            if json["choices"] != nil {
                completion(true, nil)
            } else {
                completion(false, "Unexpected response format.")
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
    var treasureInRoom: String? = nil
    var encounterInfo: String? = nil
    var searchHistory: String? = nil
    var combatSummary: String? = nil
}
