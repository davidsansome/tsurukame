// Copyright 2020 David Sansome
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

#import "Settings.h"
#import "UIViewController+InterfaceStyle.h"

@implementation UIViewController (InterfaceStyle)

- (void)refreshInterfaceStyle {
  if (@available(iOS 13.0, *)) {
    switch (Settings.interfaceStyle) {
      case InterfaceStyle_Light:
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        break;
      case InterfaceStyle_Dark:
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        break;
      default:
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        break;
    }
  }
}

@end
