// Copyright 2018 David Sansome
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

#import "AppDelegate.h"
#import "Client.h"
#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "MainViewController.h"
#import "Settings.h"
#import "TKMAudio.h"
#import "TKMServices+Internals.h"
#import "Tsurukame-Swift.h"

#import <UserNotifications/UserNotifications.h>

@interface AppDelegate () <LoginViewControllerDelegate>
@end

@implementation AppDelegate {
  UIStoryboard *_storyboard;
  UINavigationController *_navigationController;
  TKMServices *_services;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Uncomment to slow the animation speed on a real device.
  // [self.window.layer setSpeed:.1f];

  [Settings initializeDefaultsOnStartup];

  [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

  _storyboard = self.window.rootViewController.storyboard;
  _navigationController = (UINavigationController *)self.window.rootViewController;
  _services = [[TKMServices alloc] init];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(logout:) name:kLogoutNotification object:nil];
  [nc addObserver:self
         selector:@selector(userInfoChanged:)
             name:kLocalCachingClientUserInfoChangedNotification
           object:nil];

  if (Settings.userApiToken && Settings.userCookie) {
    [self setMainViewControllerAnimated:NO clearUserData:NO];
  } else {
    [self pushLoginViewController];
  }

  return YES;
}

- (void)pushLoginViewController {
  LoginViewController *loginViewController =
      [_storyboard instantiateViewControllerWithIdentifier:@"login"];
  loginViewController.delegate = self;
  [_navigationController setViewControllers:@[ loginViewController ] animated:NO];
}

- (void)setMainViewControllerAnimated:(BOOL)animated clearUserData:(BOOL)clearUserData {
  Client *client = [[Client alloc] initWithApiToken:Settings.userApiToken
                                             cookie:Settings.userCookie
                                         dataLoader:_services.dataLoader];

  _services.localCachingClient = [[LocalCachingClient alloc] initWithClient:client
                                                                 dataLoader:_services.dataLoader
                                                               reachability:_services.reachability];

  // Ask for notification permissions.
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  UNAuthorizationOptions options = UNAuthorizationOptionBadge | UNAuthorizationOptionAlert;
  [center requestAuthorizationWithOptions:options
                        completionHandler:^(BOOL granted, NSError *_Nullable error){
                        }];

  void (^pushMainViewController)(void) = ^() {
    MainViewController *vc = [_storyboard instantiateViewControllerWithIdentifier:@"main"];
    [vc setupWithServices:_services];

    [_navigationController setViewControllers:@[ vc ] animated:animated];
  };
  void (^syncProgressHandler)(float) = ^(float progress) {
    if (progress == 1.0) {
      pushMainViewController();
    }
  };

  // Do a sync before pushing the main view controller if this was a new login.
  if (clearUserData) {
    [_services.localCachingClient clearAllData];
    [_services.localCachingClient syncWithProgressHandler:syncProgressHandler quick:true];
  } else {
    [self userInfoChanged:nil];  // Set the user's max level.
    pushMainViewController();
  }
}

- (void)loginComplete {
  [self setMainViewControllerAnimated:YES clearUserData:YES];
}

- (void)logout:(NSNotification *)notification {
  Settings.userCookie = nil;
  Settings.userApiToken = nil;
  Settings.userEmailAddress = nil;
  [_services.localCachingClient clearAllDataAndClose];
  _services.localCachingClient = nil;

  [self pushLoginViewController];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [_services.reachability startNotifier];

  if ([_navigationController.topViewController isKindOfClass:MainViewController.class]) {
    MainViewController *vc = (MainViewController *)_navigationController.topViewController;
    [vc refreshQuick:true];
  }
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [_services.reachability stopNotifier];
  [self updateAppBadgeCount];
}

- (void)application:(UIApplication *)application
    performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  if (!_services.localCachingClient) {
    completionHandler(UIBackgroundFetchResultNoData);
    return;
  }

  __weak AppDelegate *weakSelf = self;
  [_services.localCachingClient
      syncWithProgressHandler:^(float progress) {
        if (progress == 1.0) {
          [weakSelf updateAppBadgeCount];
          completionHandler(UIBackgroundFetchResultNewData);
        }
      }
                        quick:true];
}

- (void)updateAppBadgeCount {
  if (!Settings.notificationsAllReviews && !Settings.notificationsBadging) {
    return;
  }

  int reviewCount = _services.localCachingClient.availableReviewCount;
  NSArray<NSNumber *> *upcomingReviews = _services.localCachingClient.upcomingReviews;
  TKMUser *user = _services.localCachingClient.getUserInfo;

  if (user.hasVacationStartedAt) {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    return;
  }

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  void (^updateBlock)(void) = ^() {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:reviewCount];
    [center removeAllPendingNotificationRequests];

    NSDate *startDate = [[NSCalendar currentCalendar] nextDateAfterDate:[NSDate date]
                                                           matchingUnit:NSCalendarUnitMinute
                                                                  value:0
                                                                options:NSCalendarMatchNextTime];
    NSTimeInterval startInterval = [startDate timeIntervalSinceNow];
    int cumulativeReviews = reviewCount;
    for (int hour = 0; hour < upcomingReviews.count; hour++) {
      int reviews = [upcomingReviews[hour] intValue];
      if (reviews == 0) {
        continue;
      }
      cumulativeReviews += reviews;

      NSTimeInterval triggerTimeInterval = startInterval + (hour * 60 * 60);
      if (triggerTimeInterval <= 0) {
        // UNTimeIntervalNotificationTrigger sometimes crashes with a negative triggerTimeInterval.
        continue;
      }
      NSString *identifier = [NSString stringWithFormat:@"badge-%d", hour];
      UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
      if (Settings.notificationsAllReviews) {
        content.body = [NSString stringWithFormat:@"%d review%@ available", cumulativeReviews,
                                                  cumulativeReviews == 1 ? @"" : @"s"];
      }
      if (Settings.notificationsBadging) {
        content.badge = @(cumulativeReviews);
      }
      UNNotificationTrigger *trigger =
          [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:triggerTimeInterval
                                                             repeats:NO];
      UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                            content:content
                                                                            trigger:trigger];
      [center addNotificationRequest:request withCompletionHandler:nil];
    }
  };

  [center
      getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
        if (settings.badgeSetting == UNNotificationSettingEnabled) {
          dispatch_async(dispatch_get_main_queue(), updateBlock);
        }
      }];
}

- (void)userInfoChanged:(NSNotification *)notification {
  _services.dataLoader.maxLevelGrantedBySubscription =
      [_services.localCachingClient getUserInfo].maxLevelGrantedBySubscription;
}

@end
