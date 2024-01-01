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
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class ArtworkModelItem: NSObject, TKMModelItem {
  let subjectID: Int64

  init(subjectID: Int64) {
    self.subjectID = subjectID
  }

  func cellClass() -> AnyClass {
    ArtworkModelCell.self
  }

  func cellReuseIdentifier() -> String {
    String(describing: cellClass())
  }

  @MainActor func createCell() -> TKMModelCell? {
    ArtworkModelCell(style: .default, reuseIdentifier: cellReuseIdentifier())
  }
}

@available(iOS 15.0, *)
@MainActor
class ArtworkModelCell: TKMModelCell {
  private var hostingController: UIHostingController<AnyView>?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateHostingController(with subjectID: Int64) {
    let screenHeight = UIScreen.main.bounds.height
    let desiredHeight = screenHeight * 0.34

    let artworkView: some View = VStack(alignment: .center, spacing: 20) {
      if let artworkURLString = ArtworkManager.artworkFullURL(subjectID: subjectID),
         let url = URL(string: artworkURLString) {
        GeometryReader { _ in
          AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
              ProgressView()
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
        }
        .frame(height: desiredHeight)
      } else {
        Text("Artwork not available for this subject ID.")
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(10)
    .shadow(radius: 5)
    .frame(height: desiredHeight)

    if hostingController == nil {
      hostingController = UIHostingController(rootView: AnyView(artworkView))
      if let hostedView = hostingController?.view {
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)

        // Define constraints for hostedView
        NSLayoutConstraint.activate([
          hostedView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
          hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
          hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
          hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
      }
    } else {
      hostingController?.rootView = AnyView(artworkView)
    }
  }

  override func update(with baseItem: TKMModelItem) {
    super.update(with: baseItem)
    guard let item = baseItem as? ArtworkModelItem else { return }
    updateHostingController(with: item.subjectID)
  }
}
