// Copyright 2021 David Sansome
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

import CommonCrypto
import Foundation
import os
import WatchConnectivity
#if os(watchOS)
  import ClockKit
#endif

typealias ClientDelegateCallback = (([String: Any]) -> Void)
typealias EpochTimeInt = Int64

class WatchConnectionServerDelegate: NSObject, WCSessionDelegate {
  func session(_: WCSession, activationDidCompleteWith _: WCSessionActivationState,
               error _: Error?) {}

  #if os(iOS)
    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_: WCSession) {}
  #endif
}

class WatchConnectionClientDelegate: NSObject, WCSessionDelegate {
  let callback: ClientDelegateCallback

  init(_ callback: @escaping ClientDelegateCallback) {
    self.callback = callback
  }

  func session(_: WCSession, activationDidCompleteWith _: WCSessionActivationState, error: Error?) {
    os_log("watch activationDidCompleteWith err=%{public}@", error?.localizedDescription ?? "none")
  }

  func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    #if os(watchOS)
      let server = CLKComplicationServer.sharedInstance()
      if let complications = server.activeComplications {
        for complication in complications {
          server.reloadTimeline(for: complication)
        }
      }
    #endif
    callback(userInfo)
  }

  #if os(iOS)
    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_: WCSession) {}
  #endif
}

@objc class WatchHelper: NSObject {
  public static let keyReviewCount = "reviewCount"
  public static let keyReviewNextHourCount = "reviewHrCount"
  public static let keyReviewUpcomingHourlyCounts = "reviewHourly"
  public static let keyLevelCurrent = "level"
  public static let keyLevelLearned = "levelLearn"
  public static let keyLevelTotal = "levelTotal"
  public static let keyLevelHalf = "levelHalf"
  public static let keyNextReviewAt = "nextReview"
  public static let keySentAt = "sent"

  @objc public static let sharedInstance = WatchHelper()
  private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
  let serverDelegate = WatchConnectionServerDelegate()
  var clientDelegate: WatchConnectionClientDelegate?
  var lastPacketSignature: String?
  var lastPacketSentAt: Date?
  let DuplicatePacketWindow = TimeInterval(30)

  override init() {
    super.init()
    #if os(iOS)
      startServerSession()
    #endif
  }

  #if os(iOS)
    @objc func startServerSession() {
      if let session = session {
        session.delegate = serverDelegate
        session.activate()
      }
    }

    @objc func updatedData(client: LocalCachingClient) {
      var halfLevel = false
      var assignmentsAtCurrentLevel = client.getAssignmentsAtUsersCurrentLevel()
      var learnedCount = assignmentsAtCurrentLevel.filter { (assignment) -> Bool in
        assignment.srsStage >= .guru1
      }.count

      // If the user is in the vocab and technically levels up but has 0
      // learned treat it as the prior level and set halfLevel=true
      if learnedCount == 0,
        let assignment = assignmentsAtCurrentLevel.first,
        assignment.level > 0 {
        halfLevel = true
        assignmentsAtCurrentLevel = client.getAssignments(level: Int(assignment.level) - 1)
        learnedCount = assignmentsAtCurrentLevel.filter { (assignment) -> Bool in
          assignment.srsStage >= .guru1
        }.count
      }

      let now = Int(Date().timeIntervalSince1970)
      let nextReviewEpoch: EpochTimeInt = client.getAllAssignments()
        .filter { a in a.isReviewStage && a.availableAt > now }
        .map { a in EpochTimeInt(a.availableAt) }
        .min() ?? 0

      let packet: [String: Any] = [
        WatchHelper.keyReviewCount: client.availableReviewCount,
        WatchHelper.keyReviewNextHourCount: client.upcomingReviews.first ?? 0,
        WatchHelper.keyReviewUpcomingHourlyCounts: client.upcomingReviews,
        WatchHelper.keyLevelCurrent: assignmentsAtCurrentLevel.first?.level ?? 0,
        WatchHelper.keyLevelTotal: assignmentsAtCurrentLevel.count,
        WatchHelper.keyLevelLearned: learnedCount,
        WatchHelper.keyLevelHalf: halfLevel,
        WatchHelper.keyNextReviewAt: nextReviewEpoch,
      ]

      if !shouldSendPacket(packet: packet) {
        NSLog("Skipping re-send of same watch data packet")
        return
      }

      if let session = session {
        var deadline = 0.0
        if session.activationState != .activated {
          // Session still initializing
          deadline += 0.5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + deadline) {
          let timestamp = [WatchHelper.keySentAt: EpochTimeInt(Date().timeIntervalSince1970)]
          session
            .transferCurrentComplicationUserInfo(packet
              .merging(timestamp, uniquingKeysWith: { current, _ in current }))
        }
      }
    }
  #endif

  func awaitMessages(callback: @escaping ClientDelegateCallback) {
    clientDelegate = WatchConnectionClientDelegate(callback)
    if let session = session {
      session.delegate = clientDelegate
      session.activate()
    }
  }

  func packetSignature(packet: [String: Any]) -> String {
    var signature = ""
    for key in packet.keys.sorted() {
      signature += "\(key):\(packet[key] ?? "nil"),"
    }
    return signature
  }

  func shouldSendPacket(packet: [String: Any]) -> Bool {
    guard let lastSignature = lastPacketSignature,
      let lastSent = lastPacketSentAt else {
      // The first one's always free.
      return true
    }

    let signature = packetSignature(packet: packet)
    let now = Date()
    if signature == lastSignature, now < (lastSent + DuplicatePacketWindow) {
      // Data unchanged and it has been sent within the window
      return false
    }

    lastPacketSignature = signature
    lastPacketSentAt = now

    return true
  }
}
