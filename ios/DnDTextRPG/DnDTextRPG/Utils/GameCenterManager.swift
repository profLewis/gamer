//
//  GameCenterManager.swift
//  DnDTextRPG
//
//  Game Center integration for leaderboards and achievements
//

import GameKit

class GameCenterManager {
    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false

    // MARK: - Leaderboard IDs (configure in App Store Connect)

    static let leaderboardGold = "com.timbaloo.dnd.textrpg.gold"
    static let leaderboardVictories = "com.timbaloo.dnd.textrpg.victories"
    static let leaderboardSlain = "com.timbaloo.dnd.textrpg.slain"

    // MARK: - Achievement IDs (configure in App Store Connect)

    static let achievementFirstBlood = "first_blood"
    static let achievementDungeonMaster = "dungeon_master"
    static let achievementHoarder = "hoarder"
    static let achievementSlayer = "slayer"
    static let achievementVeteran = "veteran"
    static let achievementLegend = "legend"

    // MARK: - Authentication

    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let vc = viewController {
                // Present Game Center login if needed
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(vc, animated: true)
                    }
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
            } else {
                self?.isAuthenticated = false
                // Silent failure — Game Center is optional
            }
        }
    }

    // MARK: - Leaderboards

    func submitScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else { return }

        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { _ in }
    }

    func showLeaderboard() {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = GameCenterDismisser.shared

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(gcVC, animated: true)
            }
        }
    }

    func showAchievements() {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = GameCenterDismisser.shared

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(gcVC, animated: true)
            }
        }
    }

    // MARK: - Achievements

    func reportAchievement(_ achievementID: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }

        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { _ in }
    }

    /// Check and report achievements based on current game state
    func checkAchievements(combatsWon: Int, monstersSlain: Int, goldCollected: Int,
                           dungeonLevel: Int, isVictory: Bool) {
        // First Blood — win first combat
        if combatsWon >= 1 {
            reportAchievement(Self.achievementFirstBlood)
        }

        // Dungeon Master — conquer first dungeon
        let totalVictories = HallOfFameManager.shared.totalVictories()
        if isVictory {
            if totalVictories >= 1 {
                reportAchievement(Self.achievementDungeonMaster)
            }

            // Veteran — conquer 5 dungeons
            if totalVictories >= 5 {
                reportAchievement(Self.achievementVeteran)
            }

            // Legend — conquer Level 3 dungeon
            if dungeonLevel >= 3 {
                reportAchievement(Self.achievementLegend)
            }
        }

        // Hoarder — 500+ gold in a single run
        if goldCollected >= 500 {
            reportAchievement(Self.achievementHoarder)
        }

        // Slayer — 20+ monsters in a single run
        if monstersSlain >= 20 {
            reportAchievement(Self.achievementSlayer)
        }
    }
}

// MARK: - Dismissal Handler

class GameCenterDismisser: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismisser()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
