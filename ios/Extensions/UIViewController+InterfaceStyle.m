//
//  UIViewController+InterfaceStyleViewController.m
//  Tsurukame
//
//  Created by Matt Sanford on 1/16/20.
//  Copyright © 2020 David Sansome. All rights reserved.
//

#import "UIViewController+InterfaceStyle.h"
#import "Settings.h"

@implementation UIViewController (InterfaceStyle)

- (void )refreshInterfaceStyle {
    if (@available(iOS 13.0, *)) {
      switch (Settings.interfaceStyle) {
          case InterfaceStyle_Light:
              self.overrideUserInterfaceStyle =  UIUserInterfaceStyleLight;
              break;
          case InterfaceStyle_Dark:
              self.overrideUserInterfaceStyle =  UIUserInterfaceStyleDark;
              break;
          default:
              self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
              break;
      }
    }
}

@end
