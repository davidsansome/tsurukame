// Copyright 2025 David Sansome
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

// Compile-time feature flags.
enum FeatureFlags {
  // Whether to show a tab bar at the bottom of the main screen to select between WaniKani and other
  // practice modes.
  static let showOtherPracticeModes = (config != .AppStoreRelease)

  // Whether to print the Subject textproto when loading a SubjectDetailsView.
  static let dumpSubjectTextproto = (config == .DeveloperDebug)

  // Whether to show an extra Developer Options section at the bottom of the SubjectDetailsView.
  static let showSubjectDeveloperOptions = (config == .DeveloperDebug)

  private enum BuildConfig {
    case DeveloperDebug
    case TestFlightRelease
    case AppStoreRelease
  }

  // These SWIFT_ACTIVE_COMPILATION_CONDITIONS are set by the .xcconfig files in the BuildConfigs
  // directory.
  #if TSURUKAME_CONFIG_DEVELOPER_DEBUG
    private static let config = BuildConfig.DeveloperDebug
  #endif
  #if TSURUKAME_CONFIG_TESTFLIGHT_RELEASE
    private static let config = BuildConfig.TestFlightRelease
  #endif
  #if TSURUKAME_CONFIG_APP_STORE_RELEASE
    private static let config = BuildConfig.AppStoreRelease
  #endif
}
