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
  private var lastWindowHeight: CGFloat?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // Guard against accessing item when baseItem is nil
    guard baseItem != nil else { return }

    // Only update if window height has changed to avoid repeated relayouts
    // Use the window that contains this cell, not a random window from connectedScenes
    let windowHeight = window?.bounds.height ?? UIScreen.main.bounds.height

    if lastWindowHeight != windowHeight {
      lastWindowHeight = windowHeight
      updateHostingController(with: item.subjectID)
    }
  }

  private func updateHostingController(with subjectID: Int64) {
    // Use the window that contains this cell for accurate height calculation
    let windowHeight = window?.bounds.height ?? UIScreen.main.bounds.height
    let desiredHeight = windowHeight * 0.25

    let artworkView: some View = VStack(alignment: .center, spacing: 20) {
      if let artworkURLString = ArtworkManager.artworkFullURL(subjectID: subjectID),
         let url = URL(string: artworkURLString) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(height: desiredHeight)
          case let .success(image):
            image
              .resizable()
              .scaledToFit()
          case .failure:
            Text("Error loading image")
          @unknown default:
            EmptyView()
          }
        }
        .frame(maxHeight: desiredHeight)
      } else {
        Text("Artwork not available for this subject ID.")
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(10)
    .shadow(radius: 5)

    if hostingController == nil {
      hostingController = UIHostingController(rootView: AnyView(artworkView))

      if let hostedView = hostingController?.view {
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)

        // Define constraints for hostedView
        NSLayoutConstraint.activate([
          hostedView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
          hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
          hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
          hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
      }
    } else {
      hostingController?.rootView = AnyView(artworkView)
    }
  }

  override func update() {
    updateHostingController(with: item.subjectID)
  }
}
