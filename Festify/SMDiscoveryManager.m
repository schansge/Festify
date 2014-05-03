//
//  PGDiscoveryManager.m
//  Festify
//
//  Created by Patrik Gebhardt on 14/04/14.
//  Copyright (c) 2014 Patrik Gebhardt. All rights reserved.
//

#import "SMDiscoveryManager.h"
#import "MWLogging.h"

@interface SMDiscoveryManager ()

@property (nonatomic, strong) CBCentralManager* centralManager;
@property (nonatomic, strong) CBPeripheralManager* peripheralManager;
@property (nonatomic, strong) NSMutableArray* discoveredPeripherals;
@property (nonatomic, strong) NSMutableDictionary* peripheralData;
@property (nonatomic, assign, getter = isAdvertising) BOOL advertising;
@property (nonatomic, assign, getter = isDiscovering) BOOL discovering;

@end

@implementation SMDiscoveryManager

// create a singleton instance of discovery manager
+(SMDiscoveryManager*)sharedInstance {
    static SMDiscoveryManager* _sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void) {
        _sharedInstance = [[SMDiscoveryManager alloc] init];
    });
    
    return _sharedInstance;
}

-(id)init {
    if (self = [super init]) {
        // create bluetooth manager and set self as their delegate
        dispatch_queue_t centralManagerQueue = dispatch_queue_create("com.patrikgebhardt.festify.centralManager", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t peripheralManagerQueue = dispatch_queue_create("com.patrikgebhardt.festify.peripheralManager", DISPATCH_QUEUE_SERIAL);
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralManagerQueue];
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:peripheralManagerQueue];

        // init properties
        self.discoveredPeripherals = [NSMutableArray array];
        self.peripheralData = [NSMutableDictionary dictionary];
    }
    
    return self;
}

-(BOOL)advertiseProperty:(NSData*)property {
    // check the bluetooth state
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        return NO;
    }
    
    // stop advertisement, if already running to clear all services
    [self stopAdvertising];
    
    // init peripheral service to advertise playlist uri and device name
    CBMutableCharacteristic* propertyCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:SMDiscoveryManagerPropertyUUIDString]
                                                                                     properties:CBCharacteristicPropertyRead
                                                                                          value:property
                                                                                    permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* devicenameCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:SMDiscoveryManagerDevicenameUUIDString]
                                                                                    properties:CBCharacteristicPropertyRead
                                                                                         value:[[UIDevice currentDevice].name dataUsingEncoding:NSUTF8StringEncoding]
                                                                                   permissions:CBAttributePermissionsReadable];
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SMDiscoveryManagerServiceUUIDString] primary:YES];
    service.characteristics = @[propertyCharacteristic, devicenameCharacteristic];
    [self.peripheralManager addService:service];
    
    // advertise service
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:SMDiscoveryManagerServiceUUIDString]],
                                               CBAdvertisementDataLocalNameKey: [UIDevice currentDevice].name}];
    self.advertising = YES;
    
    // post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:SMDiscoveryManagerDidStartAdvertising object:self];
    
    return YES;
}

-(void)stopAdvertising {
    if (self.isAdvertising) {
        [self.peripheralManager stopAdvertising];
    }
    [self.peripheralManager removeAllServices];
    self.advertising = NO;

    // post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:SMDiscoveryManagerDidStopAdvertising object:self];
}

-(BOOL)startDiscovering {
    // check the bluetooth state
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        return NO;
    }
    
    // scan for festify services
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SMDiscoveryManagerServiceUUIDString]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    self.discovering = YES;
    
    // post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:SMDiscoveryManagerDidStartDiscovering object:self];

    return YES;
}

-(void)stopDiscovering {
    if (self.isDiscovering) {
        [self.centralManager stopScan];
    }
    self.discovering = NO;

    // post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:SMDiscoveryManagerDidStopDiscovering object:self];
}

#pragma mark - CBPeripheralManagerDelegate

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state != CBPeripheralManagerStatePoweredOn && self.isAdvertising) {
        self.advertising = NO;
        [self stopAdvertising];
    }
}

#pragma mark - CBCentralManagerDelegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn && self.isDiscovering) {
        self.discovering = NO;
        [self stopDiscovering];
    }
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
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SMDiscoveryManagerServiceUUIDString]]];
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error) {
        MWLogError(@"%@", error);
    }
    
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
    [self.peripheralData removeObjectForKey:peripheral.identifier.UUIDString];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error) {
        MWLogError(@"%@", error);
    }
    
    // remove peripheral from list
    [self.discoveredPeripherals removeObject:peripheral];
    [self.peripheralData removeObjectForKey:peripheral.identifier.UUIDString];
}

#pragma mark - CBPeripheralDelegate

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        MWLogError(@"%@", error);
        
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    // discover the playlist characteristic
    if (peripheral.services.count != 0) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:SMDiscoveryManagerPropertyUUIDString], [CBUUID UUIDWithString:SMDiscoveryManagerDevicenameUUIDString]]
                                 forService:peripheral.services[0]];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        MWLogError(@"%@", error);
        
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    // read playlist value of the characteristic
    for (CBCharacteristic* characteristic in service.characteristics) {
        [peripheral readValueForCharacteristic:characteristic];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        MWLogError(@"%@", error);

        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    // add dictionary for current peripheral
    if (!self.peripheralData[peripheral.identifier.UUIDString]) {
        self.peripheralData[peripheral.identifier.UUIDString] = [NSMutableDictionary dictionary];
    }

    // save received data to peripheral dictionary
    [self.peripheralData[peripheral.identifier.UUIDString] setValue:[characteristic.value copy]
                                                             forKey:[characteristic.UUID.UUIDString lowercaseString]];

    // check if all data are collected
    if ([self.peripheralData[peripheral.identifier.UUIDString] allKeys].count == 2) {
        // inform delegate about new playlist
        if (self.delegate) {
            NSData* property = [self.peripheralData[peripheral.identifier.UUIDString] objectForKey:SMDiscoveryManagerPropertyUUIDString];
            NSString* devicename = [[NSString alloc] initWithData:self.peripheralData[peripheral.identifier.UUIDString][SMDiscoveryManagerDevicenameUUIDString]
                                                         encoding:NSUTF8StringEncoding];
            [self.delegate discoveryManager:self didDiscoverDevice:devicename withProperty:property];
        }
        
        // disconnect device
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

@end