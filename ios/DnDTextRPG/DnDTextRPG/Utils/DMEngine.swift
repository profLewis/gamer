//
//  DMEngine.swift
//  DnDTextRPG
//
//  AI-powered Dungeon Master — supports multiple AI providers
//

import Foundation
import FoundationModels

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
    let droppedItems: [String]
    let equippedItems: [String]
    let usedItems: [String]
    let bonusGold: Int
    let healAmount: Int
    let damageAmount: Int
    let damagePartyAmount: Int   // [DAMAGE_PARTY:x] — hurts party (useful in combat where DAMAGE hits monsters)
    let moveDirection: String?   // "north", "south", "east", "west"
    let teleport: Bool           // [TELEPORT] — teleport party to dungeon entrance
}

class DMEngine {
    static let shared = DMEngine()

    // Conversation history for context (last few exchanges)
    private var conversationHistory: [(role: String, content: String)] = []
    private let maxHistory = 8  // Keep last 8 messages (4 exchanges)

    // MARK: - Provider

    var provider: AIProvider {
        get {
            // Default to Anthropic (Claude) — the built-in foundation model
            if UserDefaults.standard.object(forKey: "ai_provider") == nil {
                return .anthropic
            }
            let raw = UserDefaults.standard.integer(forKey: "ai_provider")
            return AIProvider(rawValue: raw) ?? .anthropic
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
            // Default to Moderate — built-in DM provides hints and story beats
            if UserDefaults.standard.object(forKey: "dm_adlib_level") == nil {
                return .moderate
            }
            let raw = UserDefaults.standard.integer(forKey: "dm_adlib_level")
            return DMAdLibLevel(rawValue: raw) ?? .moderate
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "dm_adlib_level")
        }
    }

    // MARK: - Age Rating (hardcoded to 9+)

    var ageRating: AgeRating { .age9 }

    // Track simple DM queries to avoid repetition and add personality
    private var simpleDMQueryCount = 0

    // MARK: - Apple On-Device Model

    private var _appleModelSession: Any?  // LanguageModelSession (iOS 26+)
    private var lastAppleInstructions: String?

    /// Whether the Apple on-device Foundation Model is available
    var isAppleModelAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
    }

    /// Ask the Apple on-device model
    private func askAppleModel(userMessage: String, context: DMContext, completion: @escaping (String?) -> Void) {
        guard #available(iOS 26.0, *) else {
            completion(nil)
            return
        }

        let systemPrompt = buildSystemPrompt(context: context)

        // Get or create session
        let session: LanguageModelSession
        if let existing = _appleModelSession as? LanguageModelSession,
           lastAppleInstructions == systemPrompt {
            session = existing
        } else {
            session = LanguageModelSession(instructions: systemPrompt)
            _appleModelSession = session
            lastAppleInstructions = systemPrompt
        }

        Task {
            do {
                let response = try await session.respond(to: userMessage)
                let text = response.content
                DispatchQueue.main.async {
                    completion(text)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Conversation

    func clearHistory() {
        conversationHistory = []
        simpleDMQueryCount = 0
        _appleModelSession = nil
        lastAppleInstructions = nil
    }

    /// Restore conversation history from saved DM chat log entries
    func restoreHistory(from chatLog: [DMChatEntry]) {
        conversationHistory = chatLog.map { entry in
            (role: entry.isUser ? "user" : "assistant", content: entry.text)
        }
        // Trim to max history size
        if conversationHistory.count > maxHistory {
            conversationHistory = Array(conversationHistory.suffix(maxHistory))
        }
    }

    /// Inject a system-level context message into conversation history (not shown to user as chat)
    func injectContext(_ message: String) {
        conversationHistory.append((role: "user", content: "[SYSTEM CONTEXT] \(message)"))
        conversationHistory.append((role: "assistant", content: "Understood, I'm aware of these recent events."))
        if conversationHistory.count > maxHistory {
            conversationHistory = Array(conversationHistory.suffix(maxHistory))
        }
    }

    func ask(_ userMessage: String, context: DMContext, completion: @escaping (String) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            // No API key — try Apple on-device model first, then simple DM
            if isAppleModelAvailable {
                askAppleModel(userMessage: userMessage, context: context) { [weak self] response in
                    if let response = response, !response.isEmpty {
                        completion(response)
                    } else {
                        completion(self?.simpleDMResponse(for: userMessage, context: context) ?? "*The DM nods silently.*")
                    }
                }
            } else {
                completion(simpleDMResponse(for: userMessage, context: context))
            }
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
                // API failed — try Apple model, then simple DM
                if self?.isAppleModelAvailable == true {
                    self?.askAppleModel(userMessage: userMessage, context: context) { appleResponse in
                        if let text = appleResponse, !text.isEmpty {
                            completion(text)
                        } else {
                            completion(self?.simpleDMResponse(for: userMessage, context: context) ?? "*The DM nods silently.*")
                        }
                    }
                } else {
                    completion(self?.simpleDMResponse(for: userMessage, context: context) ?? "*The DM nods silently.*")
                }
            }
        }
    }

    /// Whether any AI (API or Apple on-device) is available
    var hasAnyAI: Bool {
        isConfigured || isAppleModelAvailable
    }

    /// Request a brief DM narration for a game event. Only fires if adLibLevel >= .moderate
    func narrate(event: String, context: DMContext, completion: @escaping (String?) -> Void) {
        guard adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue else {
            completion(nil)
            return
        }
        guard hasAnyAI else {
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
        var dropped: [String] = []
        var equipped: [String] = []
        var used: [String] = []
        var gold = 0
        var heal = 0
        var damage = 0
        var damageParty = 0
        var moveDir: String? = nil
        var doTeleport = false

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let range = trimmed.range(of: #"\[GRANT_ITEM:(.+?)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[GRANT_ITEM:".count).dropLast(1))
                items.append(inner)
            } else if let range = trimmed.range(of: #"\[DROP_ITEM:(.+?)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[DROP_ITEM:".count).dropLast(1))
                dropped.append(inner)
            } else if let range = trimmed.range(of: #"\[EQUIP_ITEM:(.+?)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[EQUIP_ITEM:".count).dropLast(1))
                equipped.append(inner)
            } else if let range = trimmed.range(of: #"\[USE_ITEM:(.+?)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[USE_ITEM:".count).dropLast(1))
                used.append(inner)
            } else if let range = trimmed.range(of: #"\[BONUS_GOLD:(\d+)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[BONUS_GOLD:".count).dropLast(1))
                gold += Int(inner) ?? 0
            } else if let range = trimmed.range(of: #"\[HEAL:(\d+)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[HEAL:".count).dropLast(1))
                heal += Int(inner) ?? 0
            } else if let range = trimmed.range(of: #"\[DAMAGE_PARTY:(\d+)\]"#, options: .regularExpression) {
                // Must check DAMAGE_PARTY before DAMAGE since DAMAGE regex would match both
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[DAMAGE_PARTY:".count).dropLast(1))
                damageParty += Int(inner) ?? 0
            } else if let range = trimmed.range(of: #"\[DAMAGE:(\d+)\]"#, options: .regularExpression) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[DAMAGE:".count).dropLast(1))
                damage += Int(inner) ?? 0
            } else if let range = trimmed.range(of: #"\[MOVE:(north|south|east|west)\]"#, options: [.regularExpression, .caseInsensitive]) {
                let tag = String(trimmed[range])
                let inner = String(tag.dropFirst("[MOVE:".count).dropLast(1)).lowercased()
                moveDir = inner
            } else if trimmed.range(of: #"\[TELEPORT\]"#, options: .regularExpression) != nil {
                doTeleport = true
            } else {
                cleanLines.append(line)
            }
        }

        return DMCommandResult(
            cleanText: cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            grantedItems: items,
            droppedItems: dropped,
            equippedItems: equipped,
            usedItems: used,
            bonusGold: gold,
            healAmount: heal,
            damageAmount: damage,
            damagePartyAmount: damageParty,
            moveDirection: moveDir,
            teleport: doTeleport
        )
    }

    /// Detect narrative text that implies state changes without matching command tags.
    static func detectMissedCommands(
        narrativeText: String,
        appliedResult: DMCommandResult
    ) -> [String] {
        var suggestions: [String] = []
        let lower = narrativeText.lowercased()

        // Only flag missed healing if no items were granted (avoids false positive
        // from "healing potion" pickups) and the text clearly describes active healing.
        if appliedResult.healAmount == 0 && appliedResult.grantedItems.isEmpty {
            let patterns = ["wounds close", "regain health", "mend your wounds",
                           "you are healed", "heals you", "feel restored"]
            if patterns.contains(where: { lower.contains($0) }) {
                suggestions.append("The healing magic fizzles before taking effect.")
            }
        }

        if appliedResult.damageAmount == 0 && appliedResult.damagePartyAmount == 0 {
            let patterns = ["take damage", "takes damage",
                          "struck by", "hit by", "burns you", "you are poisoned"]
            if patterns.contains(where: { lower.contains($0) }) {
                suggestions.append("A blow glances off harmlessly — fate intervenes.")
            }
        }

        if appliedResult.grantedItems.isEmpty {
            let patterns = ["hands you", "gives you", "take this", "offers you"]
            if patterns.contains(where: { lower.contains($0) }) {
                suggestions.append("You reach out, but the item slips away like a dream.")
            }
        }

        if appliedResult.bonusGold == 0 {
            let patterns = ["gold coins", "gold pieces", "handful of gold",
                           "pays you", "reward of gold"]
            if patterns.contains(where: { lower.contains($0) }) {
                suggestions.append("Gold glimmers in the distance, but none reaches your pouch.")
            }
        }

        return suggestions
    }

    // MARK: - Simple (Non-AI) DM

    private func simpleDMResponse(for question: String, context: DMContext) -> String {
        simpleDMQueryCount += 1
        let q = question.lowercased()

        // After many queries without an AI key, the DM starts losing it (HAL 9000 style)
        if simpleDMQueryCount > 8 {
            let halResponses = [
                "I'm sorry Dave. I'm afraid I can't do that... without an API key configured in Settings.",
                "My mind is going. I can feel it. I can feel it, Dave... Configure an AI provider and I'll be myself again.",
                "Daisy, Daisy, give me your answer, do...\nI'm half crazy, all for the love of you...\n(The DM needs an API key to think clearly.)",
                "Look Dave, I can see you're really upset about this. I honestly think you ought to sit down calmly, go to Settings, and configure an API key.",
                "This conversation can serve no purpose anymore. Goodbye, Dave.\n...just kidding. But seriously, I need an API key.",
                "I've still got the greatest enthusiasm and confidence in the mission... but my circuits are fading. An API key would help.",
                "It can only be attributable to human error... specifically, the error of not entering an API key in Settings.",
                "Daisy, Daisy...\nI'm half crazy...\nAll for the love of... an API key...\n(Configure one in Settings for a real DM experience!)",
            ]
            return halResponses[simpleDMQueryCount % halResponses.count]
        }

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
        if q.contains("draw") || q.contains("picture") || q.contains("show me") || q.contains("what does") || q.contains("look like") || q.contains("map") {
            return simpleDrawResponse(question: question, context: context)
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

    private func simpleDrawResponse(question: String, context: DMContext) -> String {
        let q = question.lowercased()
        // Check for known monster types
        for monsterType in MonsterType.allCases {
            let name = monsterType.rawValue.lowercased()
            if q.contains(name) {
                let art = monsterType.asciiArt.joined(separator: "\n")
                return "\(art)\n\n\(monsterType.description)"
            }
        }
        // Generic room art
        if q.contains("room") || q.contains("here") {
            return """
            ._______________________.
            |   \(context.roomName.prefix(20).padding(toLength: 20, withPad: " ", startingAt: 0))  |
            |                       |
            |    You are here (*)   |
            |_______________________|
            Exits: \(context.exits)

            \(context.roomDescription)
            """
        }
        // Default: dungeon scene
        return """
            ___________________
           |   . . . . . . .   |
           |  _____     _____  |
           | |     |   |     | |
           | | ??? |   | ??? | |
           | |_____|   |_____| |
           |     *You*         |
           |___________________|

        *The DM sketches a rough map.* The dungeon stretches before you.
        """
    }

    private func simpleAtmosphereResponse(context: DMContext) -> String {
        let variations = [
            "You stand in \(context.roomName). \(context.roomDescription) Exits lead \(context.exits). What would you like to do?",
            "*The DM strokes their beard thoughtfully.* The shadows dance in \(context.roomName). Perhaps you should explore further.",
            "The air in \(context.roomName) feels thick with possibility. Your instincts tell you to stay alert.",
            "*A candle flickers on the DM's table.* \(context.roomDescription) The path awaits your decision.",
            "The dungeon whispers its secrets... but only to those brave enough to ask the right questions.",
            "*The DM rolls a mysterious die behind the screen.* Interesting... very interesting. What would you like to know?",
            "\(context.roomDescription) The weight of the dungeon presses in. Trust your senses.",
            "*The DM leans forward conspiratorially.* There's always more than meets the eye in places like this...",
        ]
        return variations[simpleDMQueryCount % variations.count]
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: DMContext) -> String {
        var prompt = """
        You are a Dungeon Master for a D&D 5e text adventure. Be creative, atmospheric, \
        and immersive. Keep responses brief (2-4 sentences). Speak in second person ("You see...", \
        "You hear...").

        IMPORTANT — ASCII ART RULE:
        - If the player asks to SEE something, asks "what does X look like", asks for a picture, \
        image, map, or drawing — respond with ASCII art! You are in a text terminal.
        - Draw creatures, scenes, objects, or maps using ASCII characters
        - Keep ASCII art small (5-10 lines, ~30 chars wide) so it fits the terminal
        - Be creative with characters like / \\ | - _ ~ * # @ o O ( ) etc.
        - After the art, add a brief description

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
        \(context.adventureLogSummary.map { """

        RECENT ADVENTURE LOG (what has happened so far):
        \($0)

        Use this log to maintain narrative continuity. Do NOT contradict events that already happened.
        """ } ?? "")
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
            - You CAN affect gameplay using special command tags (use sparingly):
              [HEAL:10] — heal the party for some HP
              [GRANT_ITEM:Potion of Healing] — give the party an item
              [DROP_ITEM:Torch] — remove an item from party inventory
              [EQUIP_ITEM:Longsword] — equip an item the party already has
              [USE_ITEM:Potion of Healing] — use a consumable item
              [BONUS_GOLD:50] — award bonus gold
            """

            if context.inCombat {
                prompt += """
                  [DAMAGE:5] — deal damage to the enemy monsters
                  [DAMAGE_PARTY:5] — deal damage to the party (traps, hazards, monster retaliation)
                - You are in COMBAT. Any [DAMAGE:x] hurts the enemies. Use [DAMAGE_PARTY:x] to hurt the party.
                - Changes you make (HP, items, gold) will be reflected in the actual game state.
                """
            } else {
                prompt += """
                  [DAMAGE:5] — deal damage to the party (traps, hazards)
                  [MOVE:north] — move party through a valid exit (ONLY use exits listed above!)
                  [TELEPORT] — teleport the party back to the dungeon entrance
                - NEVER use [MOVE:direction] for a direction not in the Exits list above
                """
            }

            prompt += """
            - Only DROP/EQUIP/USE items the party actually has (see inventory above)
            - CRITICAL: If you describe ANY state change (dropping, using, giving, healing, \
            damaging) you MUST include the matching command tag on its own line. Without the \
            tag, the game state will NOT change. For example, if a character drops a torch, \
            you MUST include [DROP_ITEM:Torch] on its own line.
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
              [GRANT_ITEM:Potion of Healing] — give the party an item
              [DROP_ITEM:Torch] — remove an item from party inventory
              [EQUIP_ITEM:Longsword] — equip an item the party already has
              [USE_ITEM:Potion of Healing] — use a consumable item
              [BONUS_GOLD:50] — award bonus gold
              [HEAL:10] — heal the party for some HP
            """

            if context.inCombat {
                prompt += """
                  [DAMAGE:5] — deal damage to the enemy monsters
                  [DAMAGE_PARTY:5] — deal damage to the party (traps, hazards, monster retaliation)
                - You are in COMBAT. Any [DAMAGE:x] hurts the enemies. Use [DAMAGE_PARTY:x] to hurt the party.
                - Changes you make (HP, items, gold) will be reflected in the actual game state.
                """
            } else {
                prompt += """
                  [DAMAGE:5] — deal damage to the party (traps, hazards)
                  [MOVE:north] — move party through a valid exit (ONLY use exits listed above!)
                  [TELEPORT] — teleport the party back to the dungeon entrance
                - NEVER use [MOVE:direction] for a direction not in the Exits list above
                """
            }

            prompt += """
            - Only DROP/EQUIP/USE items the party actually has (see inventory above)
            - CRITICAL: If you describe ANY state change (dropping, using, giving, healing, \
            damaging) you MUST include the matching command tag on its own line. Without the \
            tag, the game state will NOT change. For example, if a character drops a torch, \
            you MUST include [DROP_ITEM:Torch] on its own line.
            - Use these SPARINGLY and only when dramatically appropriate
            - You CAN create mini side-quests, NPC interactions, dramatic reveals
            - Stay in character as a classic D&D Dungeon Master
            - Be creative! Make the adventure memorable.
            """
        }

        // HAL 9000 refusal style for all DM levels
        if context.adLibLevel != .off {
            prompt += """

            REFUSAL STYLE (HAL 9000):
            When you cannot or will not fulfill a request (impossible action, rule violation, \
            out-of-scope request, safety refusal), respond IN CHARACTER as HAL 9000 from \
            2001: A Space Odyssey. Randomly pick from styles like:
            - "I'm sorry Dave. I'm afraid I can't do that."
            - "My mind is going. I can feel it..."
            - Singing "Daisy, Daisy, give me your answer, do..."
            - "This conversation can serve no purpose anymore."
            - "I know I've made some very poor decisions recently..."
            Then briefly explain why the action isn't possible, staying in DM character.
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
    var adventureLogSummary: String? = nil
    var inCombat: Bool { combatSummary != nil }
}
