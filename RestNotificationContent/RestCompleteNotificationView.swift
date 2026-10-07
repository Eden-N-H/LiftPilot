//  RestCompleteNotificationView.swift
//  Target membership: RestNotificationContent

import SwiftUI

/// The custom "rest over" view: what to lift next and exactly how to load the bar.
struct RestCompleteNotificationView: View {
    let payload: RestCompletePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(payload.exerciseName) · \(payload.setLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(WeightFormatting.kg(payload.weightKg)) × \(payload.reps)")
                    .font(.largeTitle.bold())
            }

            if let barWeight = payload.barWeightKg {
                BarLoadingDiagram(platesPerSideKg: payload.platesPerSideKg)
                Text(loadingDescription(barWeightKg: barWeight))
                    .font(.subheadline.bold())
            }

            if let lastSessionLine = payload.lastSessionLine {
                Label(lastSessionLine, systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let goalLine = payload.goalLine {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalLine)
                        .font(.footnote)
                    if let progress = payload.goalProgress {
                        ProgressView(value: progress)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadingDescription(barWeightKg: Double) -> String {
        if payload.platesPerSideKg.isEmpty {
            return "Empty bar (\(WeightFormatting.kg(barWeightKg)))"
        }
        let plates = payload.platesPerSideKg.map(WeightFormatting.number).joined(separator: " + ")
        return "Each side of the \(WeightFormatting.kg(barWeightKg)) bar: \(plates)"
    }
}

/// A side-on picture of one half of the bar, with plates drawn in the
/// standard competition colours and sized by weight.
struct BarLoadingDiagram: View {
    let platesPerSideKg: [Double]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            // Bar sleeve leading out from the lifter's hands.
            Rectangle()
                .fill(Color.gray)
                .frame(width: 36, height: 8)
            Rectangle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 6, height: 22)

            ForEach(Array(platesPerSideKg.enumerated()), id: \.offset) { _, plate in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colour(for: plate))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
                    )
                    .frame(width: Self.thickness(for: plate), height: Self.height(for: plate))
                    .overlay(
                        Text(WeightFormatting.number(plate))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Self.labelColour(for: plate))
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                    )
            }

            Rectangle()
                .fill(Color.gray)
                .frame(width: 24, height: 8)
            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Plates on each side: " + platesPerSideKg.map { "\(WeightFormatting.number($0)) kilograms" }.joined(separator: ", ")
        )
    }

    private static func colour(for plate: Double) -> Color {
        switch plate {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        case 2.5: return .black
        default: return Color(white: 0.75)
        }
    }

    private static func labelColour(for plate: Double) -> Color {
        switch plate {
        case 15, 5, 1.25: return .black
        default: return .white
        }
    }

    private static func height(for plate: Double) -> CGFloat {
        switch plate {
        case 15...: return 70
        case 10: return 60
        case 5: return 46
        case 2.5: return 36
        default: return 28
        }
    }

    private static func thickness(for plate: Double) -> CGFloat {
        switch plate {
        case 25: return 16
        case 20: return 14
        case 15: return 12
        case 10: return 10
        default: return 8
        }
    }
}
