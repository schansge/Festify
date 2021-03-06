//
//  PGFestifyViewController.m
//  Festify
//
//  Created by Patrik Gebhardt on 15/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import "SMPlayerViewController.h"

@implementation SMPlayerViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // observe playback state change and track change to update UI accordingly
    [self.trackPlayer addObserver:self forKeyPath:@"playing" options:0 context:nil];
    [self.trackPlayer addObserver:self forKeyPath:@"currentPlaybackPosition" options:0 context:nil];
    [self.trackPlayer addObserver:self forKeyPath:@"currentTrack" options:0 context:nil];
    [self.trackPlayer addObserver:self forKeyPath:@"coverArtOfCurrentTrack" options:0 context:nil];
    
    // initialy setup UI correctly
    [self updateTrackInfo:self.trackPlayer.currentTrack];
    [self updateCoverArt:self.trackPlayer.coverArtOfCurrentTrack];
    [self updatePlayButton:self.trackPlayer.playing];
    [self updatePlaybackPosition:self.trackPlayer.currentPlaybackPosition
                     andDuration:self.trackPlayer.currentTrack.duration];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // remove observers
    [self.trackPlayer removeObserver:self forKeyPath:@"playing"];
    [self.trackPlayer removeObserver:self forKeyPath:@"currentPlaybackPosition"];
    [self.trackPlayer removeObserver:self forKeyPath:@"currentTrack"];
    [self.trackPlayer removeObserver:self forKeyPath:@"coverArtOfCurrentTrack"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"coverArtOfCurrentTrack"]) {
        [self updateCoverArt:self.trackPlayer.coverArtOfCurrentTrack];
    }
    else if ([keyPath isEqualToString:@"currentTrack"]) {
        [self updateTrackInfo:self.trackPlayer.currentTrack];
    }
    else if ([keyPath isEqualToString:@"playing"]) {
        [self updatePlayButton:self.trackPlayer.playing];
    }
    else if ([keyPath isEqualToString:@"currentPlaybackPosition"]) {
        [self updatePlaybackPosition:self.trackPlayer.currentPlaybackPosition
                         andDuration:self.trackPlayer.currentTrack.duration];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showPlaylist"]) {
        UINavigationController* navigationController = (UINavigationController*)segue.destinationViewController;
        SMPlaylistViewController* viewController = (SMPlaylistViewController*)navigationController.viewControllers[0];
        
        navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        viewController.trackPlayer = self.trackPlayer;
    }
}

#pragma mark - Actions

-(IBAction)rewind:(id)sender {
    [self.trackPlayer skipBackward];
}

-(IBAction)playPause:(id)sender {
    if (self.trackPlayer.playing) {
        [self.trackPlayer pause];
    }
    else {
        [self.trackPlayer play];
    }
}

-(IBAction)fastForward:(id)sender {
    [self.trackPlayer skipForward];
}

- (IBAction)openInSpotify:(id)sender {
    // open currently played track in spotify app, if available
    if ([SPTAuth defaultInstance].spotifyApplicationIsInstalled) {
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"spotify://%@",
                                           self.trackPlayer.currentTrack.uri.absoluteString]];
        
        [self.trackPlayer pause];
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (IBAction)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Logic

-(void)updatePlayButton:(BOOL)playing {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (playing) {
            [self.playPauseButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
        }
        else {
            [self.playPauseButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
        }
    });
}

-(void)updatePlaybackPosition:(NSTimeInterval)playbackPosition andDuration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.trackPosition.progress = playbackPosition / duration;
        self.currentTimeView.text = [NSString stringWithFormat:@"%d:%02d",
                                     (int)playbackPosition / 60, (int)playbackPosition % 60];
        self.remainingTimeView.text = [NSString stringWithFormat:@"%d:%02d",
                                       (int)(playbackPosition - duration) / 60,
                                       (int)(duration - playbackPosition) % 60];
    });
}

-(void)updateTrackInfo:(SPTTrack*)track {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.text = track.name;
        self.artistLabel.text = [track.artists[0] name];
    });
}

-(void)updateCoverArt:(UIImage*)coverArt {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (coverArt) {
            self.coverImage.image = coverArt;
        }
        else {
            self.coverImage.image = [UIImage imageNamed:@"DefaultCoverArt"];
        }
    });
}

@end