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

enum FeatureFlags {
  private enum Config {
    case DeveloperDebug
    case TestFlightRelease
    case AppStoreRelease
  }

  #if TSURUKAME_CONFIG_DEVELOPER_DEBUG
    private static let config = Config.DeveloperDebug
  #endif
  #if TSURUKAME_CONFIG_TESTFLIGHT_RELEASE
    private static let config = Config.TestFlightRelease
  #endif
  #if TSURUKAME_CONFIG_APP_STORE_RELEASE
    private static let config = Config.AppStoreRelease
  #endif

  static let showOtherPracticeModes = (config != .AppStoreRelease)
}
