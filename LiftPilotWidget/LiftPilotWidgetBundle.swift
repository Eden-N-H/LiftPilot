//
//  LiftPilotWidgetBundle.swift
//  LiftPilotWidget
//
//  Created by Eden Hallett on 7/10/2026.
//

import WidgetKit
import SwiftUI

@main
struct LiftPilotWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiftPilotWidget()
        LiftPilotWidgetControl()
        LiftPilotWidgetLiveActivity()
    }
}
