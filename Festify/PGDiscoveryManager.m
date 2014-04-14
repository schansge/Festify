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

@end

@implementation PGDiscoveryManager

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
        dispatch_queue_t peripheralManagerQueue = dispatch_queue_create("com.patrikgebhardt.festify.centralManager", DISPATCH_QUEUE_SERIAL);
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralManagerQueue];
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:peripheralManagerQueue];
        
        self.discoveredPeripherals = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void)startAdvertisingPlaylist:(SPTPartialPlaylist*)playlist withSession:(SPTSession *)session {
    // init peripheral service
    CBMutableCharacteristic* characteristic = [[CBMutableCharacteristic alloc] initWithType:self.serviceUUID properties:CBCharacteristicPropertyRead value:[[playlist.uri absoluteString] dataUsingEncoding:NSUTF8StringEncoding] permissions:CBAttributePermissionsReadable];
    CBMutableService* service = [[CBMutableService alloc] initWithType:self.serviceUUID primary:YES];
    service.characteristics = @[characteristic];
    [self.peripheralManager addService:service];
    
    // advertise service
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[self.serviceUUID],
                                               CBAdvertisementDataLocalNameKey: session.canonicalUsername}];
}

-(void)stopAdvertisingPlaylists {
    [self.peripheralManager stopAdvertising];
}

-(void)startDiscoveringPlaylists {
    // scan for festify services
    [self.centralManager scanForPeripheralsWithServices:@[self.serviceUUID]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
}

-(void)stopDiscoveringPlaylists {
    [self.centralManager stopScan];
}

#pragma mark - CBPeripheralManagerDelegate

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
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
    [peripheral discoverServices:@[self.serviceUUID]];
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
}

#pragma mark - CBPeripheralDelegate

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // discover the playlist characteristic
    [peripheral discoverCharacteristics:@[self.serviceUUID] forService:peripheral.services[0]];
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    // read playlist value of the characteristic
    [peripheral readValueForCharacteristic:service.characteristics[0]];
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    // get playlist URI
    NSURL* playlistURI = [NSURL URLWithString:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
                          
    // inform delegate about new playlist
    if (self.delegate) {
        [self.delegate discoveryManager:self didDiscoverPlaylistWithURI:playlistURI];
    }
}

@end