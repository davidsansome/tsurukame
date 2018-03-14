#import "AppDelegate.h"
#import "Client.h"
#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "MainViewController.h"
#import "ReviewViewController.h"
#import "UserDefaults.h"

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
  _storyboard = self.window.rootViewController.storyboard;
  _navigationController = (UINavigationController *)self.window.rootViewController;
  
  _dataLoader = [[DataLoader alloc] initFromURL:[[NSBundle mainBundle] URLForResource:@"data"
                                                                        withExtension:@"bin"]];
  _reachability = [Reachability reachabilityForInternetConnection];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(loginComplete:)
                                               name:kLoginCompleteNotification
                                             object:nil];
  
  if (UserDefaults.userApiToken && UserDefaults.userCookie) {
    [self loginComplete:nil];
  } else {
    LoginViewController *loginViewController = [_storyboard instantiateViewControllerWithIdentifier:@"login"];
    [_navigationController setViewControllers:@[loginViewController] animated:NO];
  }
  
  return YES;
}

- (void)loginComplete:(NSNotification *)notification {
  Client *client = [[Client alloc] initWithApiToken:UserDefaults.userApiToken
                                             cookie:UserDefaults.userCookie];
  
  _localCachingClient = [[LocalCachingClient alloc] initWithClient:client reachability:_reachability];
  
  MainViewController *vc = [_storyboard instantiateViewControllerWithIdentifier:@"main"];
  vc.dataLoader = _dataLoader;
  vc.reachability = _reachability;
  vc.localCachingClient = _localCachingClient;
  
  NSLog(@"Pushing main view controller %@ %@", _navigationController, self.window.rootViewController);
  [_navigationController setViewControllers:@[vc] animated:(notification == nil) ? NO : YES];
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [_reachability stopNotifier];
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
  [_reachability startNotifier];
  [_localCachingClient sync];
}

@end
