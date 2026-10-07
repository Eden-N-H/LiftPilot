//  ForecastGoalAchievementUseCase.swift

import Foundation

/// Forecasts when the lifter will reach their goal from their real training,
/// and compares that with the planned timeline.
///
/// Business rules:
/// - Uses the best estimated max from each session over the last 6 weeks.
/// - Needs at least 4 sessions spread over at least 14 days before forecasting
///   a date; with less data the forecast would be guesswork.
/// - A trend gaining less than 0.25 kg a week counts as stalled, and no date is shown.
/// - Within 7 days of the planned date counts as on track.
/// - Once the estimated max reaches the target, the goal is ready to test.
@MainActor
struct ForecastGoalAchievementUseCase {
    private let repository: TrainingLogRepository
    private let calendar: Calendar

    init(repository: TrainingLogRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    func execute(for goal: LiftGoal, asOf now: Date = Date()) throws -> GoalForecast {
        if goal.status == .achieved {
            return GoalForecast(
                goalID: goal.id,
                targetWeightKg: goal.targetWeightKg,
                currentEstimatedMaxKg: goal.targetWeightKg,
                plannedCompletionDate: goal.plannedCompletionDate,
                status: .achieved(on: goal.achievedAt ?? now)
            )
        }

        let windowStart = calendar.date(byAdding: .day, value: -ProgressionRules.forecastWindowDays, to: now) ?? now
        let sets: [ExerciseSet]
        do {
            sets = try repository.fetchCompletedSets(for: goal.exerciseID, since: windowStart)
        } catch {
            throw ForecastGoalAchievementError.historyUnavailable
        }

        let points: [(date: Date, estimatedMaxKg: Double)] = LiftHistory
            .sessionRecords(from: sets)
            .compactMap { record -> (date: Date, estimatedMaxKg: Double)? in
                guard let best = record.bestEstimatedMaxKg else { return nil }
                return (date: record.date, estimatedMaxKg: best)
            }

        let recentBest = points.map(\.estimatedMaxKg).max() ?? 0
        let currentEstimatedMax = max(goal.startingEstimatedMaxKg, recentBest)

        func forecast(_ status: GoalForecastStatus) -> GoalForecast {
            GoalForecast(
                goalID: goal.id,
                targetWeightKg: goal.targetWeightKg,
                currentEstimatedMaxKg: currentEstimatedMax,
                plannedCompletionDate: goal.plannedCompletionDate,
                status: status
            )
        }

        if currentEstimatedMax >= goal.targetWeightKg {
            return forecast(.readyToTest)
        }

        guard let first = points.first, let last = points.last else {
            return forecast(.notEnoughData(
                sessionsLogged: 0,
                sessionsNeeded: ProgressionRules.minimumSessionsForForecast,
                daysNeeded: ProgressionRules.minimumDaysForForecast
            ))
        }

        let spanDays = last.date.timeIntervalSince(first.date) / 86_400
        guard points.count >= ProgressionRules.minimumSessionsForForecast,
              spanDays >= Double(ProgressionRules.minimumDaysForForecast) else {
            return forecast(.notEnoughData(
                sessionsLogged: points.count,
                sessionsNeeded: ProgressionRules.minimumSessionsForForecast,
                daysNeeded: ProgressionRules.minimumDaysForForecast
            ))
        }

        // Least-squares trend line: estimated max (kg) against days since the first session.
        let xs = points.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = points.map(\.estimatedMaxKg)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var covariance = 0.0
        var varianceX = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            varianceX += (x - meanX) * (x - meanX)
        }
        guard varianceX > 0 else {
            return forecast(.stalled)
        }

        let gainPerDay = covariance / varianceX
        guard gainPerDay * 7 >= ProgressionRules.minimumWeeklyGainKg else {
            return forecast(.stalled)
        }

        let trendAtLastSession = meanY + gainPerDay * (xs.last! - meanX)
        let remainingKg = max(0, goal.targetWeightKg - trendAtLastSession)
        let daysToGo = Int((remainingKg / gainPerDay).rounded(.up))
        let forecastDate = calendar.date(byAdding: .day, value: daysToGo, to: last.date) ?? last.date

        let daysFromPlan = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: goal.plannedCompletionDate),
            to: calendar.startOfDay(for: forecastDate)
        ).day ?? 0

        if abs(daysFromPlan) <= ProgressionRules.onTrackToleranceDays {
            return forecast(.onTrack(forecastDate: forecastDate))
        } else if daysFromPlan < 0 {
            return forecast(.aheadOfPlan(forecastDate: forecastDate, daysAhead: -daysFromPlan))
        } else {
            return forecast(.behindPlan(forecastDate: forecastDate, daysBehind: daysFromPlan))
        }
    }
}

enum ForecastGoalAchievementError: LocalizedError {
    case historyUnavailable

    var errorDescription: String? {
        switch self {
        case .historyUnavailable:
            return "Your training history couldn't be loaded, so we can't forecast this goal right now. Please try again."
        }
    }
}
