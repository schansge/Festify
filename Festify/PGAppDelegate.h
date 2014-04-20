//
//  PGAppDelegate.h
//  Festify
//
//  Created by Patrik Gebhardt on 14/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Spotify/Spotify.h>
#import "PGFestifyTrackProvider.h"

@interface PGAppDelegate : UIResponder <UIApplicationDelegate>

-(void)loginToSpotifyAPI:(void (^)(NSError* error))completion ;
-(void)logoutOfSpotifyAPI;
-(void)initStreamingControllerWithCompletionHandler:(void (^)(NSError* error))completion;

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) SPTSession* session;
@property (nonatomic, strong) SPTAudioStreamingController* streamingController;
@property (nonatomic, strong) SPTTrackPlayer* trackPlayer;
@property (nonatomic, strong) PGFestifyTrackProvider* trackProvider;

@end
