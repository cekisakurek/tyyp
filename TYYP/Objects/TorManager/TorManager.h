//
//  TorManager.h
//  Chattor
//
//  Created by Cihan Emre Kisakurek on 30/07/14.
//  Copyright (c) 2014 Cihan Emre Kisakurek. All rights reserved.
//

#import <Foundation/Foundation.h>


#define COOKIES_ALLOW_ALL 0
#define COOKIES_BLOCK_THIRDPARTY 1
#define COOKIES_BLOCK_ALL 2

// Sets "Content-Security-Policy" headers. See ProxyURLController.m
#define CONTENTPOLICY_STRICT 0 // Blocks nearly every CSP type
#define CONTENTPOLICY_BLOCK_CONNECT 1 // Blocks `connect-src` (XHR, CORS, WebSocket)
#define CONTENTPOLICY_PERMISSIVE 2 // Allows all content (DANGEROUS: websockets leak outside tor)

#define UA_SPOOF_UNSET 0
#define UA_SPOOF_WIN7_TORBROWSER 1
#define UA_SPOOF_SAFARI_MAC 2
#define UA_SPOOF_IPHONE 3
#define UA_SPOOF_IPAD 4
#define UA_SPOOF_NO 5

#define DNT_HEADER_UNSET 0
#define DNT_HEADER_CANTRACK 1
#define DNT_HEADER_NOTRACK 2

#define X_DEVICE_IS_IPHONE 0
#define X_DEVICE_IS_IPAD 1
#define X_DEVICE_IS_SIM 2

/** String: Identifier **/
#define DEVICE_IDENTIFIER ( ( IS_IPAD ) ? DEVICE_IPAD : ( IS_IPHONE ) ? DEVICE_IPHONE , DEVICE_SIMULATOR )

/** String: iPhone **/
#define DEVICE_IPHONE @"iPhone"

/** String: iPad **/
#define DEVICE_IPAD @"iPad"

/** String: Device Model **/
#define DEVICE_MODEL ( [[UIDevice currentDevice ] model ] )

/** String: Localized Device Model **/
#define DEVICE_MODEL_LOCALIZED ( [[UIDevice currentDevice ] localizedModel ] )

/** String: Device Name **/
#define DEVICE_NAME ( [[UIDevice currentDevice ] name ] )

/** Double: Device Orientation **/
#define DEVICE_ORIENTATION ( [[UIDevice currentDevice ] orientation ] )

/** String: Simulator **/
#define DEVICE_SIMULATOR @"Simulator"

/** String: Device Type **/
/** Import UIDevice+Extended.h **/
#define DEVICE_TYPE ( [[UIDevice currentDevice ] deviceType ] )

/** BOOL: Detect if device is an iPad **/
#define IS_IPAD ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )

/** BOOL: Detect if device is an iPhone or iPod **/
#define IS_IPHONE ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone )

/** BOOL: IS_RETINA **/
#define IS_RETINA ( [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2 )

/** BOOL: Detect if device is the Simulator **/
#define IS_SIMULATOR ( TARGET_IPHONE_SIMULATOR )

@class TorThread;
typedef enum : NSUInteger {
    TorConnectionStateUndefined,
    TorConnectionStateNotConnected,
    TorConnectionStateConnecting,
    TorConnectionStateConnected,
    TorConnectionStateAuthenticating,
    TorConnectionStateAuthenticated,
    TorConnectionStateRunning
} TorConnectionState;


@interface TorManager : NSObject

@property(assign)TorConnectionState state;
-(void)connectWithHandler:(void(^)(NSError*error))handler;

+ (instancetype)sharedManager;

@property(strong,nonatomic)NSMutableDictionary *settings;
@property(strong)NSMutableArray *whiteListDomains;
@property(strong)NSString *userAgent;
- (NSString *)javascriptInjection ;
@property(strong)TorThread *thread;
@end


@interface TorThread : NSThread
@property(assign)int torControlPort;
@property(assign)int torSocksPort;
-(NSData *)readTorCookie;
@end