// Copyright David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ReviewLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ReviewLiveActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        Text("Reviews").font(.headline)
        ProgressView(value: Double(context.state.completed),
                     total: Double(max(context.state.total, 1)))
        Text("\(context.state.completed) of \(context.state.total) completed")
          .font(.subheadline)
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { Text("Reviews").font(.headline) }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.completed)/\(context.state.total)").font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          ProgressView(value: Double(context.state.completed),
                       total: Double(max(context.state.total, 1)))
        }
      } compactLeading: {
        Image(systemName: "checkmark.circle")
      } compactTrailing: {
        Text("\(context.state.completed)/\(context.state.total)").font(.caption2)
      } minimal: {
        Text("\(context.state.completed)").font(.caption2)
      }
    }
  }
}
