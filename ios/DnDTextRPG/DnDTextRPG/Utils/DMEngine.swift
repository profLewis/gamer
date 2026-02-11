//
//  DMEngine.swift
//  DnDTextRPG
//
//  AI-powered Dungeon Master using Claude API
//

import Foundation

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

    // MARK: - System Prompt

    private func buildSystemPrompt(context: DMContext) -> String {
        """
        You are a Dungeon Master for a D&D 5e text adventure. Be creative, atmospheric, \
        and immersive. Keep responses brief (2-4 sentences). Speak in second person ("You see...", \
        "You hear...").

        CURRENT LOCATION: \(context.roomName) (\(context.roomType))
        \(context.roomDescription)
        Exits: \(context.exits)
        Room cleared: \(context.isCleared ? "Yes" : "No — danger lurks here")

        PARTY:
        \(context.partyStatus)

        TIME: \(context.gameTime)

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
            "max_tokens": 200,
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
}
