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

  Client *client = [[Client alloc] initWithApiToken:@"(redacted in git history)"];
  
  LocalCachingClient *lcc = [[LocalCachingClient alloc] initWithClient:client reachability:_reachability];
  
  MainViewController *vc = [[MainViewController alloc] init];
  
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  nav.navigationBarHidden = YES;

  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.rootViewController = nav;
  
  self.window.backgroundColor = [UIColor whiteColor];
  [self.window makeKeyAndVisible];
  
  NSLog(@"Starting thread %@", [NSThread currentThread]);
  [lcc getAllAssignments:^(NSError *error, NSArray<WKAssignment *> *assignments) {
    if (error) {
      NSLog(@"Failed to get assignments: %@", error);
      return;
    }
    NSLog(@"Callback thread %@", [NSThread currentThread]);
    NSLog(@"Got %lu assignments", (unsigned long)assignments.count);
    NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForReview:assignments];
    NSLog(@"Got %lu items", (unsigned long)items.count);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      ReviewViewController *rvc = [[ReviewViewController alloc]
                                   initWithItems:items
                                   dataLoader:_dataLoader];
      [vc.navigationController pushViewController:rvc animated:YES];
    });
  }];

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
