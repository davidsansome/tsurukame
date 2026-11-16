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

import UIKit

#if targetEnvironment(macCatalyst)
  // Live Activities aren't available on Mac Catalyst.
  @available(iOS 16.2, *)
  @MainActor
  final class ReviewLiveActivityManager {
    static let shared = ReviewLiveActivityManager()

    func setProgress(completed _: Int, total _: Int) {}
    func end() async {}
  }
#else
  import ActivityKit

  /// Shows review progress on the Lock Screen and Dynamic Island. The activity is started with the
  /// first progress update of a session, but is only refreshed when the app leaves the foreground,
  /// since nobody can see it before then.
  @available(iOS 16.2, *)
  @MainActor
  final class ReviewLiveActivityManager {
    static let shared = ReviewLiveActivityManager()

    private var activity: Activity<ReviewLiveActivityAttributes>?
    private var state = ReviewLiveActivityAttributes.ContentState(completed: 0, total: 0)
    private var observer: NSObjectProtocol?

    func setProgress(completed: Int, total: Int) {
      guard Settings.reviewLiveActivity, total > 0 else { return }
      state = .init(completed: completed, total: total)
      if activity == nil { start() }
    }

    /// Ends every review activity, including ones left behind if the app was killed mid-session.
    func end() async {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
      activity = nil
      for activity in Activity<ReviewLiveActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }

    private func start() {
      guard ActivityAuthorizationInfo().areActivitiesEnabled,
            let activity = try? Activity.request(attributes: ReviewLiveActivityAttributes(),
                                                 content: ActivityContent(state: state,
                                                                          staleDate: nil))
      else { return }
      self.activity = activity
      observer = NotificationCenter.default
        .addObserver(forName: UIApplication.willResignActiveNotification, object: nil,
                     queue: .main) { [weak self] _ in
          Task { @MainActor in await self?.refresh() }
        }
    }

    private func refresh() async {
      // The setting was turned off during the session.
      guard Settings.reviewLiveActivity else { return await end() }
      await activity?.update(ActivityContent(state: state, staleDate: nil))
    }
  }
#endif
