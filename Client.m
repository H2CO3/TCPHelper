/*
 * Client.m
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Launch me using: ./client <servername_or_ip> <port>
 */

@import Foundation;

#import "TCPHelper.h"


@interface Client: NSObject

@property (nonatomic, strong) TCPHelper *tcpHelper;

- (instancetype)initWithHost:(NSString *)host port:(NSString *)port;

@end

@implementation Client

- (instancetype)initWithHost:(NSString *)host port:(NSString *)port {
	if (self = [self init]) {
		self.tcpHelper = [[TCPHelper alloc] initWithHost:host port:port];

		__weak Client *weakSelf = self;

		self.tcpHelper.connectedHandler = ^{
			NSLog(@"Connected on port %@, receiving data...", weakSelf.tcpHelper.port);
			[weakSelf.tcpHelper receiveData];
		};

		self.tcpHelper.disconnectedHandler = ^{
			NSLog(@"Disconnected, exiting.");
			exit(0);
		};

		self.tcpHelper.receivedDataHandler = ^(NSData *data) {
			NSLog(@"Data received: \"%s\" (%zu bytes)", data.bytes, (size_t)[data length]);
		};

		self.tcpHelper.finishedReceivingHandler = ^{
			NSLog(@"Finsihed receiving data! Disconnecting...");
			[weakSelf.tcpHelper disconnect];
		};

		self.tcpHelper.errorHandler = ^(NSError *error) {
			NSLog(@"Error: %@", error);
		};

		[self.tcpHelper startClient];
		NSLog(@"Listening on port %@...", self.tcpHelper.port);
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

		NSString *host = [NSString stringWithUTF8String:argv[1]];
		NSString *port = [NSString stringWithUTF8String:argv[2]];
		Client *client = [[Client alloc] initWithHost:host port:port];

		[rl run];

		return 0;
	}
}
