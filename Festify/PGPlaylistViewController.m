//
//  PGPlaylistViewController.m
//  Festify
//
//  Created by Patrik Gebhardt on 17/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "PGPlaylistViewController.h"
#import "PGAppDelegate.h"
#import <Spotify/Spotify.h>
#import "UIImage+ImageEffects.h"
#import "UIView+ConvertToImage.h"

@interface PGPlaylistViewController ()

@property (nonatomic, weak) SPTTrackPlayer* trackPlayer;

@end

@implementation PGPlaylistViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.trackPlayer = ((PGAppDelegate*)[UIApplication sharedApplication].delegate).trackPlayer;
    [self createBlurredBackgroundFromView:self.underlyingView];
}

- (IBAction)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.delegate) {
            [self.delegate playlistViewDidEndShowing:self];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.trackPlayer.currentProvider.tracks.count;
}

#pragma mark - Table view delegate

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    NSUInteger trackIndex = (indexPath.row + self.trackPlayer.indexOfCurrentTrack + 1) % self.trackPlayer.currentProvider.tracks.count;
    cell.textLabel.text = [self.trackPlayer.currentProvider.tracks[trackIndex] name];
    cell.detailTextLabel.text = [[[self.trackPlayer.currentProvider.tracks[trackIndex] artists] objectAtIndex:0] name];
    cell.backgroundColor = [UIColor clearColor];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger trackIndex = (indexPath.row + self.trackPlayer.indexOfCurrentTrack + 1) % self.trackPlayer.currentProvider.tracks.count;
    [self.trackPlayer playTrackProvider:self.trackPlayer.currentProvider fromIndex:trackIndex];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - PGPlayerViewDelegate

-(void)playerView:(PGPlayerViewController *)playerView didUpdateTrackInfo:(NSDictionary *)trackInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        // update background image
        [self createBlurredBackgroundFromView:self.underlyingView];
        
        // update table view
        [self.tableView reloadData];
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                              atScrollPosition:UITableViewScrollPositionTop animated:YES];
    });
}

#pragma mark - Helper

-(void)createBlurredBackgroundFromView:(UIView*)view {
    // create image view containing a blured image of the current view controller.
    // This makes the effect of a transparent playlist view
    UIImage* image = [view convertToImage];
    image = [image applyBlurWithRadius:15
                             tintColor:[UIColor colorWithRed:236.0/255.0 green:235.0/255.0 blue:232.0/255.0 alpha:0.7]
                 saturationDeltaFactor:1.3
                             maskImage:nil];
    
    self.tableView.backgroundView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [(UIImageView*)self.tableView.backgroundView setImage:image];
}

@end
