//
//  Contributors.swift — everyone thanked on the About page.
//
//  The list lives in the repository (contributors.json) so it can grow
//  without a new release: the game reads it at most once a day, keeps a
//  copy, and falls back to the built-in names if it has never managed to
//  fetch one. Names only — nothing here is trusted enough to act on, and
//  anything odd-looking is dropped (see isSensible).
//

import Foundation

struct Contributor: Codable, Identifiable {
    let name: String
    let reason: String

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case reason = "for"
    }

    /// Plain, short, printable text — anything else is left out.
    var isSensible: Bool {
        guard (1...40).contains(name.count), reason.count <= 140 else { return false }
        let bad = CharacterSet.controlCharacters
        return name.rangeOfCharacter(from: bad) == nil && reason.rangeOfCharacter(from: bad) == nil
    }
}

final class ContributorsManager {
    static let shared = ContributorsManager()

    static let listURL = URL(string: "https://raw.githubusercontent.com/profLewis/gamer/main/contributors.json")!
    /// The same list, for a human to read in a browser.
    static let webURL = "https://github.com/profLewis/gamer/blob/main/CONTRIBUTORS.md"
    static let maxBytes = 32 * 1024
    static let maxNames = 60

    static let builtIn: [Contributor] = [
        Contributor(name: "Philip Lewis", reason: "created the game: design, creative direction and relentless testing"),
        Contributor(name: "Beau Lewis", reason: "world creation, storytelling, gameplay structure and style, and game testing"),
        Contributor(name: "Claude (Anthropic)", reason: "code, words, and a great deal of ASCII"),
        Contributor(name: "Codex (OpenAI)", reason: "code assistance"),
    ]

    private(set) var contributors: [Contributor] = ContributorsManager.builtIn
    private var fetching = false

    private struct Body: Codable {
        let version: Int
        let contributors: [Contributor]
    }

    private var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Contributors", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("contributors.json")
    }

    private init() {
        if let url = fileURL, let data = try? Data(contentsOf: url), let list = Self.parse(data) {
            contributors = list
        }
    }

    private static func parse(_ data: Data) -> [Contributor]? {
        guard data.count <= maxBytes,
              let body = try? JSONDecoder().decode(Body.self, from: data) else { return nil }
        let good = body.contributors.filter { $0.isSensible }.prefix(maxNames)
        return good.isEmpty ? nil : Array(good)
    }

    /// At most once a day, quietly.
    func checkIfDue() {
        let last = UserDefaults.standard.double(forKey: "contributorsLastCheck")
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        check(completion: nil)
    }

    /// Fetches the list; `completion` (on the main thread) says what happened.
    func check(completion: ((String) -> Void)?) {
        guard !fetching else { completion?("Already looking…"); return }
        fetching = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "contributorsLastCheck")
        var request = URLRequest(url: Self.listURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        URLSession(configuration: .ephemeral).dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.fetching = false
                guard let data = data, (response as? HTTPURLResponse)?.statusCode == 200,
                      let list = Self.parse(data) else {
                    completion?("Couldn't reach the list just now — showing the names already known.")
                    return
                }
                if let url = self.fileURL { try? data.write(to: url, options: .atomic) }
                self.contributors = list
                completion?("\(list.count) names on the list.")
            }
        }.resume()
    }
}
