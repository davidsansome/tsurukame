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
      HStack(spacing: 14) {
        subjectBadge(context.state, size: 42)
        VStack(alignment: .leading, spacing: 4) {
          Text("Review session").font(.headline)
          Text("\(context.state.completed) of \(context.state.total) completed")
            .font(.subheadline)
        }
        Spacer()
        Text(context.state.subject).font(.title2.bold())
      }
      .padding()
      .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          subjectBadge(context.state, size: 36)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading) {
            Text(context.state.subjectType).font(.caption)
            Text(context.state.subject).font(.title3.bold())
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          ProgressView(value: Double(context.state.completed),
                       total: Double(max(context.state.total, 1)))
          Text("\(context.state.completed) of \(context.state.total) completed")
            .font(.caption)
        }
      } compactLeading: {
        subjectBadge(context.state, size: 22)
      } compactTrailing: {
        Text("\(context.state.completed)/\(context.state.total)").font(.caption2)
      } minimal: {
        subjectBadge(context.state, size: 20)
      }
      .keylineTint(Color(hex: context.state.color))
    }
  }

  private func subjectBadge(_ state: ReviewLiveActivityAttributes.ContentState,
                            size: CGFloat) -> some View {
    ZStack {
      Circle().fill(Color(hex: state.color))
      Text(state.subjectType == "Radical" ? "部" : state.subjectType == "Kanji" ? "漢" : "語")
        .font(.system(size: size * 0.52, weight: .bold))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}

private extension Color {
  init(hex: String) {
    let value = UInt64(hex, radix: 16) ?? 0
    self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255, opacity: 1)
  }
}
