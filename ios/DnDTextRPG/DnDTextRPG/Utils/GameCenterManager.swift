//
//  GameCenterManager.swift
//  DnDTextRPG
//
//  Game Center integration for leaderboards, achievements, and multiplayer
//

import GameKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Turn-Based Match Delegate

protocol TurnBasedMatchDelegate: AnyObject {
    func didReceiveTurn(match: GKTurnBasedMatch, didBecomeActive: Bool)
    func matchEnded(match: GKTurnBasedMatch)
    func playerWantsToQuit(match: GKTurnBasedMatch, player: GKPlayer)
}

class GameCenterManager: NSObject {
    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false

    // MARK: - Multiplayer

    weak var turnBasedDelegate: TurnBasedMatchDelegate?
    var currentMatch: GKTurnBasedMatch?

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
                #if canImport(UIKit)
                self?.presentFromTop(vc)
                #endif
            } else if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
                // Register as turn-based event listener
                GKLocalPlayer.local.register(self!)
            } else {
                self?.isAuthenticated = false
            }
        }
    }

    // MARK: - Leaderboards

    func submitScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else { return }

        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { _ in }
    }

    #if canImport(UIKit)
    /// Present a view controller from the topmost visible controller
    private func presentFromTop(_ vc: UIViewController) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(vc, animated: true)
        }
    }
    #endif


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
        if combatsWon >= 1 {
            reportAchievement(Self.achievementFirstBlood)
        }

        let totalVictories = HallOfFameManager.shared.totalVictories()
        if isVictory {
            if totalVictories >= 1 {
                reportAchievement(Self.achievementDungeonMaster)
            }
            if totalVictories >= 5 {
                reportAchievement(Self.achievementVeteran)
            }
            if dungeonLevel >= 3 {
                reportAchievement(Self.achievementLegend)
            }
        }

        if goldCollected >= 500 {
            reportAchievement(Self.achievementHoarder)
        }
        if monstersSlain >= 20 {
            reportAchievement(Self.achievementSlayer)
        }
    }

    // MARK: - Turn-Based Matchmaker

    func showMatchmaker(minPlayers: Int = 2, maxPlayers: Int = 4) {
        guard isAuthenticated else { return }

        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers

        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = MatchmakerDismisser.shared

        #if canImport(UIKit)
        presentFromTop(vc)
        #endif
    }

    // MARK: - Turn-Based Match Operations

    func endTurn(matchState: MultiplayerMatchState, nextParticipants: [GKTurnBasedParticipant],
                 timeout: TimeInterval = GKTurnTimeoutDefault) async throws {
        guard let match = currentMatch else { return }
        var state = matchState
        state.trimForTransfer()
        let data = try state.encoded()
        try await match.endTurn(withNextParticipants: nextParticipants, turnTimeout: timeout, match: data)
    }

    func saveCurrentTurn(matchState: MultiplayerMatchState) async throws {
        guard let match = currentMatch else { return }
        var state = matchState
        state.trimForTransfer()
        let data = try state.encoded()
        try await match.saveMergedMatch(data, withResolvedExchanges: [])
    }

    func endMatch(matchState: MultiplayerMatchState, outcome: GKTurnBasedMatch.Outcome) async throws {
        guard let match = currentMatch else { return }
        var state = matchState
        state.trimForTransfer()
        let data = try state.encoded()

        for participant in match.participants {
            participant.matchOutcome = outcome
        }
        try await match.endMatchInTurn(withMatch: data)
    }

    func quitMatch(outcome: GKTurnBasedMatch.Outcome, updatedState: MultiplayerMatchState? = nil) async throws {
        guard let match = currentMatch else { return }
        // Use updated state data if provided (e.g., with AI flag set), else fall back to server data
        let matchData: Data
        if let state = updatedState {
            var mutable = state
            mutable.trimForTransfer()
            matchData = (try? mutable.encoded()) ?? match.matchData ?? Data()
        } else {
            matchData = match.matchData ?? Data()
        }
        if match.currentParticipant?.player == GKLocalPlayer.local {
            let others = match.participants.filter { $0.player != GKLocalPlayer.local }
            try await match.participantQuitInTurn(
                with: outcome,
                nextParticipants: others,
                turnTimeout: GKTurnTimeoutDefault,
                match: matchData
            )
        } else {
            // Out-of-turn quit can't send data — save it first
            if updatedState != nil {
                try? await match.saveMergedMatch(matchData, withResolvedExchanges: [])
            }
            try await match.participantQuitOutOfTurn(with: outcome)
        }
    }

    func loadMatches() async throws -> [GKTurnBasedMatch] {
        return try await GKTurnBasedMatch.loadMatches()
    }

    func removeMatch(_ match: GKTurnBasedMatch) async throws {
        try await match.remove()
    }

    func loadMatchState() -> MultiplayerMatchState? {
        guard let match = currentMatch, let data = match.matchData, !data.isEmpty else { return nil }
        return try? MultiplayerMatchState.decoded(from: data)
    }
}

// MARK: - GKTurnBasedEventListener

extension GameCenterManager: GKLocalPlayerListener, GKTurnBasedEventListener {
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.turnBasedDelegate?.didReceiveTurn(match: match, didBecomeActive: didBecomeActive)
        }
    }

    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        DispatchQueue.main.async { [weak self] in
            self?.turnBasedDelegate?.matchEnded(match: match)
        }
    }

    func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        DispatchQueue.main.async { [weak self] in
            self?.turnBasedDelegate?.playerWantsToQuit(match: match, player: player)
        }
    }
}

// MARK: - Dismissal Handlers

class GameCenterDismisser: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismisser()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        #if canImport(UIKit)
        gameCenterViewController.dismiss(animated: true)
        #endif
    }
}

class MatchmakerDismisser: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
    static let shared = MatchmakerDismisser()

    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        #if canImport(UIKit)
        viewController.dismiss(animated: true)
        #endif
    }

    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
        #if canImport(UIKit)
        viewController.dismiss(animated: true)
        #endif
    }
}
