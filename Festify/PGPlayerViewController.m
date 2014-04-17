//
//  PGFestifyViewController.m
//  Festify
//
//  Created by Patrik Gebhardt on 15/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "PGPlayerViewController.h"
#import "PGPlaylistViewController.h"

@implementation PGPlayerViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // observe playback state change and track change to update UI accordingly
    [self addObserver:self forKeyPath:@"streamingController.currentTrackMetadata" options:0 context:nil];
    [self addObserver:self forKeyPath:@"streamingController.isPlaying" options:0 context:nil];

    // initialy setup UI correctly
    [self updateTrackInfo:self.streamingController.currentTrackMetadata];
    [self updatePlayButton:self.streamingController.isPlaying];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self removeObserver:self forKeyPath:@"streamingController.currentTrackMetadata"];
    [self removeObserver:self forKeyPath:@"streamingController.isPlaying"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"streamingController.currentTrackMetadata"]) {
        [self updateTrackInfo:self.streamingController.currentTrackMetadata];
    }
    else if ([keyPath isEqualToString:@"streamingController.isPlaying"]) {
        [self updatePlayButton:self.streamingController.isPlaying];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showPlaylist"]) {
        PGPlaylistViewController* viewController = (PGPlaylistViewController*)segue.destinationViewController;
        
        viewController.trackPlayer = self.trackPlayer;
    }
}

#pragma mark - Actions

-(IBAction)rewind:(id)sender {
    if (self.trackPlayer.currentProvider != nil) {
        [self.trackPlayer skipToPreviousTrack:NO];
    }
}

-(IBAction)playPause:(id)sender {
    if (self.trackPlayer.currentProvider != nil) {
        if (self.trackPlayer.paused) {
            [self.trackPlayer resumePlayback];
        }
        else {
            [self.trackPlayer pausePlayback];
        }
    }
}

-(IBAction)fastForward:(id)sender {
    if (self.trackPlayer.currentProvider != nil) {
        [self.trackPlayer skipToNextTrack];
    }
}

#pragma mark - Logic

-(void)updatePlayButton:(BOOL)isPlaying {
    if (isPlaying) {
        self.playPauseButton.imageView.image = [UIImage imageNamed:@"Pause"];
    }
    else {
        self.playPauseButton.imageView.image = [UIImage imageNamed:@"Play"];
    }
}

-(void)updateTrackInfo:(NSDictionary*)trackMetadata {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (trackMetadata) {
            self.titleLabel.text = trackMetadata[SPTAudioStreamingMetadataTrackName];
            self.albumLabel.text = trackMetadata[SPTAudioStreamingMetadataAlbumName];
            self.artistLabel.text = trackMetadata[SPTAudioStreamingMetadataArtistName];
            
            [self loadAlbumCoverArtWithURL:[NSURL URLWithString:trackMetadata[SPTAudioStreamingMetadataAlbumURI]]];
        }
        else {
            self.titleLabel.text = @"Nothing Playing";
            self.albumLabel.text = @"";
            self.artistLabel.text = @"";
            self.coverImage.image = nil;
        }
    });
}

-(void)loadAlbumCoverArtWithURL:(NSURL*)albumURI {
    // request complete album of track
    [SPTRequest requestItemAtURI:albumURI withSession:self.session callback:^(NSError *error, id object) {
        if (!error) {
            // extract image URL
            NSURL* imageURL = [object largestCover].imageURL;
            
            // download image
            [self.spinner startAnimating];
            [[[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:imageURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // show cover image
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.spinner stopAnimating];
                    self.coverImage.image = [UIImage imageWithData:data];
                });
            }] resume];
        }
    }];
}

@end