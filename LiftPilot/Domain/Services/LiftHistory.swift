//  LiftHistory.swift

import Foundation

/// How the working sets of a goal lift went in one session, judged against the
/// 3 × 6–8 rep scheme.
enum WorkingSetOutcome: Hashable {
    /// Every working set reached 8 reps: time to add weight.
    case reachedTopOfRange
    /// Every working set reached at least 6 reps, but not all reached 8.
    case withinRange(lowestReps: Int)
    /// Fewer than 3 working sets, or a set fell short of 6 reps.
    case missed

    var isMissed: Bool {
        if case .missed = self { return true }
        return false
    }
}

/// One session's sets for a single lift.
struct LiftSessionRecord: Hashable {
    let sessionID: UUID
    let date: Date
    let sets: [ExerciseSet]

    /// The heaviest weight used this session is treated as the working weight;
    /// lighter sets are assumed to be warm-ups.
    var workingWeightKg: Double {
        sets.map(\.weightKg).max() ?? 0
    }

    var workingSets: [ExerciseSet] {
        let working = sets.filter { abs($0.weightKg - workingWeightKg) < 0.001 }
        return Array(working.prefix(ProgressionRules.workingSets))
    }

    var bestEstimatedMaxKg: Double? {
        sets.compactMap(\.estimatedMaxKg).max()
    }

    var bestSet: ExerciseSet? {
        sets.max { ($0.estimatedMaxKg ?? 0) < ($1.estimatedMaxKg ?? 0) }
    }

    var outcome: WorkingSetOutcome {
        let working = workingSets
        guard working.count >= ProgressionRules.workingSets,
              let lowestReps = working.map(\.reps).min() else {
            return .missed
        }
        if lowestReps >= ProgressionRules.maximumReps {
            return .reachedTopOfRange
        }
        if lowestReps >= ProgressionRules.minimumReps {
            return .withinRange(lowestReps: lowestReps)
        }
        return .missed
    }
}

enum LiftHistory {
    /// Groups a lift's logged sets into one record per session, oldest first.
    static func sessionRecords(from sets: [ExerciseSet]) -> [LiftSessionRecord] {
        let grouped = Dictionary(grouping: sets, by: \.sessionID)
        return grouped.map { sessionID, sessionSets in
            let ordered = sessionSets.sorted { $0.loggedAt < $1.loggedAt }
            return LiftSessionRecord(
                sessionID: sessionID,
                date: ordered.first?.loggedAt ?? Date.distantPast,
                sets: ordered
            )
        }
        .sorted { $0.date < $1.date }
    }

    /// The best estimated max across the given sets, if any qualify.
    static func bestEstimatedMaxKg(in sets: [ExerciseSet]) -> Double? {
        sets.compactMap(\.estimatedMaxKg).max()
    }
}
