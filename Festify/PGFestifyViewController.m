//
//  PGFestifyViewController.m
//  Festify
//
//  Created by Patrik Gebhardt on 15/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "PGFestifyViewController.h"
#import "PGFestifyTrackProvider.h"
#import <iAd/iAd.h>

@interface PGFestifyViewController ()

@property (nonatomic, strong) SPTSession* session;
@property (nonatomic, strong) SPTTrackPlayer* trackPlayer;
@property (nonatomic, strong) PGFestifyTrackProvider* trackProvider;

@end

@implementation PGFestifyViewController

-(void)viewDidLoad {
    [super viewDidLoad];
	[self addObserver:self forKeyPath:@"trackPlayer.indexOfCurrentTrack" options:0 context:nil];

    // enable iAd
    self.canDisplayBannerAds = YES;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([[PGDiscoveryManager sharedInstance] isDiscoveringPlaylists]) {
        [self.trackPlayer playTrackProvider:self.trackProvider];
    }
}

-(void)handleNewSession:(SPTSession *)session {
    self.session = session;
    
    // create new track player if not already existing
    if (!self.trackPlayer) {
        self.trackPlayer = [[SPTTrackPlayer alloc] initWithCompanyName:@"Patrik Gebhardt" appName:@"Festify"];
        self.trackPlayer.delegate = self;
    }
    
    // init track provider and attach to discovery manager
    self.trackProvider = [[PGFestifyTrackProvider alloc] initWithSession:session];
    [PGDiscoveryManager sharedInstance].delegate = self.trackProvider;
    
    // enable playback
    [self.trackPlayer enablePlaybackWithSession:session callback:^(NSError *error) {
        if (error) {
			NSLog(@"*** Enabling playback got error: %@", error);
        }
    }];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"trackPlayer.indexOfCurrentTrack"]) {
        [self updateUI];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Actions

-(IBAction)rewind:(id)sender {
	[self.trackPlayer skipToPreviousTrack:NO];
}

-(IBAction)playPause:(id)sender {
	if (self.trackPlayer.paused) {
		[self.trackPlayer resumePlayback];
	} else {
		[self.trackPlayer pausePlayback];
	}
}

-(IBAction)fastForward:(id)sender {
	[self.trackPlayer skipToNextTrack];
}

#pragma mark - Logic

-(void)updateUI {
	if (self.trackPlayer.indexOfCurrentTrack == NSNotFound) {
		self.titleLabel.text = @"Nothing Playing";
		self.albumLabel.text = @"";
		self.artistLabel.text = @"";
        self.coverImage.image = nil;
	}
    else {
		NSInteger index = self.trackPlayer.indexOfCurrentTrack;
		SPTTrack *track = (SPTTrack*)self.trackProvider.tracks[index];
		self.titleLabel.text = track.name;
		self.albumLabel.text = track.album.name;
		self.artistLabel.text = [track.artists.firstObject name];
        self.coverImage.image = nil;
        
        [self loadCoverArt];
    }
}

-(void)loadCoverArt {
    // request complete album of track
    [SPTRequest requestItemFromPartialObject:[self.trackProvider.tracks[self.trackPlayer.indexOfCurrentTrack] album]
                                 withSession:self.session
                                    callback:^(NSError *error, id object) {
        if (error) {
            return;
        }

        SPTAlbum* album = (SPTAlbum*)object;
        NSURL* imageURL = album.largestCover.imageURL;
        
        if (imageURL == nil) {
            NSLog(@"Album %@ doesn't have any images!", album);
            self.coverImage.image = nil;
            return;
        }
        
        [self.spinner startAnimating];
        
        // Pop over to a background queue to load the image over the network.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSError *error = nil;
            UIImage *image = nil;
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL options:0 error:&error];
            
            if (imageData != nil) {
                image = [UIImage imageWithData:imageData];
            }
            
            // …and back to the main queue to display the image.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                self.coverImage.image = image;
                if (image == nil) {
                    NSLog(@"Couldn't load cover image with error: %@", error);
                }
            });
        });
    }];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showSettings"]) {
        [segue.destinationViewController setSession:self.session];
    }
}

#pragma mark - Track Player Delegates

-(void)trackPlayer:(SPTTrackPlayer *)player didStartPlaybackOfTrackAtIndex:(NSInteger)index ofProvider:(id <SPTTrackProvider>)provider {
	NSLog(@"Started playback of track %@ of %@", @(index), provider.uri);
}

-(void)trackPlayer:(SPTTrackPlayer *)player didEndPlaybackOfTrackAtIndex:(NSInteger)index ofProvider:(id<SPTTrackProvider>)provider {
    NSLog(@"Ended playback of track %@ of %@", @(index), provider.uri);
}

-(void)trackPlayer:(SPTTrackPlayer *)player didEndPlaybackOfProvider:(id <SPTTrackProvider>)provider withReason:(SPTPlaybackEndReason)reason {
	NSLog(@"Ended playback of provider %@ with reason %@", provider.uri, @(reason));
}

-(void)trackPlayer:(SPTTrackPlayer *)player didEndPlaybackOfProvider:(id <SPTTrackProvider>)provider withError:(NSError *)error {
	NSLog(@"Ended playback of provider %@ with error %@", provider.uri, error);
}

-(void)trackPlayer:(SPTTrackPlayer *)player didDidReceiveMessageForEndUser:(NSString *)message {
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
														message:message
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


@end
