//
//  PGFestifyTrackProvider.m
//  Festify
//
//  Created by Patrik Gebhardt on 15/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "PGFestifyTrackProvider.h"
#import "NSMutableArray+Shuffling.h"

@interface PGFestifyTrackProvider ()

@property (nonatomic, strong) SPTSession* session;
@property (nonatomic, strong) NSMutableDictionary* playlists;
@property (nonatomic, strong) NSMutableArray* tracks;

@end

@implementation PGFestifyTrackProvider

-(id)initWithSession:(SPTSession*)session {
    if (self = [super init]) {
        self.session = session;
        self.playlists = [NSMutableDictionary dictionary];
        self.tracks = [NSMutableArray array];
    }
    
    return self;
}

-(void)clearAllTracks {
    [self.playlists removeAllObjects];
    [self.tracks removeAllObjects];
}

-(void)addPlaylist:(SPTPlaylistSnapshot *)playlist forIdentifier:(NSString *)identifier {
    self.playlists[identifier] = [playlist.tracks copy];
    
    [self.tracks removeAllObjects];
    for (NSArray* tracks in self.playlists.allValues) {
        [self.tracks addObjectsFromArray:tracks];
    }
    
    // shuffle tracks array
    [self.tracks shuffle];
}

#pragma mark - SPTTrackProvider

-(NSArray *)tracks {
    return _tracks;
}

-(NSURL *)uri {
    return [NSURL URLWithString:@""];
}

@end
