#!/usr/bin/env swift
//
//  sign-puzzle-pack.swift — signs the puzzle pack the game downloads.
//
//  The game only installs a pack whose Ed25519 signature checks out against
//  the public key built into the app (PuzzlePackManager.publicKeyBase64), and
//  only if its version is newer than the one it has — so nobody can slip in
//  puzzles of their own, or roll players back to an older pack.
//
//  One-off, on the maintainer's machine:
//      swift tools/sign-puzzle-pack.swift --generate-key
//  (writes the PRIVATE key to ~/.config/gamer/puzzle-signing-key — outside the
//  repo; never commit it — and prints the public key for the app.)
//
//  Each time the puzzles change: bump "version" in puzzles/source.json, then
//      swift tools/sign-puzzle-pack.swift puzzles/source.json puzzles/pack.json
//  and commit both files. Players get it within a day (or at once via
//  Settings > Puzzles > Check for New Puzzles).
//

import Foundation
import CryptoKit

let maxPackBytes = 256 * 1024
let defaultKeyPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/gamer/puzzle-signing-key").path

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())

if args.first == "--generate-key" {
    let path = args.count > 1 ? args[1] : defaultKeyPath
    if FileManager.default.fileExists(atPath: path) { fail("A key already exists at \(path) — not overwriting it.") }
    let key = Curve25519.Signing.PrivateKey()
    do {
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try key.rawRepresentation.base64EncodedString().write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    } catch { fail("Couldn't write the key: \(error)") }
    print("Private key written to \(path) — keep it safe, never commit it.")
    print("Public key (PuzzlePackManager.publicKeyBase64):")
    print(key.publicKey.rawRepresentation.base64EncodedString())
    exit(0)
}

var keyPath = defaultKeyPath
let useKeychainOnly = args.contains("--keychain")
args.removeAll { $0 == "--keychain" }
if let i = args.firstIndex(of: "--key"), i + 1 < args.count {
    keyPath = args[i + 1]
    args.removeSubrange(i...(i + 1))
}
guard args.count == 2 else {
    fail("usage: swift tools/sign-puzzle-pack.swift [--key KEYFILE] SOURCE.json PACK.json\n       swift tools/sign-puzzle-pack.swift --generate-key [KEYFILE]")
}

/// The key's backup in the login Keychain (service = the repo's URL).
func keyFromKeychain() -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["find-generic-password", "-s", "https://github.com/profLewis/gamer", "-a", "puzzle-signing-key", "-w"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    guard (try? p.run()) != nil else { return nil }
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
}

// The key file if there is one (or --keychain to skip it), else the Keychain copy.
let keyText = (useKeychainOnly ? nil : try? String(contentsOfFile: keyPath, encoding: .utf8)) ?? keyFromKeychain()
guard let keyText = keyText,
      let raw = Data(base64Encoded: keyText.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
    fail("Can't find the signing key at \(keyPath) or in the Keychain (make one with --generate-key).")
}

guard let source = try? Data(contentsOf: URL(fileURLWithPath: args[0])),
      let object = try? JSONSerialization.jsonObject(with: source) as? [String: Any],
      let version = object["version"] as? Int,
      let puzzles = object["puzzles"] as? [[String: Any]] else {
    fail("\(args[0]) must be a JSON object: {\"version\": N, \"puzzles\": [ ... ]}")
}

// The same checks the game makes, so a bad pack is caught here, not on phones.
var ids = Set<String>()
for (n, p) in puzzles.enumerated() {
    let id = p["id"] as? String ?? ""
    let tier = p["tier"] as? Int ?? 0
    let question = p["question"] as? String ?? ""
    let options = p["options"] as? [String]
    let answers = p["answers"] as? [String]
    if id.isEmpty || ids.contains(id) { fail("Puzzle #\(n + 1): missing or repeated id \"\(id)\"") }
    ids.insert(id)
    if !(1...4).contains(tier) { fail("\(id): tier must be 1-4") }
    if question.isEmpty || question.count > 600 { fail("\(id): question missing or too long") }
    if options == nil && (answers ?? []).isEmpty { fail("\(id): needs options (multiple choice) or answers (typed)") }
    if let o = options, o.count < 2 || o.count > 6 { fail("\(id): 2-6 options, correct one first") }
}

guard let payload = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { fail("Couldn't encode the payload") }
guard payload.count <= maxPackBytes else { fail("Pack is \(payload.count) bytes; the game refuses anything over \(maxPackBytes).") }
guard let signature = try? key.signature(for: payload) else { fail("Signing failed") }

let pack: [String: Any] = ["format": 1, "payload": payload.base64EncodedString(), "signature": signature.base64EncodedString()]
guard let out = try? JSONSerialization.data(withJSONObject: pack, options: [.sortedKeys, .prettyPrinted]) else { fail("Couldn't encode the pack") }
do { try out.write(to: URL(fileURLWithPath: args[1])) } catch { fail("Couldn't write \(args[1]): \(error)") }
print("Signed pack v\(version): \(puzzles.count) puzzles -> \(args[1]) (\(out.count) bytes)")
