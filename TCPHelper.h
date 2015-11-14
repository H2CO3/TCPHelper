/*
 * TCPHelper.h
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Released into the public domain
 */

@import Foundation;

#import <stdint.h>


typedef enum {
	TCPHelperStateInactive,
	TCPHelperStateServerRunning,
	TCPHelperStateServerConnected,
	TCPHelperStateClientRunning,
	TCPHelperStateClientConnected
} TCPHelperState;

typedef enum {
	TCPHelperErrorSocket = 1,
	TCPHelperErrorBusy = 2,
	TCPHelperErrorDisconnected = 3,
	TCPHelperErrorNoHostOrPort = 4,
	TCPHelperErrorNoData = 5,
	TCPHelperErrorIO = 6,
	TCPHelperErrorTimedOut = 7
} TCPHelperError;


@interface TCPHelper: NSObject

@property (nonatomic, readonly) TCPHelperState state;
@property (nonatomic, readonly, copy) NSString *port;
@property (nonatomic, readonly, copy) NSString *host;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) uint32_t chunkSize;

// All callbacks are optional
@property (nonatomic, copy) void (^connectedHandler)(void);
@property (nonatomic, copy) void (^disconnectedHandler)(void);

@property (nonatomic, copy) void (^receivedDataHandler)(NSData *);
@property (nonatomic, copy) void (^sentDataHandler)(NSData *);

@property (nonatomic, copy) void (^finishedSendingHandler)(void);
@property (nonatomic, copy) void (^finishedReceivingHandler)(void);

@property (nonatomic, copy) void (^errorHandler)(NSError *);

- (instancetype)initWithHost:(NSString *)theHost port:(NSString *)thePort;

- (BOOL)isRunning;
- (BOOL)isConnected;
- (BOOL)isServer;
- (BOOL)isClient;

- (void)startServer;
- (void)startClient;
- (void)disconnect;

- (void)receiveData;
- (void)sendData:(NSData *)data;

@end
