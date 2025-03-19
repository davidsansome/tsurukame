// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal enum SRSStages {
    internal static let apprentice = ImageAsset(name: "Apprentice")
    internal static let burned = ImageAsset(name: "Burned")
    internal static let enlightened = ImageAsset(name: "Enlightened")
    internal static let guru = ImageAsset(name: "Guru")
    internal static let master = ImageAsset(name: "Master")
  }
  internal static let add = ImageAsset(name: "add")
  internal static let back = ImageAsset(name: "back")
  internal static let baselineAccessTimeBlack24pt = ImageAsset(name: "baseline_access_time_black_24pt")
  internal static let baselineCancelBlack24pt = ImageAsset(name: "baseline_cancel_black_24pt")
  internal static let baselineCloudDownloadBlack24pt = ImageAsset(name: "baseline_cloud_download_black_24pt")
  internal static let baselineEditBlack24pt = ImageAsset(name: "baseline_edit_black_24pt")
  internal static let baselineMenuBlack24pt = ImageAsset(name: "baseline_menu_black_24pt")
  internal static let baselineNoteAddBlack24pt = ImageAsset(name: "baseline_note_add_black_24pt")
  internal static let baselineStopBlack24pt = ImageAsset(name: "baseline_stop_black_24pt")
  internal static let baselineVolumeUpBlack24pt = ImageAsset(name: "baseline_volume_up_black_24pt")
  internal static let checkmarkCircle = SymbolAsset(name: "checkmark.circle")
  internal enum FontPreviews {
    internal static let armedBanana = ImageAsset(name: "ArmedBanana")
    internal static let hinaMincho = ImageAsset(name: "Hina Mincho")
    internal static let hosofuwafont = ImageAsset(name: "Hosofuwafont")
    internal static let notoSerifJP = ImageAsset(name: "Noto Serif JP")
    internal static let sawarabiMincho = ImageAsset(name: "Sawarabi Mincho")
    internal static let dartsFont = ImageAsset(name: "darts font")
    internal static let nagayamaKai = ImageAsset(name: "nagayama_kai")
    internal static let santyoumeFont = ImageAsset(name: "santyoume-font")
  }
  internal static let forward = ImageAsset(name: "forward")
  internal static let goforwardPlus = SymbolAsset(name: "goforward.plus")
  internal static let icArrowForwardWhite = ImageAsset(name: "ic_arrow_forward_white")
  internal static let icSearchWhite = ImageAsset(name: "ic_search_white")
  internal static let icSettingsWhite = ImageAsset(name: "ic_settings_white")
  internal static let inbox = ImageAsset(name: "inbox")
  internal static let katakana = ImageAsset(name: "katakana")
  internal static let launchScreen = ImageAsset(name: "launch_screen")
  internal static let offline = ImageAsset(name: "offline")
  internal static let radical241 = ImageAsset(name: "radical-241")
  internal static let radical8761 = ImageAsset(name: "radical-8761")
  internal static let radical8762 = ImageAsset(name: "radical-8762")
  internal static let radical8763 = ImageAsset(name: "radical-8763")
  internal static let radical8764 = ImageAsset(name: "radical-8764")
  internal static let radical8765 = ImageAsset(name: "radical-8765")
  internal static let radical8766 = ImageAsset(name: "radical-8766")
  internal static let radical8767 = ImageAsset(name: "radical-8767")
  internal static let radical8768 = ImageAsset(name: "radical-8768")
  internal static let radical8769 = ImageAsset(name: "radical-8769")
  internal static let radical8770 = ImageAsset(name: "radical-8770")
  internal static let radical8771 = ImageAsset(name: "radical-8771")
  internal static let radical8772 = ImageAsset(name: "radical-8772")
  internal static let radical8773 = ImageAsset(name: "radical-8773")
  internal static let radical8774 = ImageAsset(name: "radical-8774")
  internal static let radical8775 = ImageAsset(name: "radical-8775")
  internal static let radical8776 = ImageAsset(name: "radical-8776")
  internal static let radical8777 = ImageAsset(name: "radical-8777")
  internal static let radical8778 = ImageAsset(name: "radical-8778")
  internal static let radical8779 = ImageAsset(name: "radical-8779")
  internal static let radical8780 = ImageAsset(name: "radical-8780")
  internal static let radical8781 = ImageAsset(name: "radical-8781")
  internal static let radical8782 = ImageAsset(name: "radical-8782")
  internal static let radical8783 = ImageAsset(name: "radical-8783")
  internal static let radical8784 = ImageAsset(name: "radical-8784")
  internal static let radical8785 = ImageAsset(name: "radical-8785")
  internal static let radical8786 = ImageAsset(name: "radical-8786")
  internal static let radical8787 = ImageAsset(name: "radical-8787")
  internal static let radical8788 = ImageAsset(name: "radical-8788")
  internal static let radical8789 = ImageAsset(name: "radical-8789")
  internal static let radical8790 = ImageAsset(name: "radical-8790")
  internal static let radical8791 = ImageAsset(name: "radical-8791")
  internal static let radical8792 = ImageAsset(name: "radical-8792")
  internal static let radical8793 = ImageAsset(name: "radical-8793")
  internal static let radical8794 = ImageAsset(name: "radical-8794")
  internal static let radical8795 = ImageAsset(name: "radical-8795")
  internal static let radical8796 = ImageAsset(name: "radical-8796")
  internal static let radical8797 = ImageAsset(name: "radical-8797")
  internal static let radical8798 = ImageAsset(name: "radical-8798")
  internal static let radical8799 = ImageAsset(name: "radical-8799")
  internal static let radical8819 = ImageAsset(name: "radical-8819")
  internal static let refresh = ImageAsset(name: "refresh")
  internal static let thumb = ImageAsset(name: "thumb")
  internal static let tick = ImageAsset(name: "tick")
  internal static let wanikani = ImageAsset(name: "wanikani")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

internal struct SymbolAsset {
  internal fileprivate(set) var name: String

  #if os(iOS) || os(tvOS) || os(watchOS)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  internal typealias Configuration = UIImage.SymbolConfiguration
  internal typealias Image = UIImage

  @available(iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }

  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  internal func image(with configuration: Configuration) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, with: configuration) else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: SymbolAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: SymbolAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: SymbolAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
