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
class ArtworkModelItem: TableModelItem {
  let subjectID: Int64

  init(subjectID: Int64) {
    self.subjectID = subjectID
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: ArtworkModelCell.self)
  }
}

@available(iOS 15.0, *)
@MainActor
class ArtworkModelCell: TableModelCell {
  @TypedModelItem var item: ArtworkModelItem

  private var hostingController: UIHostingController<AnyView>?
  private var lastSize: CGSize = .zero

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let currentSize = contentView.bounds.size
    if currentSize != lastSize && currentSize.width > 0 {
      lastSize = currentSize
      updateHostingController(with: item.subjectID)
    }
  }

  private func updateHostingController(with subjectID: Int64) {
    var windowHeight: CGFloat

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
      // If we have a window, we're guaranteed to have valid height and width
      windowHeight = window.bounds.height
    } else {
      // Fallback to main screen's dimensions if the window scene or the window itself is not
      // available
      windowHeight = UIScreen.main.bounds.height
    }

    let containerWidth = contentView.bounds.width
    let desiredHeight = windowHeight * 0.30
    let artworkView: some View = VStack(alignment: .center, spacing: 0) {
      if let artworkURLString = ArtworkManager.artworkFullURL(subjectID: subjectID),
         let url = URL(string: artworkURLString) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(width: containerWidth, height: desiredHeight)
          case let .success(image):
            image
              .resizable()
              .scaledToFit()
              .contentShape(Rectangle())
              .onTapGesture {
                self.presentFullWindowArtwork(url: url)
              }
          case .failure:
            Text("Error loading image")
          @unknown default:
            EmptyView()
          }
        }
        .frame(maxWidth: containerWidth, maxHeight: desiredHeight)
      } else {
        Text("Artwork not available for this subject ID.")
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(10)
    .shadow(radius: 5)
    .frame(width: containerWidth, height: desiredHeight)

    if hostingController == nil {
      hostingController = UIHostingController(rootView: AnyView(artworkView))

      if let hostedView = hostingController?.view {
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)

        // Define constraints for hostedView
        NSLayoutConstraint.activate([
          hostedView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -20),
          hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 20),
          hostedView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
      }
    } else {
      hostingController?.rootView = AnyView(artworkView)
    }
  }

  private func presentFullWindowArtwork(url: URL) {
    guard let topViewController = topPresentedViewController() else { return }

    let viewerView = FullWindowArtworkView(url: url) { [weak topViewController] in
      topViewController?.dismiss(animated: true)
    }

    let modalController = UIHostingController(rootView: viewerView)
    modalController.modalPresentationStyle = .overFullScreen
    modalController.modalTransitionStyle = .crossDissolve
    modalController.view.backgroundColor = .clear

    topViewController.present(modalController, animated: true)
  }

  private func topPresentedViewController() -> UIViewController? {
    let windowScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

    let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
    var current = window?.rootViewController

    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  override func update() {
    updateHostingController(with: item.subjectID)
  }
}

@available(iOS 15.0, *)
private struct FullWindowArtworkView: View {
  let url: URL
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.92)
        .ignoresSafeArea()
        .onTapGesture {
          onDismiss()
        }

      AsyncImage(url: url) { phase in
        switch phase {
        case .empty:
          ProgressView()
            .tint(.white)
        case let .success(image):
          ZoomableArtworkScrollView(image: image, onSingleTapOutsideZoom: onDismiss)
            .ignoresSafeArea()
        case .failure:
          Text("Error loading image")
            .foregroundColor(.white)
        @unknown default:
          EmptyView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

@available(iOS 15.0, *)
private struct ZoomableArtworkScrollView: UIViewRepresentable {
  let image: Image
  let onSingleTapOutsideZoom: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onSingleTapOutsideZoom: onSingleTapOutsideZoom)
  }

  func makeUIView(context: Context) -> UIScrollView {
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 4.0
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.backgroundColor = .clear
    scrollView.bouncesZoom = true

    let hostingController = UIHostingController(rootView: AnyView(image
        .resizable()
        .scaledToFit()
    ))
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    scrollView.addSubview(hostingController.view)
    context.coordinator.hostedView = hostingController.view
    context.coordinator.hostingController = hostingController

    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor
        .constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      hostingController.view.trailingAnchor
        .constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      hostingController.view.bottomAnchor
        .constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      hostingController.view.widthAnchor
        .constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
      hostingController.view.heightAnchor
        .constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
    ])

    let singleTap = UITapGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.handleSingleTap(_:)))
    singleTap.numberOfTapsRequired = 1
    scrollView.addGestureRecognizer(singleTap)

    return scrollView
  }

  func updateUIView(_: UIScrollView, context: Context) {
    context.coordinator.onSingleTapOutsideZoom = onSingleTapOutsideZoom
    context.coordinator.hostingController?.rootView = AnyView(image
      .resizable()
      .scaledToFit())
  }

  @MainActor
  final class Coordinator: NSObject, UIScrollViewDelegate {
    var onSingleTapOutsideZoom: () -> Void
    weak var hostedView: UIView?
    var hostingController: UIHostingController<AnyView>?

    init(onSingleTapOutsideZoom: @escaping () -> Void) {
      self.onSingleTapOutsideZoom = onSingleTapOutsideZoom
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
      hostedView
    }

    @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
      guard let scrollView = gesture.view as? UIScrollView else { return }
      if scrollView.zoomScale <= 1.01 {
        onSingleTapOutsideZoom()
      } else {
        scrollView.setZoomScale(1.0, animated: true)
      }
    }
  }
}
