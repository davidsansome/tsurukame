// Copyright 2024 David Sansome
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

class FullRefreshOverlayView: UIView {
  @IBOutlet var containerView: UIVisualEffectView!

  init?(window: UIWindow) {
    super.init(frame: window.frame)

    let nib = UINib(nibName: "FullRefreshOverlayView", bundle: Bundle(for: type(of: self)))
    nib.instantiate(withOwner: self, options: nil)

    // Add the container to ourself and add ourself to the window.
    addSubview(containerView)
    window.addSubview(self)

    // Fade in.
    alpha = 0.0
    UIView.animate(withDuration: 0.3) {
      self.alpha = 1.0
    }
  }

  override func layoutSubviews() {
    containerView.frame = frame
  }

  func hide() {
    UIView.animate(withDuration: 0.3) {
      self.alpha = 0.0
    } completion: { _ in
      self.removeFromSuperview()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
