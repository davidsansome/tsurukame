// Copyright 2023 David Sansome
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

private let kMargin: CGFloat = 8.0

class VacationModeView: UIView {
  @IBOutlet private var container: UIView!
  @IBOutlet var gradient: GradientView!
  @IBOutlet private var label: UILabel!
  @IBOutlet private var detail: UILabel!

  private weak var gradientLayer: CAGradientLayer!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    let nib = UINib(nibName: "VacationModeView", bundle: Bundle(for: type(of: self)))
    nib.instantiate(withOwner: self, options: nil)

    addSubview(container)
    addConstraints([
      container.leftAnchor.constraint(equalTo: leftAnchor),
      container.rightAnchor.constraint(equalTo: rightAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor),
      container.topAnchor.constraint(equalTo: topAnchor),
    ])
  }

  override func didMoveToSuperview() {
    backgroundColor = .clear

    updateGradientColors()

    // Add shadows to things in the vacation view.
    TKMStyle.addShadowToView(label, offset: 1.0, opacity: 0.4, radius: 2.0)
  }

  func updateGradientColors() {
    gradient.colors = TKMStyle.kanjiGradient
  }

  override func traitCollectionDidChange(_: UITraitCollection?) {
    updateGradientColors()
  }
}
