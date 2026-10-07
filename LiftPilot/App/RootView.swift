//  RootView.swift

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            TodayView(dependencies: dependencies)
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

            LiftsView(dependencies: dependencies)
                .tabItem { Label("Lifts", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView(dependencies: dependencies)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
