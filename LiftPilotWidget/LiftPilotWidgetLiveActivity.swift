//
//  LiftPilotWidgetLiveActivity.swift
//  LiftPilotWidget
//
//  Created by Eden Hallett on 7/10/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiftPilotWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiftPilotWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftPilotWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiftPilotWidgetAttributes {
    fileprivate static var preview: LiftPilotWidgetAttributes {
        LiftPilotWidgetAttributes(name: "World")
    }
}

extension LiftPilotWidgetAttributes.ContentState {
    fileprivate static var smiley: LiftPilotWidgetAttributes.ContentState {
        LiftPilotWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiftPilotWidgetAttributes.ContentState {
         LiftPilotWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiftPilotWidgetAttributes.preview) {
   LiftPilotWidgetLiveActivity()
} contentStates: {
    LiftPilotWidgetAttributes.ContentState.smiley
    LiftPilotWidgetAttributes.ContentState.starEyes
}
