// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length implicit_return

// MARK: - Storyboard Scenes

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
internal enum StoryboardScene {
  internal enum AppSettings: StoryboardType {
    internal static let storyboardName = "AppSettings"

    internal static let initialScene = InitialSceneType<Tsurukame.AppSettingsViewController>(storyboard: Self.self)
  }
  internal enum LaunchScreen: StoryboardType {
    internal static let storyboardName = "LaunchScreen"

    internal static let initialScene = InitialSceneType<UIKit.UIViewController>(storyboard: Self.self)
  }
  internal enum LessonOrder: StoryboardType {
    internal static let storyboardName = "LessonOrder"

    internal static let initialScene = InitialSceneType<Tsurukame.LessonOrderViewController>(storyboard: Self.self)

    internal static let uiTableViewControllerB5QPHHTQ = SceneType<Tsurukame.LessonOrderViewController>(storyboard: Self.self, identifier: "UITableViewController-B5Q-PH-hTQ")
  }
  internal enum LessonPicker: StoryboardType {
    internal static let storyboardName = "LessonPicker"

    internal static let initialScene = InitialSceneType<Tsurukame.LessonPickerViewController>(storyboard: Self.self)
  }
  internal enum LessonSettings: StoryboardType {
    internal static let storyboardName = "LessonSettings"

    internal static let initialScene = InitialSceneType<Tsurukame.LessonSettingsViewController>(storyboard: Self.self)
  }
  internal enum Lessons: StoryboardType {
    internal static let storyboardName = "Lessons"

    internal static let initialScene = InitialSceneType<Tsurukame.LessonsViewController>(storyboard: Self.self)
  }
  internal enum Login: StoryboardType {
    internal static let storyboardName = "Login"

    internal static let initialScene = InitialSceneType<Tsurukame.LoginViewController>(storyboard: Self.self)
  }
  internal enum Main: StoryboardType {
    internal static let storyboardName = "Main"

    internal static let initialScene = InitialSceneType<Tsurukame.MainViewController>(storyboard: Self.self)
  }
  internal enum Navigation: StoryboardType {
    internal static let storyboardName = "Navigation"

    internal static let initialScene = InitialSceneType<Tsurukame.NavigationController>(storyboard: Self.self)
  }
  internal enum OfflineAudio: StoryboardType {
    internal static let storyboardName = "OfflineAudio"

    internal static let initialScene = InitialSceneType<Tsurukame.OfflineAudioViewController>(storyboard: Self.self)
  }
  internal enum Review: StoryboardType {
    internal static let storyboardName = "Review"

    internal static let initialScene = InitialSceneType<Tsurukame.ReviewViewController>(storyboard: Self.self)
  }
  internal enum ReviewContainer: StoryboardType {
    internal static let storyboardName = "ReviewContainer"

    internal static let initialScene = InitialSceneType<Tsurukame.ReviewContainerViewController>(storyboard: Self.self)
  }
  internal enum ReviewSettings: StoryboardType {
    internal static let storyboardName = "ReviewSettings"

    internal static let initialScene = InitialSceneType<Tsurukame.ReviewSettingsViewController>(storyboard: Self.self)
  }
  internal enum ReviewSummary: StoryboardType {
    internal static let storyboardName = "ReviewSummary"

    internal static let initialScene = InitialSceneType<Tsurukame.ReviewSummaryViewController>(storyboard: Self.self)
  }
  internal enum SearchResult: StoryboardType {
    internal static let storyboardName = "SearchResult"

    internal static let initialScene = InitialSceneType<Tsurukame.SearchResultViewController>(storyboard: Self.self)
  }
  internal enum SelectFonts: StoryboardType {
    internal static let storyboardName = "SelectFonts"

    internal static let initialScene = InitialSceneType<Tsurukame.FontsViewController>(storyboard: Self.self)
  }
  internal enum Settings: StoryboardType {
    internal static let storyboardName = "Settings"

    internal static let initialScene = InitialSceneType<Tsurukame.SettingsViewController>(storyboard: Self.self)
  }
  internal enum SubjectCatalogue: StoryboardType {
    internal static let storyboardName = "SubjectCatalogue"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectCatalogueViewController>(storyboard: Self.self)
  }
  internal enum SubjectDetails: StoryboardType {
    internal static let storyboardName = "SubjectDetails"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectDetailsViewController>(storyboard: Self.self)
  }
  internal enum SubjectDetailsSettings: StoryboardType {
    internal static let storyboardName = "SubjectDetailsSettings"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectDetailsSettingsViewController>(storyboard: Self.self)
  }
  internal enum SubjectsByCategory: StoryboardType {
    internal static let storyboardName = "SubjectsByCategory"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectsByCategoryViewController>(storyboard: Self.self)
  }
  internal enum SubjectsByLevel: StoryboardType {
    internal static let storyboardName = "SubjectsByLevel"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectsByLevelViewController>(storyboard: Self.self)
  }
  internal enum SubjectsRemaining: StoryboardType {
    internal static let storyboardName = "SubjectsRemaining"

    internal static let initialScene = InitialSceneType<Tsurukame.SubjectsRemainingViewController>(storyboard: Self.self)
  }
  internal enum UpcomingReviews: StoryboardType {
    internal static let storyboardName = "UpcomingReviews"

    internal static let initialScene = InitialSceneType<Tsurukame.UpcomingReviewsViewController>(storyboard: Self.self)
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

// MARK: - Implementation Details

internal protocol StoryboardType {
  static var storyboardName: String { get }
}

internal extension StoryboardType {
  static var storyboard: UIStoryboard {
    let name = self.storyboardName
    return UIStoryboard(name: name, bundle: BundleToken.bundle)
  }
}

internal struct SceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type
  internal let identifier: String

  internal func instantiate() -> T {
    let identifier = self.identifier
    guard let controller = storyboard.storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
      fatalError("ViewController '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(iOS 13.0, tvOS 13.0, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T {
    return storyboard.storyboard.instantiateViewController(identifier: identifier, creator: block)
  }
}

internal struct InitialSceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController() as? T else {
      fatalError("ViewController is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(iOS 13.0, tvOS 13.0, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController(creator: block) else {
      fatalError("Storyboard \(storyboard.storyboardName) does not have an initial scene.")
    }
    return controller
  }
}

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
