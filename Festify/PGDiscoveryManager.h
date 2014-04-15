//
//  PGDiscoveryManager.h
//  Festify
//
//  Created by Patrik Gebhardt on 14/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <Spotify/Spotify.h>

@class PGDiscoveryManager;

@protocol PGDiscoveryManagerDelegate<NSObject>

-(void)discoveryManager:(PGDiscoveryManager*)discoveryManager didDiscoverPlaylistWithURI:(NSURL*)uri fromIdentifier:(NSString*)identifier;

@end

@interface PGDiscoveryManager : NSObject<CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>

+(PGDiscoveryManager*)sharedInstance;

-(void)setAdvertisingPlaylist:(SPTPartialPlaylist*)playlist withSession:(SPTSession*)session;
-(void)startAdvertisingPlaylistWithSession:(SPTSession*)session;
-(void)stopAdvertisingPlaylist;
-(BOOL)isAdvertisingsPlaylist;

-(void)startDiscoveringPlaylists;
-(void)stopDiscoveringPlaylists;
-(BOOL)isDiscoveringPlaylists;

@property (nonatomic, weak) id<PGDiscoveryManagerDelegate> delegate;
@property (nonatomic, strong) CBUUID* serviceUUID;
@property (nonatomic, strong, readonly) SPTPartialPlaylist* advertisingPlaylist;

@end
