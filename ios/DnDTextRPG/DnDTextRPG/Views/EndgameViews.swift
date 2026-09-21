//
//  EndgameViews.swift — the end of an adventure: fireworks, a look at any
//  PDF before it's kept, and the shelf where finished adventures'
//  certificates are stored (Settings > Certificates).
//
//  The certificate itself is drawn in ASCII (GameEngine.certificateLines),
//  the same words on screen and on paper — see CertificateView.
//

import SwiftUI
#if canImport(PDFKit) && !os(tvOS)
import PDFKit
#endif

// MARK: - Fireworks

/// Bursts of sparks over everything for a few seconds — none at all with
/// Reduce Motion on. Never takes a tap.
struct FireworksView: View {
    let start: Date
    let until: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let now = timeline.date
                    Self.draw(&ctx, size: size, t: now.timeIntervalSince(start),
                              fade: min(1, max(0, until.timeIntervalSince(now))))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private static let colors: [Color] = [.yellow, .red, .orange, .pink, .cyan, .green, .white,
                                           Color(red: 0.86, green: 0.69, blue: 0.24)]

    /// A fixed "random" number in 0..<1 for n, so a burst stays put frame to frame.
    private static func rand(_ n: Int) -> Double {
        var x = UInt64(bitPattern: Int64(n)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Double(x % 100_000) / 100_000
    }

    private static func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double, fade: Double) {
        let every = 0.5, life = 1.8
        guard t >= 0 else { return }
        let last = Int(t / every)
        let first = max(0, Int((t - life - 0.3) / every))
        let reach = Double(min(size.width, size.height))
        for b in first...max(first, last) {
            let born = Double(b) * every + 0.3 * rand(b &* 7)
            let age = t - born
            guard age >= 0, age < life else { continue }
            let cx = Double(size.width) * (0.12 + 0.76 * rand(b &* 3 &+ 1))
            let cy = Double(size.height) * (0.1 + 0.45 * rand(b &* 5 &+ 2))
            let color = colors[Int(rand(b &* 11 &+ 3) * Double(colors.count)) % colors.count]
            let speed = reach * (0.18 + 0.14 * rand(b &* 13 &+ 4))
            let alpha = (1 - age / life) * fade
            let spread = speed * (1 - exp(-age * 2.4))
            let drop = 0.12 * reach * age * age
            let dot = 1.6 + 1.8 * (1 - age / life)
            for p in 0..<30 {
                let angle = Double(p) / 30 * 2 * Double.pi + 0.2 * rand(b &* 17 &+ p)
                let x = cx + cos(angle) * spread
                let y = cy + sin(angle) * spread + drop
                ctx.fill(Path(ellipseIn: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(color.opacity(alpha)))
            }
            if age < 0.18 {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14)),
                         with: .color(.white.opacity((0.18 - age) / 0.18 * fade)))
            }
        }
    }
}

// MARK: - Certificates kept

/// A finished adventure's certificate, as kept on disk.
struct SavedCertificate: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let title: String
    let heroes: [[String]]      // [name, detail]
    let quest: String
    let village: String?
    let stats: [[String]]       // [label, value]
    let levels: [AtlasLevel]
    let date: String

    init(_ c: GameEngine.EndgameCertificate) {
        id = UUID()
        savedAt = Date()
        title = c.title
        heroes = c.heroes.map { [$0.name, $0.detail] }
        quest = c.quest
        village = c.village
        stats = c.stats.map { [$0.0, $0.1] }
        levels = c.levels
        date = c.date
    }

    var certificate: GameEngine.EndgameCertificate {
        GameEngine.EndgameCertificate(title: title,
                                      heroes: heroes.map { (name: $0.first ?? "", detail: $0.count > 1 ? $0[1] : "") },
                                      quest: quest, village: village,
                                      stats: stats.map { ($0.first ?? "", $0.count > 1 ? $0[1] : "") },
                                      levels: levels, date: date, preview: false)
    }

    /// "Ada, Wren & Pip" — short enough for a button.
    var heroNames: String {
        let names = heroes.compactMap { $0.first?.split(separator: " ").first.map(String.init) }
        guard names.count > 1 else { return names.first ?? "Heroes" }
        return names.dropLast().joined(separator: ", ") + " & " + names.last!
    }
}

/// The certificate shelf: Documents/Certificates, one file each.
enum CertificateStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Certificates")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ c: GameEngine.EndgameCertificate) {
        let saved = SavedCertificate(c)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(saved) else { return }
        try? data.write(to: directory.appendingPathComponent("\(saved.id.uuidString).json"))
    }

    /// Newest first.
    static func list() -> [SavedCertificate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(SavedCertificate.self, from: Data(contentsOf: $0)) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id.uuidString).json"))
    }
}

// MARK: - PDFs

/// A PDF waiting in the preview sheet, before it's saved or printed.
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
    let name: String
    let title: String
}

#if canImport(PDFKit) && !os(tvOS)
/// A PDF before it's kept: look it over, then Save… or Print (on a Mac,
/// or open it in Preview).
struct PDFPreviewSheet: View {
    let item: PDFPreviewItem
    let onSave: () -> Void
    let onPrint: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(item.title).font(.headline)
                Spacer()
                #if os(macOS)
                Button("Open in Preview", action: openInPreview)
                #endif
                Button("Print", action: onPrint)
                Button("Save…", action: onSave).keyboardShortcut(.defaultAction)
                Button("Close", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            PDFKitView(data: item.data)
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 780)
        #endif
    }

    #if os(macOS)
    private func openInPreview() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.name + ".pdf")
        try? item.data.write(to: url)
        NSWorkspace.shared.open(url)
    }
    #endif
}

#if os(iOS) || os(visionOS)
private struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
#else
private struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {}
}
#endif
#endif
