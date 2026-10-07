//  GoalForecast.swift

import Foundation

/// Where the lifter stands against their goal, based on their real training.
enum GoalForecastStatus: Hashable {
    case achieved(on: Date)
    case readyToTest
    case notEnoughData(sessionsLogged: Int, sessionsNeeded: Int, daysNeeded: Int)
    case stalled
    case onTrack(forecastDate: Date)
    case aheadOfPlan(forecastDate: Date, daysAhead: Int)
    case behindPlan(forecastDate: Date, daysBehind: Int)
}

struct GoalForecast: Hashable {
    let goalID: UUID
    let targetWeightKg: Double
    let currentEstimatedMaxKg: Double
    let plannedCompletionDate: Date
    let status: GoalForecastStatus

    var progressFraction: Double {
        guard targetWeightKg > 0 else { return 0 }
        return min(1, max(0, currentEstimatedMaxKg / targetWeightKg))
    }

    /// The date the forecast predicts, when there is one.
    var forecastDate: Date? {
        switch status {
        case .onTrack(let date), .aheadOfPlan(let date, _), .behindPlan(let date, _):
            return date
        default:
            return nil
        }
    }

    /// One short line suitable for a card or widget.
    var headline: String {
        switch status {
        case .achieved:
            return "Goal reached"
        case .readyToTest:
            return "Ready to test"
        case .notEnoughData:
            return "Building your forecast"
        case .stalled:
            return "Progress has stalled"
        case .onTrack(let date):
            return "On track for \(Self.monthYear(date))"
        case .aheadOfPlan(let date, _):
            return "Ahead of plan: \(Self.monthYear(date))"
        case .behindPlan(let date, _):
            return "Behind plan: \(Self.monthYear(date))"
        }
    }

    /// A fuller, plain-language explanation for the Lift Detail screen.
    var explanation: String {
        switch status {
        case .achieved(let date):
            return "You lifted your target on \(date.formatted(date: .abbreviated, time: .omitted)). Time to set a new goal."
        case .readyToTest:
            return "Your estimated max has reached your target. On a day you feel fresh, try a single at \(WeightFormatting.kg(targetWeightKg)) with a spotter."
        case .notEnoughData(let logged, let needed, let days):
            return "LiftPilot needs at least \(needed) sessions across \(days) days to forecast honestly. You've logged \(logged) recent session\(logged == 1 ? "" : "s") on this lift. Keep following the plan."
        case .stalled:
            return "Your estimated max hasn't risen over your recent sessions. If you miss reps twice in a row, LiftPilot will lower the weight so you can build back up."
        case .onTrack(let date):
            return "At your current rate you'll reach \(WeightFormatting.kg(targetWeightKg)) around \(Self.dayMonth(date)), in line with your plan."
        case .aheadOfPlan(let date, let days):
            return "At your current rate you'll reach \(WeightFormatting.kg(targetWeightKg)) around \(Self.dayMonth(date)), about \(Self.weeks(days)) ahead of plan."
        case .behindPlan(let date, let days):
            return "At your current rate you'll reach \(WeightFormatting.kg(targetWeightKg)) around \(Self.dayMonth(date)), about \(Self.weeks(days)) behind plan. Forecasts assume steady progress, so treat this as an estimate."
        }
    }

    private static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    private static func weeks(_ days: Int) -> String {
        let weeks = max(1, Int((Double(days) / 7).rounded()))
        return "\(weeks) week\(weeks == 1 ? "" : "s")"
    }
}
