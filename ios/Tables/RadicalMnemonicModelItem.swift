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

import Foundation
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class RadicalMnemonicModelItem: TableModelItem {
  let subjectId: Int64

  init(subjectId: Int64) {
    self.subjectId = subjectId
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: RadicalMnemonicModelCell.self)
  }
}

@available(iOS 15.0, *)
@MainActor
class RadicalMnemonicModelCell: TableModelCell {
  @TypedModelItem var item: RadicalMnemonicModelItem

  private static let artworkInset: CGFloat = 10
  private var hostingController: UIHostingController<AnyView>?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateHostingController(subjectId: Int64) {
    let url = ArtworkManager.radicalFullURL(subjectId: subjectId).flatMap { URL(string: $0) }
    let maxRasterWidth = RadicalMnemonicImages.rasterSize.width

    let artworkView: some View = VStack(alignment: .center, spacing: 0) {
      if let url {
        SVGAsyncImage(url: url, subjectId: subjectId)
          .aspectRatio(1, contentMode: .fit)
          .id(url) // `.id(url)` resets the view state when the cell is reused for another subject.
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
    .cornerRadius(10)
    .shadow(radius: 5)

    if hostingController == nil {
      hostingController = UIHostingController(rootView: AnyView(artworkView))

      if let hostedView = hostingController?.view {
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)

        let fillWidth = hostedView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
        fillWidth.priority = UILayoutPriority(999)
        let bottom = hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,
                                                        constant: Self.artworkInset)
        bottom.priority = UILayoutPriority(999)

        // NOTE: the negative top and positive bottom constants are intentional. They push the
        // card 10 pt past the contentView edges to cancel the extra vertical spacing around it,
        // so the artwork sits flush within its section. Do not "fix" the signs of artworkInset.
        NSLayoutConstraint.activate([
          hostedView.topAnchor.constraint(equalTo: contentView.topAnchor,
                                          constant: -Self.artworkInset),
          bottom,
          hostedView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
          fillWidth,
          hostedView.widthAnchor.constraint(lessThanOrEqualToConstant: maxRasterWidth),
          hostedView.heightAnchor.constraint(equalTo: hostedView.widthAnchor),
        ])
      }
      attachHostingControllerIfNeeded()
    } else {
      hostingController?.rootView = AnyView(artworkView)
    }
  }

  override func update() {
    updateHostingController(subjectId: item.subjectId)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      attachHostingControllerIfNeeded()
    } else {
      detachHostingController()
    }
  }

  private func attachHostingControllerIfNeeded() {
    guard let controller = hostingController,
          controller.parent == nil,
          let parent = parentViewController else {
      return
    }
    parent.addChild(controller)
    controller.didMove(toParent: parent)
  }

  private func detachHostingController() {
    guard let controller = hostingController, controller.parent != nil else {
      return
    }
    controller.willMove(toParent: nil)
    controller.removeFromParent()
  }
}

private extension UIView {
  var parentViewController: UIViewController? {
    var responder: UIResponder? = self
    while let next = responder?.next {
      if let controller = next as? UIViewController {
        return controller
      }
      responder = next
    }
    return nil
  }
}

// MARK: - SVGAsyncImage

@available(iOS 15.0, *)
struct SVGAsyncImage: View {
  let url: URL
  let subjectId: Int64

  @State private var image: UIImage?
  @State private var failed = false

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
      } else if failed {
        Text("Error loading image")
      } else {
        ProgressView()
      }
    }
    .task(id: url) {
      await loadRadicalSvg()
    }
  }

  private func loadRadicalSvg() async {
    let startTime = CFAbsoluteTimeGetCurrent()
    failed = false
    image = nil
    do {
      // The loader checks the cache, shares in-flight requests and stores the result.
      let rendered = try await SVGImageLoader.shared.image(from: url, subjectId: subjectId)
      // The shared load is not cancelled with this task, so do not apply a stale result.
      try Task.checkCancellation()
      image = rendered
      NSLog("[RadicalMnemonic] loadRadicalSvg: image applied url=\(url.absoluteString)")
    } catch {
      if error is CancellationError || (error as? URLError)?.code == .cancelled {
        NSLog("[RadicalMnemonic] loadRadicalSvg: load cancelled url=\(url.absoluteString)")
        return
      }
      NSLog("[RadicalMnemonic] loadRadicalSvg SVG loading error: \(error)")
      failed = true
    }

    let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
    NSLog("[RadicalMnemonic] loadRadicalSvg: finished in \(elapsedMs) ms")
  }
}
