//  WorkoutSession.swift

import Foundation

/// A single trip to the gym. In progress until the lifter finishes it.
struct WorkoutSession: Identifiable, Hashable {
    let id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var sets: [ExerciseSet]

    var isInProgress: Bool {
        finishedAt == nil
    }

    func sets(for exerciseID: UUID) -> [ExerciseSet] {
        sets
            .filter { $0.exerciseID == exerciseID }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    /// Exercise IDs in the order the lifter first trained them this session.
    var exerciseIDsInOrder: [UUID] {
        var seen = Set<UUID>()
        var ordered: [UUID] = []
        for set in sets.sorted(by: { $0.loggedAt < $1.loggedAt }) where !seen.contains(set.exerciseID) {
            seen.insert(set.exerciseID)
            ordered.append(set.exerciseID)
        }
        return ordered
    }
}
