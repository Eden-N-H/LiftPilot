//  CoreDataTrainingLogRepository.swift

import CoreData

/// Core Data implementation of the training log. This is the only type in the
/// app that knows about managed objects; everything it returns is a plain
/// domain struct.
@MainActor
final class CoreDataTrainingLogRepository: TrainingLogRepository {
    private let context: NSManagedObjectContext

    init(container: NSPersistentContainer) {
        self.context = container.viewContext
        seedExerciseCatalogueIfNeeded()
    }

    convenience init() {
        self.init(container: PersistenceController.shared.container)
    }

    // MARK: - Exercises

    func fetchExercises() throws -> [Exercise] {
        let request = NSFetchRequest<ExerciseEntity>(entityName: "ExerciseEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let entities = try fetch(request)
        let exercises = entities.compactMap(Self.exercise(from:))
        // Main barbell lifts first, then accessories.
        return exercises.filter(\.isMainBarbellLift) + exercises.filter { !$0.isMainBarbellLift }
    }

    func fetchExercise(id: UUID) throws -> Exercise? {
        try exerciseEntity(id: id).flatMap(Self.exercise(from:))
    }

    // MARK: - Workout sessions

    func fetchInProgressSession() throws -> WorkoutSession? {
        let request = NSFetchRequest<WorkoutSessionEntity>(entityName: "WorkoutSessionEntity")
        request.predicate = NSPredicate(format: "finishedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = 1
        return try fetch(request).first.flatMap(Self.session(from:))
    }

    func fetchSession(id: UUID) throws -> WorkoutSession? {
        try sessionEntity(id: id).flatMap(Self.session(from:))
    }

    func fetchRecentCompletedSessions(limit: Int) throws -> [WorkoutSession] {
        let request = NSFetchRequest<WorkoutSessionEntity>(entityName: "WorkoutSessionEntity")
        request.predicate = NSPredicate(format: "finishedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = limit
        return try fetch(request).compactMap(Self.session(from:))
    }

    @discardableResult
    func startSession(at date: Date) throws -> WorkoutSession {
        let entity = WorkoutSessionEntity(context: context)
        entity.id = UUID()
        entity.startedAt = date
        entity.finishedAt = nil
        try save()
        guard let session = Self.session(from: entity) else {
            throw RepositoryError.recordNotFound
        }
        return session
    }

    func markSessionFinished(id: UUID, at date: Date) throws {
        guard let entity = try sessionEntity(id: id) else {
            throw RepositoryError.recordNotFound
        }
        entity.finishedAt = date
        try save()
    }

    func deleteSession(id: UUID) throws {
        guard let entity = try sessionEntity(id: id) else {
            throw RepositoryError.recordNotFound
        }
        context.delete(entity)
        try save()
    }

    // MARK: - Sets

    @discardableResult
    func addSet(_ set: ExerciseSet) throws -> ExerciseSet {
        guard let session = try sessionEntity(id: set.sessionID),
              let exercise = try exerciseEntity(id: set.exerciseID) else {
            throw RepositoryError.recordNotFound
        }
        let entity = ExerciseSetEntity(context: context)
        entity.id = set.id
        entity.weightKg = set.weightKg
        entity.reps = Int16(clamping: set.reps)
        entity.loggedAt = set.loggedAt
        entity.session = session
        entity.exercise = exercise
        try save()
        return set
    }

    func deleteSet(id: UUID) throws {
        let request = NSFetchRequest<ExerciseSetEntity>(entityName: "ExerciseSetEntity")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        guard let entity = try fetch(request).first else {
            throw RepositoryError.recordNotFound
        }
        context.delete(entity)
        try save()
    }

    /// Domain query: every set of one lift from finished workouts since a date.
    /// Drives prescriptions, estimated max trends and goal forecasts.
    func fetchCompletedSets(for exerciseID: UUID, since date: Date?) throws -> [ExerciseSet] {
        let request = NSFetchRequest<ExerciseSetEntity>(entityName: "ExerciseSetEntity")
        var predicates = [
            NSPredicate(format: "exercise.id == %@", exerciseID as NSUUID),
            NSPredicate(format: "session.finishedAt != nil")
        ]
        if let date {
            predicates.append(NSPredicate(format: "session.startedAt >= %@", date as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "loggedAt", ascending: true)]
        return try fetch(request).compactMap(Self.exerciseSet(from:))
    }

    // MARK: - Lift goals

    func fetchActiveGoals() throws -> [LiftGoal] {
        let request = NSFetchRequest<LiftGoalEntity>(entityName: "LiftGoalEntity")
        request.predicate = NSPredicate(format: "status == %@", LiftGoalStatus.active.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "setAt", ascending: true)]
        return try fetch(request).compactMap(Self.goal(from:))
    }

    func fetchActiveGoal(for exerciseID: UUID) throws -> LiftGoal? {
        let request = NSFetchRequest<LiftGoalEntity>(entityName: "LiftGoalEntity")
        request.predicate = NSPredicate(
            format: "exercise.id == %@ AND status == %@",
            exerciseID as NSUUID,
            LiftGoalStatus.active.rawValue
        )
        request.fetchLimit = 1
        return try fetch(request).first.flatMap(Self.goal(from:))
    }

    /// Inserts a new goal or updates an existing one with the same ID.
    func saveGoal(_ goal: LiftGoal) throws {
        let request = NSFetchRequest<LiftGoalEntity>(entityName: "LiftGoalEntity")
        request.predicate = NSPredicate(format: "id == %@", goal.id as NSUUID)
        request.fetchLimit = 1

        let entity = try fetch(request).first ?? LiftGoalEntity(context: context)
        guard let exercise = try exerciseEntity(id: goal.exerciseID) else {
            throw RepositoryError.recordNotFound
        }
        entity.id = goal.id
        entity.exercise = exercise
        entity.targetWeightKg = goal.targetWeightKg
        entity.startingEstimatedMaxKg = goal.startingEstimatedMaxKg
        entity.sessionsPerWeek = Int16(clamping: goal.sessionsPerWeek)
        entity.setAt = goal.setAt
        entity.plannedCompletionDate = goal.plannedCompletionDate
        entity.status = goal.status.rawValue
        entity.achievedAt = goal.achievedAt
        try save()
    }

    // MARK: - Seeding

    private func seedExerciseCatalogueIfNeeded() {
        let request = NSFetchRequest<ExerciseEntity>(entityName: "ExerciseEntity")
        let existingCount = (try? context.count(for: request)) ?? 0
        guard existingCount == 0 else { return }

        for entry in ExerciseCatalogue.standardExercises {
            let entity = ExerciseEntity(context: context)
            entity.id = UUID()
            entity.name = entry.name
            entity.category = entry.category.rawValue
            entity.progressionIncrementKg = entry.progressionIncrementKg
        }
        try? save()
    }

    // MARK: - Helpers

    private func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        do {
            return try context.fetch(request)
        } catch {
            throw RepositoryError.fetchFailed(error.localizedDescription)
        }
    }

    private func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }

    private func exerciseEntity(id: UUID) throws -> ExerciseEntity? {
        let request = NSFetchRequest<ExerciseEntity>(entityName: "ExerciseEntity")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    private func sessionEntity(id: UUID) throws -> WorkoutSessionEntity? {
        let request = NSFetchRequest<WorkoutSessionEntity>(entityName: "WorkoutSessionEntity")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    // MARK: - Mapping (managed objects -> domain structs)

    private static func exercise(from entity: ExerciseEntity) -> Exercise? {
        guard let id = entity.id,
              let name = entity.name,
              let category = ExerciseCategory(rawValue: entity.category ?? "") else {
            return nil
        }
        return Exercise(
            id: id,
            name: name,
            category: category,
            progressionIncrementKg: entity.progressionIncrementKg
        )
    }

    private static func exerciseSet(from entity: ExerciseSetEntity) -> ExerciseSet? {
        guard let id = entity.id,
              let sessionID = entity.session?.id,
              let exerciseID = entity.exercise?.id,
              let loggedAt = entity.loggedAt else {
            return nil
        }
        return ExerciseSet(
            id: id,
            sessionID: sessionID,
            exerciseID: exerciseID,
            weightKg: entity.weightKg,
            reps: Int(entity.reps),
            loggedAt: loggedAt
        )
    }

    private static func session(from entity: WorkoutSessionEntity) -> WorkoutSession? {
        guard let id = entity.id, let startedAt = entity.startedAt else {
            return nil
        }
        let setEntities = (entity.sets as? Set<ExerciseSetEntity>) ?? []
        let sets = setEntities
            .compactMap(exerciseSet(from:))
            .sorted { $0.loggedAt < $1.loggedAt }
        return WorkoutSession(id: id, startedAt: startedAt, finishedAt: entity.finishedAt, sets: sets)
    }

    private static func goal(from entity: LiftGoalEntity) -> LiftGoal? {
        guard let id = entity.id,
              let exerciseID = entity.exercise?.id,
              let setAt = entity.setAt,
              let plannedCompletionDate = entity.plannedCompletionDate,
              let status = LiftGoalStatus(rawValue: entity.status ?? "") else {
            return nil
        }
        return LiftGoal(
            id: id,
            exerciseID: exerciseID,
            targetWeightKg: entity.targetWeightKg,
            startingEstimatedMaxKg: entity.startingEstimatedMaxKg,
            sessionsPerWeek: Int(entity.sessionsPerWeek),
            setAt: setAt,
            plannedCompletionDate: plannedCompletionDate,
            status: status,
            achievedAt: entity.achievedAt
        )
    }
}
