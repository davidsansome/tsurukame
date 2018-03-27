#import "AppDelegate.h"
#import "Client.h"
#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "MainViewController.h"
#import "ReviewViewController.h"
#import "UserDefaults.h"

#import <UserNotifications/UserNotifications.h>

@interface AppDelegate ()
@end

@implementation AppDelegate {
  UIStoryboard *_storyboard;
  UINavigationController *_navigationController;
  DataLoader *_dataLoader;
  LocalCachingClient *_localCachingClient;
  Reachability *_reachability;
}

- (BOOL)application:(UIApplication *)application
      didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
  
  _storyboard = self.window.rootViewController.storyboard;
  _navigationController = (UINavigationController *)self.window.rootViewController;
  
  _dataLoader = [[DataLoader alloc] initFromURL:[[NSBundle mainBundle] URLForResource:@"data"
                                                                        withExtension:@"bin"]];
  _reachability = [Reachability reachabilityForInternetConnection];
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(loginComplete:)
             name:kLoginCompleteNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(logout:)
             name:kLogoutNotification
           object:nil];
  
  if (UserDefaults.userApiToken && UserDefaults.userCookie) {
    [self loginComplete:nil];
  } else {
    [self pushLoginViewController];
  }
  
  return YES;
}

- (void)pushLoginViewController {
  LoginViewController *loginViewController = [_storyboard instantiateViewControllerWithIdentifier:@"login"];
  [_navigationController setViewControllers:@[loginViewController] animated:NO];
}

- (void)loginComplete:(NSNotification *)notification {
  Client *client = [[Client alloc] initWithApiToken:UserDefaults.userApiToken
                                             cookie:UserDefaults.userCookie];
  
  _localCachingClient = [[LocalCachingClient alloc] initWithClient:client reachability:_reachability];
  
  void (^pushMainViewController)(void) = ^() {
    MainViewController *vc = [_storyboard instantiateViewControllerWithIdentifier:@"main"];
    vc.dataLoader = _dataLoader;
    vc.reachability = _reachability;
    vc.localCachingClient = _localCachingClient;
    
    [_navigationController setViewControllers:@[vc] animated:(notification == nil) ? NO : YES];
  };
  // Do a sync before pushing the main view controller if this was a new login.
  if (notification) {
    [_localCachingClient sync:pushMainViewController];
  } else {
    pushMainViewController();
  }
}

- (void)logout:(NSNotification *)notification {
  UserDefaults.userCookie = nil;
  UserDefaults.userApiToken = nil;
  UserDefaults.userEmailAddress = nil;
  [_localCachingClient clearAllData];
  _localCachingClient = nil;
  
  [self pushLoginViewController];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [_reachability startNotifier];
  [_localCachingClient sync:nil];
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [_reachability stopNotifier];
  [self updateAppBadgeCount];
}

- (void)application:(UIApplication *)application
      performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  if (!_localCachingClient) {
    completionHandler(UIBackgroundFetchResultNoData);
    return;
  }
  
  __weak AppDelegate *weakSelf = self;
  [_localCachingClient sync:^{
    [weakSelf updateAppBadgeCount];
    completionHandler(UIBackgroundFetchResultNewData);
  }];
}

- (void)updateAppBadgeCount {
  int reviewCount = _localCachingClient.availableReviewCount;
  NSArray<NSNumber *> *upcomingReviews = _localCachingClient.upcomingReviews;

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  void(^updateBlock)(void) = ^() {
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
      NSString *identifier = [NSString stringWithFormat:@"badge-%d", hour];
      UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
      content.badge = @(cumulativeReviews);
      UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:triggerTimeInterval repeats:NO];
      UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
      [center addNotificationRequest:request withCompletionHandler:nil];
    }
  };
  
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge)
                        completionHandler:^(BOOL granted, NSError * _Nullable error) {
                          if (granted) {
                            dispatch_async(dispatch_get_main_queue(), updateBlock);
                          }
                        }];
}

@end
