//
//  AppDelegate.m
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "AppDelegate.h"
#import "Client.h"
#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "MainViewController.h"
#import "ReviewViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate {
  DataLoader *_dataLoader;
  Reachability *_reachability;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  _dataLoader = [[DataLoader alloc] initFromURL:[[NSBundle mainBundle] URLForResource:@"data"
                                                                        withExtension:@"bin"]];
  _reachability = [Reachability reachabilityForInternetConnection];

  Client *client = [[Client alloc] initWithApiToken:@"(redacted in git history)"
                                             cookie:@"(redacted in git history)"];
  
  LocalCachingClient *lcc = [[LocalCachingClient alloc] initWithClient:client reachability:_reachability];
  
  MainViewController *vc = (MainViewController *)
      ((UINavigationController *)self.window.rootViewController).topViewController;
  vc.dataLoader = _dataLoader;
  vc.reachability = _reachability;
  vc.localCachingClient = lcc;
  
  return YES;
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
}


- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
