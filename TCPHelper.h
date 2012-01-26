/*
 * TCPHelper.h
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Released into the public domain
*/

#import <stdint.h>
#import <Foundation/Foundation.h>

#define TCPHelperErrorDomain @"TCPHelperErrorDomain"
#define TCPHelperErrorDescriptionKey @"TCPHelperErrorDescriptionKey"


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

@protocol TCPHelperDelegate;

@interface TCPHelper: NSObject {
	TCPHelperState state;
	int sockfd;
	NSString *port;
	NSString *host;
	BOOL ioInProgress;
	NSTimeInterval timeout;
	uint32_t chunkSize;
	id <TCPHelperDelegate> delegate;
}

@property (nonatomic, readonly) TCPHelperState state;
@property (nonatomic, readonly) NSString *port;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) uint32_t chunkSize;
@property (nonatomic, assign) id <TCPHelperDelegate> delegate;

- (id) initWithHost:(NSString *)theHost port:(NSString *)thePort;

- (BOOL) isRunning;
- (BOOL) isConnected;
- (BOOL) isServer;
- (BOOL) isClient;

- (void) startServer;
- (void) connectToServer;
- (void) disconnect;

- (void) receiveData;
- (void) sendData:(NSData *)data;

@end


@protocol TCPHelperDelegate <NSObject>
@optional

/*
 * Connection methods
*/
- (void) tcpHelperStartedRunning:(TCPHelper *)helper;
- (void) tcpHelperConnected:(TCPHelper *)helper;
- (void) tcpHelperDisconnected:(TCPHelper *)helper;

/*
 * Progress observation
*/
- (void) tcpHelper:(TCPHelper *)helper receivedData:(NSData *)data;
- (void) tcpHelper:(TCPHelper *)helper sentData:(NSData *)data;

/*
 * Completion methods
*/
- (void) tcpHelperFinishedSendingData:(TCPHelper *)helper;
- (void) tcpHelperFinishedReceivingData:(TCPHelper *)helper;

/*
 * Error handling
*/
- (void) tcpHelper:(TCPHelper *)helper errorOccurred:(NSError *)error;

@end

