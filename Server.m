/*
 * Server.m
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Launch me using: ./server <port>
 */

@import Foundation;
#import "TCPHelper.h"

@interface Server: NSObject

@property (nonatomic, strong) TCPHelper *tcpHelper;

- (instancetype)initWithPort:(NSString *)port;

@end

@implementation Server

- (instancetype)initWithPort:(NSString *)port {
	if (self = [self init]) {
		// host can be nil as it will be used as a server
		self.tcpHelper = [[TCPHelper alloc] initWithHost:nil port:port];

		__weak Server *weakSelf = self;

		self.tcpHelper.connectedHandler = ^{
			const char msg[] = "Hello World!";
			NSData *data = [NSData dataWithBytes:msg length:sizeof msg];
			[weakSelf.tcpHelper sendData:data];
		};

		self.tcpHelper.disconnectedHandler = ^{
			NSLog(@"Disconnected, exiting.");
			exit(0);
		};

		self.tcpHelper.sentDataHandler = ^(NSData *data) {
			NSLog(@"Data sent: \"%s\" (%zu bytes)", data.bytes, (size_t)[data length]);
		};

		self.tcpHelper.finishedSendingHandler = ^{
			NSLog(@"Finsihed sending! Disconnecting...");
			[weakSelf.tcpHelper disconnect];
		};

		self.tcpHelper.errorHandler = ^(NSError *error) {
			NSLog(@"Error: %@", error);
		};

		[self.tcpHelper startServer];
		NSLog(@"Listening on port %@", self.tcpHelper.port);
	}
	return self;
}

@end

int main(int argc, char **argv)
{
	@autoreleasepool {
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
    NSTimer *tmr = [[NSTimer alloc] initWithFireDate:[NSDate date]
		                                        interval:60.0
		                                          target:nil
		                                        selector:NULL
		                                        userInfo:nil
		                                         repeats:YES];

		[rl addTimer:tmr forMode:NSDefaultRunLoopMode];

		NSString *port = [NSString stringWithUTF8String:argv[1]]; // ./server 5555
		Server *server = [[Server alloc] initWithPort:port];

		[rl run];

		return 0;
	}
}
