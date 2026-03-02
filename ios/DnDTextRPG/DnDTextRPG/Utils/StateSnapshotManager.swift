//
//  StateSnapshotManager.swift
//  DnDTextRPG
//
//  File I/O for state snapshots — tracks DM mode state for reconciliation
//

import Foundation

class StateSnapshotManager {
    static let shared = StateSnapshotManager()

    private var snapshotsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedGames").appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Snapshot taken when DM mode was entered
    private(set) var dmEntrySnapshot: StateSnapshot?

    /// Most recently written snapshot
    private(set) var latestSnapshot: StateSnapshot?

    func write(_ snapshot: StateSnapshot) {
        latestSnapshot = snapshot
        if snapshot.label == "dm_entry" {
            dmEntrySnapshot = snapshot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(snapshot) else { return }

        // Write to current file
        let currentFile = snapshotsDirectory.appendingPathComponent("current_snapshot.json")
        try? data.write(to: currentFile)

        // Archive with timestamp
        let formatter = ISO8601DateFormatter()
        let ts = formatter.string(from: snapshot.timestamp)
            .replacingOccurrences(of: ":", with: "-")
        let archiveFile = snapshotsDirectory.appendingPathComponent("snapshot_\(ts).json")
        try? data.write(to: archiveFile)

        trimArchives()
    }

    func readCurrent() -> StateSnapshot? {
        let currentFile = snapshotsDirectory.appendingPathComponent("current_snapshot.json")
        guard let data = try? Data(contentsOf: currentFile) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StateSnapshot.self, from: data)
    }

    func clearDMEntry() {
        dmEntrySnapshot = nil
    }

    private func trimArchives(keep: Int = 20) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        let archives = files
            .filter { $0.lastPathComponent.hasPrefix("snapshot_") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        if archives.count > keep {
            for file in archives.suffix(from: keep) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
