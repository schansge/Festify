//
//  PGAppDelegate.m
//  Festify
//
//  Created by Patrik Gebhardt on 14/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMUserDefaults.h"
#import "TSMessage.h"
#import "MBProgressHUD.h"
#import "MWLogging.h"

// spotify authentication constants
// TODO: replace with post-beta IDs and adjust the App's URL type
static NSString* const kClientID = @"spotify-ios-sdk-beta";
static NSString * const kCallbackURL = @"spotify-ios-sdk-beta://callback";

@interface SMAppDelegate ()
@property (nonatomic, copy) void (^loginCallback)(NSError* error);
@end

@implementation SMAppDelegate

-(void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [self.trackPlayer handleRemoteEvent:event];
}

-(void)requestSpotifySessionWithCompletionHandler:(void (^)(NSError *))completion {
    // set login callback
    self.loginCallback = completion;
    
    // get login url
    NSURL* loginURL = [[SPTAuth defaultInstance] loginURLForClientId:kClientID
                                                 declaredRedirectURL:[NSURL URLWithString:kCallbackURL]
                                                              scopes:@[@"login"]];
    
    // open url in safari to login to spotify api
    [[UIApplication sharedApplication] openURL:loginURL];
}

-(void)loginToSpotifyAPIWithCompletionHandler:(void (^)(NSError *))completion {
    // login to track player to Spotify
    [self.trackPlayer enablePlaybackWithSession:self.session callback:^(NSError *error) {
        if (!error) {
            // start receiving remote control events
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        }
        
        if (completion) {
            completion(error);
        }
    }];
}

-(void)logoutOfSpotifyAPI {
    // stop receiving remote control events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    
    // cleanup spotify
    [self.trackPlayer clear];
    [self.trackProvider clearAllTracks];
    self.session = nil;
}

#pragma mark - UIApplicationDelegate

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.trackPlayer = [SMTrackPlayer trackPlayerWithCompanyName:[NSBundle mainBundle].bundleIdentifier
                                                         appName:[NSBundle mainBundle].infoDictionary[(NSString*)kCFBundleNameKey]];
    self.trackProvider = [[SMTrackProvider alloc] init];

    // adjust default colors to match spotify color schema
    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    [TSMessage addCustomDesignFromFileWithName:@"spotifymessagedesign.json"];

     return YES;
}

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    // this is the return point for the spotify authentication,
    // so completion happens here
    if ([[SPTAuth defaultInstance] canHandleURL:url withDeclaredRedirectURL:[NSURL URLWithString:kCallbackURL]]) {
        [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url
                                            tokenSwapServiceEndpointAtURL:[NSURL URLWithString:@"http://192.168.178.28:1234/swap"]
                                                                 callback:^(NSError *error, SPTSession *session) {
            if (!error) {
                self.session = session;
            }

            // call callback to inform about completed session request
            if (self.loginCallback) {
                self.loginCallback(error);
            }
        }];
        
        return YES;
    }
    
    return NO;
}

-(void)applicationWillTerminate:(UIApplication *)application {
    // save current application state
    [SMUserDefaults saveApplicationState];
}

-(void)applicationWillResignActive:(UIApplication *)application {
    // save current application state
    [SMUserDefaults saveApplicationState];    
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    // assume spotify did logout when player is not playing
    if (!self.trackPlayer.playing) {
        [MBProgressHUD showHUDAddedTo:self.window.subviews.lastObject animated:YES];
        [self.trackPlayer enablePlaybackWithSession:self.session callback:^(NSError *error) {
            [MBProgressHUD hideAllHUDsForView:self.window.subviews.lastObject animated:YES];
            
            if (error) {
                MWLogError(@"%@", error);
            }
        }];
    }
}
@end