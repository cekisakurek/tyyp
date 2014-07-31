//
//  TorManager.m
//  Chattor
//
//  Created by Cihan Emre Kisakurek on 30/07/14.
//  Copyright (c) 2014 Cihan Emre Kisakurek. All rights reserved.
//

#import "TorManager.h"
#import "ULINetSocket.h"
#include "or/or.h"
#include "or/main.h"
#import "NSData+Conversion.h"
#import "ProxyURLProtocol.h"
#define STATUS_CHECK_TIMEOUT 3.0f



@interface TorManager ()

@property (strong) NSTimer *torCheckLoopTimer;
@property (strong) NSTimer *torStatusTimeoutTimer;
@property (nonatomic) ULINetSocket	*socket;
@property(assign,getter = isHeartBeating)BOOL heartBeat;
@property(readwrite, copy) void(^handler)(NSError*error);
@end


@implementation TorManager
+ (instancetype)sharedManager
{
    static dispatch_once_t once;
    static TorManager *sharedFoo;
    dispatch_once(&once, ^ { sharedFoo = [[self alloc] init]; });
    return sharedFoo;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        
        self.thread=[[TorThread alloc]init];
        
        self.thread.torControlPort = (arc4random() % (57343-49153)) + 49153;
        self.thread.torSocksPort = (arc4random() % (65534-57344)) + 57344;
        [self setState:TorConnectionStateNotConnected];

    }
    return self;
}
-(void)stop{
    
}
-(void)invalidateTimers{
    if (self.torCheckLoopTimer!=nil) {
        [self.torCheckLoopTimer invalidate];
        self.torCheckLoopTimer=nil;
    }
    if (self.torStatusTimeoutTimer!=nil) {
        [self.torStatusTimeoutTimer invalidate];
        self.torStatusTimeoutTimer=nil;
    }
}
-(void)connectWithHandler:(void(^)(NSError*error))h{

    if (self.state==TorConnectionStateRunning) {
        return;
    }
    [NSURLProtocol registerClass:[ProxyURLProtocol class]];
    [self setHandler:h];
    
    [self invalidateTimers];
    [self.thread start];
    self.torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
    
}
- (void)hupTor {
    [self invalidateTimers];
    
    [self.socket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
    self.torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)requestNewTorIdentity {
#ifdef DEBUG
    NSLog(@"[tor] Requesting new identity (SIGNAL NEWNYM)" );
#endif
    [self.socket writeString:@"SIGNAL NEWNYM\n" encoding:NSUTF8StringEncoding];
}
- (void)activateTorCheckLoop {
#ifdef DEBUG
    NSLog(@"[tor] Checking Tor Control Port" );
#endif
    

    
    [ULINetSocket ignoreBrokenPipes];
    // Create a new ULINetSocket connected to the host. Since ULINetSocket is asynchronous, the socket is not
    // connected to the host until the delegate method is called.
    
    self.socket = [ULINetSocket netsocketConnectedToHost:@"127.0.0.1" port:self.thread.torControlPort];
    
    // Schedule the ULINetSocket on the current runloop
    [self.socket scheduleOnCurrentRunLoop];
    
    // Set the ULINetSocket's delegate to ourself
    [self.socket setDelegate:self];
}

- (void)disableTorCheckLoop {
    // When in background, don't poll the Tor control port.
    [ULINetSocket ignoreBrokenPipes];
    [self.socket close];
    self.socket = nil;
    
    [self.torCheckLoopTimer invalidate];
}

- (void)checkTor {
    if (![self isHeartBeating]) {
        // We haven't loaded a page yet, so we are checking against bootstrap first.
        [self.socket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
    }
    else {
        // This is a "heartbeat" check, so we are checking our circuits.
        [self.socket writeString:@"getinfo orconn-status\n" encoding:NSUTF8StringEncoding];
        if (self.torStatusTimeoutTimer != nil) {
            [self.torStatusTimeoutTimer invalidate];
        }
        self.torStatusTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:STATUS_CHECK_TIMEOUT
                                                                  target:self
                                                                selector:@selector(checkTorStatusTimeout)
                                                                userInfo:nil
                                                                 repeats:NO];
    }
}

- (void)checkTorStatusTimeout {
    // Our orconn-status check didn't return before the alotted timeout.
    // (We're basically giving it STATUS_CHECK_TIMEOUT seconds -- default 1 sec
    // -- since this is a LOCAL port and LOCAL instance of tor, it should be
    // near instantaneous.)
    //
    // Fail: Restart Tor? (Maybe HUP?)
    NSLog(@"[tor] checkTor timed out, attempting to restart tor");
    //[self startTor];
    [self hupTor];
}



- (void)netsocketConnected:(ULINetSocket*)inNetSocket {
    /* Authenticate on first control port connect */
#ifdef DEBUG
    NSLog(@"[tor] Control Port Connected" );
#endif
    NSData *torCookie = [self.thread readTorCookie];
    
    NSString *authMsg = [NSString stringWithFormat:@"authenticate %@\n",
                         [torCookie hexadecimalString]];
    [self.socket writeString:authMsg encoding:NSUTF8StringEncoding];
    

    [self setState:TorConnectionStateAuthenticating];
}


- (void)netsocketDisconnected:(ULINetSocket*)inNetSocket {
#ifdef DEBUG
    NSLog(@"[tor] Control Port Disconnected" );
#endif
    
    // Attempt to reconnect the netsocket
    [self disableTorCheckLoop];
    [self activateTorCheckLoop];
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *msgIn = [self.socket readString:NSUTF8StringEncoding];
    
    if ([self state]==TorConnectionStateAuthenticating) {
        // Response to AUTHENTICATE
        if ([msgIn hasPrefix:@"250"]) {
#ifdef DEBUG
            NSLog(@"[tor] Control Port Authenticated Successfully" );
#endif

            [self setState:TorConnectionStateAuthenticated];
            
            [self.socket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
            self.torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
        else {
#ifdef DEBUG
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", msgIn);
#endif
            // Could not authenticate with control port. This is the worst thing
            // that can happen on app init and should fail badly so that the
            // app does not just hang there.
            if ([self isHeartBeating]) {
                // If we've already performed initial connect, wait a couple
                // seconds and try to HUP tor.
                if (_torCheckLoopTimer != nil) {
                    [_torCheckLoopTimer invalidate];
                }
                if (_torStatusTimeoutTimer != nil) {
                    [_torStatusTimeoutTimer invalidate];
                }
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:2.5f
                                                                      target:self
                                                                    selector:@selector(hupTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            } else {
                // Otherwise, crash because we don't know the app's current state
                // (since it hasn't totally initialized yet).
                exit(0);
            }
        }
    } else if ([msgIn rangeOfString:@"-status/bootstrap-phase="].location != NSNotFound) {
        // Response to "getinfo status/bootstrap-phase"
        
        if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
            [self setState:TorConnectionStateRunning];
            if (self.handler) {
                self.handler(nil);
            }
            

        }
        
        if (![self isHeartBeating]) {
            if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
                // This is our first go-around (haven't loaded page into webView yet)
                // but we are now at 100%, so go ahead.
                [self setHeartBeat:YES];

                
                // See "checkTor call in middle of app" a little bit below.
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            } else {
                // Haven't done initial load yet and still waiting on bootstrap, so
                // render status.
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            }
        }
    } else if ([msgIn rangeOfString:@"+orconn-status="].location != NSNotFound) {
        [_torStatusTimeoutTimer invalidate];
        
        // Response to "getinfo orconn-status"
        // This is a response to a "checkTor" call in the middle of our app.
        if ([msgIn rangeOfString:@"250 OK"].location == NSNotFound) {
            // Bad stuff! Should HUP since this means we can still talk to
            // Tor, but Tor is having issues with it's onion routing connections.
            NSLog(@"[tor] Control Port: orconn-status: NOT OK\n    %@",
                  [msgIn
                   stringByReplacingOccurrencesOfString:@"\n"
                   withString:@"\n    "]
                  );
            
            [self hupTor];
        } else {
#ifdef DEBUG
            NSLog(@"[tor] Control Port: orconn-status: OK");
#endif
            self.torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }
- (NSString *)customUserAgent {
    Byte uaspoof = [[self.settings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14";
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        return @"Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0";
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        return @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53";
    } else if (uaspoof == UA_SPOOF_IPAD) {
        return @"Mozilla/5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53";
    }
    return nil;
}
- (NSString *)javascriptInjection {
    NSMutableString *str = [[NSMutableString alloc] init];
    
    Byte uaspoof = [[self.settings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'MacIntel';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14';});"];
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Windows)';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'Win32';});"];
        [str appendString:@"navigator.__defineGetter__('language',function(){return 'en-US';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0';});"];
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPhone';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
    } else if (uaspoof == UA_SPOOF_IPAD) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPad';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
    }
    
    Byte activeContent = [[self.settings valueForKey:@"javascript"] integerValue];
    if (activeContent != CONTENTPOLICY_PERMISSIVE) {
        [str appendString:@"function Worker(){};"];
        [str appendString:@"function WebSocket(){};"];
        [str appendString:@"function sessionStorage(){};"];
        [str appendString:@"function localStorage(){};"];
        [str appendString:@"function globalStorage(){};"];
        [str appendString:@"function openDatabase(){};"];
    }
    return str;
}
- (NSMutableDictionary *)settings {
    NSString *errorDesc = nil;
    NSPropertyListFormat format;
    NSMutableDictionary *d;
    
    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:@"asd"];
    if (plistXML == nil) {
        // We didn't have a settings file, so we'll want to initialize one now.
        d = [NSMutableDictionary dictionary];
    } else {
        d = (NSMutableDictionary *)[NSPropertyListSerialization
                                    propertyListFromData:plistXML
                                    mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                    format:&format errorDescription:&errorDesc];
    }
    
    // SETTINGS DEFAULTS
    // we do this here in case the user has an old version of the settings file and we've
    // added new keys to settings. (or if they have no settings file and we're initializing
    // from a blank slate.)
    Boolean update = NO;
    if ([d objectForKey:@"homepage"] == nil) {
        [d setObject:@"onionbrowser:home" forKey:@"homepage"]; // DEFAULT HOMEPAGE
        update = YES;
    }
    if ([d objectForKey:@"cookies"] == nil) {
        [d setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"cookies"];
        update = YES;
    }
    if (([d objectForKey:@"uaspoof"] == nil) || ([[d objectForKey:@"uaspoof"] integerValue] == UA_SPOOF_UNSET)) {
        if (IS_IPAD) {
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
        } else {
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
        }
        update = YES;
    }
    if ([d objectForKey:@"dnt"] == nil) {
        [d setObject:[NSNumber numberWithInteger:DNT_HEADER_UNSET] forKey:@"dnt"];
        update = YES;
    }
    if ([d objectForKey:@"javascript"] == nil) { // for historical reasons, CSP setting is named "javascript"
        [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
        update = YES;
    }

    
    return d;
}
@end



@implementation TorThread

-(NSData *)readTorCookie {
    /* We have the CookieAuthentication ControlPort method set up, so Tor
     * will create a "control_auth_cookie" in the data dir. The contents of this
     * file is the data that AppDelegate will use to communicate back to Tor. */
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *control_auth_cookie = [tmpDir stringByAppendingPathComponent:@"control_auth_cookie"];
    
    NSData *cookie = [[NSData alloc] initWithContentsOfFile:control_auth_cookie];
    return cookie;
}

-(void)main {
//    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSString *tmpDir = NSTemporaryDirectory();
    
    //NSString *base_torrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    
    
    NSString *base_torrc =[[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSString *geoip = [[NSBundle mainBundle] pathForResource:@"geoip" ofType:nil];
    
    NSString *controlPortStr = [NSString stringWithFormat:@"%ld", (unsigned long)self.torControlPort];
    NSString *socksPortStr = [NSString stringWithFormat:@"%ld", (unsigned long)self.torSocksPort];
    
    //NSLog(@"%@ / %@", controlPortStr, socksPortStr);
    
    /**************/
    
    char *arg_0 = "tor";
    
    // These options here (and not in torrc) since we don't know the temp dir
    // and data dir for this app until runtime.
    char *arg_1 = "DataDirectory";
    char *arg_2 = (char *)[tmpDir cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_3 = "ControlPort";
    char *arg_4 = (char *)[controlPortStr cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_5 = "SocksPort";
    char *arg_6 = (char *)[socksPortStr cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_7 = "GeoIPFile";
    char *arg_8 = (char *)[geoip cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_9 = "-f";
    char *arg_10 = (char *)[base_torrc cStringUsingEncoding:NSUTF8StringEncoding];
    
    // Set loglevel based on compilation option (loglevel "notice" for debug,
    // loglevel "warn" for release). Debug also will receive "DisableDebuggerAttachment"
    // torrc option (which allows GDB/LLDB to attach to the process).
    char *arg_11 = "Log";
    
#ifndef DEBUG
    char *arg_12 = "warn stderr";
#endif
#ifdef DEBUG
    char *arg_12 = "notice stderr";
#endif
    char* argv[] = {arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, arg_7, arg_8, arg_9, arg_10, arg_11, arg_12, NULL};
    tor_main(13, argv);
}


@end
