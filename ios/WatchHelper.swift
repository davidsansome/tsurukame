// Copyright 2019 David Sansome
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

import Foundation
import os
import WatchConnectivity

typealias ClientDelegateCallback = (([String: Any]) -> Void)

class WatchConnectionServerDelegate: NSObject, WCSessionDelegate {
  override init() {
    super.init()
  }

  func session(_: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {}

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
    os_log("MZS - activationDidCompleteWith err=%{public}@", error?.localizedDescription ?? "none")
  }

  func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    callback(userInfo)
  }

  #if os(iOS)
    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_: WCSession) {}
  #endif
}

@objc class WatchHelper: NSObject {
  public static let KeyReviewCount = "reviewCount"

  private static let _sharedInstance = WatchHelper()
  private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
  let serverDelegate = WatchConnectionServerDelegate()
  var clientDelegate: WatchConnectionClientDelegate?

  override init() {
    super.init()
    #if os(iOS)
      startServerSession()
    #endif
  }

  @objc static func sharedInstance() -> WatchHelper {
    return _sharedInstance
  }

  #if os(iOS)
    @objc func startServerSession() {
      if let session = session {
        session.delegate = serverDelegate
        session.activate()
      }
    }

    @objc func sendReviewCount(_ reviewCount: Int32) {
      if let session = session, session.isPaired {
        let packet = [WatchHelper.KeyReviewCount: reviewCount]
        // session.transferUserInfo(packet)
        session.transferCurrentComplicationUserInfo(packet)
      }
    }
  #endif

  func awaitMessages(callback: @escaping ClientDelegateCallback) {
    clientDelegate = WatchConnectionClientDelegate(callback)
    if let session = session {
      session.delegate = clientDelegate
      session.activate()
      os_log("MZS - activated listener")
    }
  }
}
