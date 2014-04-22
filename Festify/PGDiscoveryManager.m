//
//  PGDiscoveryManager.m
//  Festify
//
//  Created by Patrik Gebhardt on 14/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "PGDiscoveryManager.h"

@interface PGDiscoveryManager ()

@property (nonatomic, strong) CBCentralManager* centralManager;
@property (nonatomic, strong) CBPeripheralManager* peripheralManager;
@property (nonatomic, strong) NSMutableArray* discoveredPeripherals;
@property (nonatomic, strong) NSMutableDictionary* peripheralData;
@property (nonatomic, assign) BOOL discoveringPlaylists;

@end

@implementation PGDiscoveryManager {
    SPTPartialPlaylist* _advertisingPlaylist;
}

// create a singleton instance of discovery manager
+(PGDiscoveryManager*)sharedInstance {
    static PGDiscoveryManager* _sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void) {
        _sharedInstance = [[PGDiscoveryManager alloc] init];
    });
    
    return _sharedInstance;
}

-(id)init {
    if (self = [super init]) {
        // create bluetooth manager and set self as their delegate
        dispatch_queue_t centralManagerQueue = dispatch_queue_create("com.patrikgebhardt.festify.centralManager", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t peripheralManagerQueue = dispatch_queue_create("com.patrikgebhardt.festify.peripheralManager", DISPATCH_QUEUE_SERIAL);
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralManagerQueue];
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:nil queue:peripheralManagerQueue];
        self.discoveringPlaylists = NO;
        
        self.discoveredPeripherals = [NSMutableArray array];
        self.peripheralData = [NSMutableDictionary dictionary];
    }
    
    return self;
}

-(BOOL)setAdvertisingPlaylist:(SPTPartialPlaylist *)playlist {
    _advertisingPlaylist = playlist;
    
    // detect own playlist
    if (self.isDiscoveringPlaylists && self.delegate) {
        [self.delegate discoveryManager:self didDiscoverPlaylistWithURI:self.advertisingPlaylist.uri devicename:[UIDevice currentDevice].name identifier:@"self"];
    }
    
    // restart bluetooth service
    if (self.peripheralManager.isAdvertising) {
        [self stopAdvertisingPlaylist];
        return [self startAdvertisingPlaylist];
    }

    return NO;
}

-(SPTPartialPlaylist*)advertisingPlaylist {
    return _advertisingPlaylist;
}

-(BOOL)startAdvertisingPlaylist {
    if (!self.advertisingPlaylist) {
        return NO;
    }
    
    // check the bluetooth state
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        return NO;
    }
    
    // init peripheral service to advertise playlist uri and device name
    CBMutableCharacteristic* nameCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:PGDiscoveryManagerNameUUIDString]
                                                                                     properties:CBCharacteristicPropertyRead
                                                                                          value:[[UIDevice currentDevice].name dataUsingEncoding:NSUTF8StringEncoding]
                                                                                    permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* uriCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:PGDiscoveryManagerPlaylistUUIDString]
                                                                                    properties:CBCharacteristicPropertyRead
                                                                                         value:[[self.advertisingPlaylist.uri absoluteString] dataUsingEncoding:NSUTF8StringEncoding]
                                                                                   permissions:CBAttributePermissionsReadable];
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:PGDiscoveryManagerServiceUUIDString] primary:YES];
    service.characteristics = @[nameCharacteristic, uriCharacteristic];
    [self.peripheralManager addService:service];
    
    // advertise service
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:PGDiscoveryManagerServiceUUIDString]],
                                               CBAdvertisementDataLocalNameKey: [UIDevice currentDevice].name}];
    
    return YES;
}

-(void)stopAdvertisingPlaylist {
    [self.peripheralManager stopAdvertising];
    [self.peripheralManager removeAllServices];
}

-(BOOL)isAdvertisingsPlaylist {
    return self.peripheralManager.isAdvertising;
}

-(BOOL)startDiscoveringPlaylists {
    // check the bluetooth state
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        return NO;
    }
    
    // scan for festify services
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:PGDiscoveryManagerServiceUUIDString]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    self.discoveringPlaylists = YES;
    
    // detect own playlist
    if (self.advertisingPlaylist && self.delegate) {
        [self.delegate discoveryManager:self didDiscoverPlaylistWithURI:self.advertisingPlaylist.uri devicename:[UIDevice currentDevice].name identifier:@"self"];
    }
    
    return YES;
}

-(void)stopDiscoveringPlaylists {
    [self.centralManager stopScan];
    self.discoveringPlaylists = NO;
}

-(BOOL)isDiscoveringPlaylists {
    return self.discoveringPlaylists;
}

#pragma mark - CBCentralManagerDelegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {

}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // connect to peripheral to retrieve list of services and
    // prevent CoreBluetooth from deallocating peripheral
    [self.discoveredPeripherals addObject:peripheral];
    peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // discover our service
    [peripheral discoverServices:@[[CBUUID UUIDWithString:PGDiscoveryManagerServiceUUIDString]]];
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
    [self.peripheralData removeObjectForKey:peripheral.identifier.UUIDString];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
    [self.peripheralData removeObjectForKey:peripheral.identifier.UUIDString];
}

#pragma mark - CBPeripheralDelegate

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // discover the playlist characteristic
    if (peripheral.services.count != 0) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:PGDiscoveryManagerNameUUIDString], [CBUUID UUIDWithString:PGDiscoveryManagerPlaylistUUIDString]]
                                 forService:peripheral.services[0]];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    // read playlist value of the characteristic
    for (CBCharacteristic* characteristic in service.characteristics) {
        [peripheral readValueForCharacteristic:characteristic];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    // add dictionary for current peripheral
    if (!self.peripheralData[peripheral.identifier.UUIDString]) {
        self.peripheralData[peripheral.identifier.UUIDString] = [NSMutableDictionary dictionary];
    }

    // save received data to peripheral dictionary
    [self.peripheralData[peripheral.identifier.UUIDString] setValue:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]
                                                             forKey:[characteristic.UUID.UUIDString lowercaseString]];

    // check if all data are collected
    if ([self.peripheralData[peripheral.identifier.UUIDString] allKeys].count == 2) {
        // inform delegate about new playlist
        if (self.delegate) {
            NSURL* playlistURI = [NSURL URLWithString:[self.peripheralData[peripheral.identifier.UUIDString] objectForKey:PGDiscoveryManagerPlaylistUUIDString]];
            NSString* devicename = [NSString stringWithString:[self.peripheralData[peripheral.identifier.UUIDString] objectForKey:PGDiscoveryManagerNameUUIDString]];
            [self.delegate discoveryManager:self
                 didDiscoverPlaylistWithURI:playlistURI
                                 devicename:devicename
                                 identifier:peripheral.identifier.UUIDString];
        }
        
        // disconnect device
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

@end