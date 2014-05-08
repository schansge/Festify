//
//  PGUserDefaults.m
//  Festify
//
//  Created by Patrik Gebhardt on 22/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "SMUserDefaults.h"
#import "SMDiscoveryManager.h"
#import "SMAppDelegate.h"
#import <Spotify/Spotify.h>

@implementation SMUserDefaults

+(void)saveApplicationState {
    // force synchronization
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+(void)clear {
    // clear NSUserDefault storage
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SMUserDefaultsAdvertisementStateKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SMUserDefaultsSpotifySessionKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SMUserDefaultsAdvertisedPlaylistsKey];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+(SPTSession *)session {
    id plistRepresentation = [[NSUserDefaults standardUserDefaults] valueForKey:SMUserDefaultsSpotifySessionKey];
    return [[SPTSession alloc] initWithPropertyListRepresentation:plistRepresentation];
}

+(void)setSession:(SPTSession *)session {
    [[NSUserDefaults standardUserDefaults] setValue:session.propertyListRepresentation
                                             forKey:SMUserDefaultsSpotifySessionKey];
}

+(BOOL)advertisementState {
    NSObject* advertisementState = [[NSUserDefaults standardUserDefaults] valueForKeyPath:SMUserDefaultsAdvertisementStateKey];
    
    if (!advertisementState) {
        return YES;
    }
    return [(NSNumber*)advertisementState boolValue];
}

+(void)setAdvertisementState:(BOOL)state {
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:state]
                                             forKey:SMUserDefaultsAdvertisementStateKey];
}

+(void)advertisedPlaylists:(void (^)(NSArray *))completion {
    NSMutableArray* advertisedPlaylists = [[NSUserDefaults standardUserDefaults] valueForKey:SMUserDefaultsAdvertisedPlaylistsKey];
    
    if (!advertisedPlaylists) {
        advertisedPlaylists = [NSMutableArray array];
        
        // initialize advertised playlists with all playlists, if session is available
        SPTSession* session = [SMUserDefaults session];
        if (session) {
            [SPTRequest playlistsForUser:session.canonicalUsername withSession:session callback:^(NSError *error, id object) {
                if (!error) {
                    [advertisedPlaylists addObjectsFromArray:[[[object items] valueForKey:@"uri"] valueForKey:@"absoluteString"]];
                }
                
                if (completion) {
                    completion(advertisedPlaylists);
                }
            }];
        }
        else if (completion) {
            completion(advertisedPlaylists);
        }
    }
    else if (completion) {
        completion(advertisedPlaylists);
    }
}

+(void)setAdvertisedPlaylists:(NSArray *)advertisedPlaylists {
    [[NSUserDefaults standardUserDefaults] setValue:advertisedPlaylists
                                             forKey:SMUserDefaultsAdvertisedPlaylistsKey];
}

@end