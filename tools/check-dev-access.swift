#!/usr/bin/env swift
//
//  check-dev-access.swift — checks the hidden-buttons phrase is where the
//  maker keeps it, and still matches the game.
//
//  The game holds only a SHA-256 of the phrase (DevAccess.phraseHash in
//  ios/DnDTextRPG/DnDTextRPG/Utils/DevAccess.swift). The phrase itself lives
//  in two places, never in git:
//    1. .dev-access at the repo root (git-ignored), and
//    2. the login Keychain — service "dndrpg-hidden-buttons" (search "dndrpg").
//
//  Run from the repo root:   swift tools/check-dev-access.swift
//  Checks the file first. If it's missing, or doesn't match (you're asked),
//  checks the Keychain.       --keychain skips straight to the Keychain.
//

import Foundation
import CryptoKit

let service = "dndrpg-hidden-buttons"
let root = FileManager.default.currentDirectoryPath
let swiftFile = root + "/ios/DnDTextRPG/DnDTextRPG/Utils/DevAccess.swift"
let localFile = root + "/.dev-access"

func normalize(_ s: String) -> String { s.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
func hash(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }

guard let source = try? String(contentsOfFile: swiftFile, encoding: .utf8),
      let range = source.range(of: #"phraseHash = "([0-9a-f]{64})""#, options: .regularExpression) else {
    print("Can't read DevAccess.phraseHash from \(swiftFile) — run this from the repo root."); exit(1)
}
let appHash = String(source[range].dropFirst("phraseHash = \"".count).dropLast())

func keychainPhrase() -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["find-generic-password", "-s", service, "-w"]
    let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
    guard (try? p.run()) != nil else { return nil }
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
}

func checkKeychain() -> Never {
    guard let phrase = keychainPhrase() else {
        print("✗ Nothing in the Keychain under service \"\(service)\" (or access was refused)."); exit(1)
    }
    if hash(normalize(phrase)) == appHash {
        print("✓ The Keychain's phrase matches the game.")
        exit(0)
    }
    print("✗ The Keychain's phrase does NOT match the game's stored code.")
    exit(1)
}

if CommandLine.arguments.contains("--keychain") { checkKeychain() }

guard let local = try? String(contentsOfFile: localFile, encoding: .utf8) else {
    print("No local file at \(localFile) — looking in the Keychain.")
    checkKeychain()
}
if hash(normalize(local)) == appHash {
    print("✓ The local file matches the game  (file://\(localFile))")
    exit(0)
}
print("✗ The local file doesn't match the game's stored code.")
print("  Open it: file://\(localFile)")
print("Look in the Keychain instead? [y/N] ", terminator: "")
if let answer = readLine(), answer.lowercased().hasPrefix("y") { checkKeychain() }
exit(1)
