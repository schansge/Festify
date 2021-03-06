//
//  PGLoginViewController.h
//  Festify
//
//  Created by Patrik Gebhardt on 16/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Spotify/Spotify.h>

@class SMLoginViewController;

@protocol SMLoginViewDelegate <NSObject>

-(void)loginView:(SMLoginViewController*)loginView didCompleteLoginWithSession:(SPTSession*)session;

@end

@interface SMLoginViewController : UIViewController

- (IBAction)login:(id)sender;

@property (nonatomic, weak) id<SMLoginViewDelegate> delegate;

@end
