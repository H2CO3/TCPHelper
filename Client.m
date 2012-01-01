//
// Client.m
// Example code for TCPHelper
//
// Created by Árpád Goretity on 01/01/2012.
// Launch me using: ./client <servername_or_ip> <port>
//

#import <Foundation/Foundation.h>
#import "TCPHelper.h"

@interface Client: NSObject <TCPHelperDelegate> {
	TCPHelper *tcpHelper;
}

- (id) initWithHost:(NSString *)host port:(NSString *)port;

@end

@implementation Client

- (id) initWithHost:(NSString *)host port:(NSString *)port {
	self = [self init];
	tcpHelper = [[TCPHelper alloc] initWithHost:host port:port];
	tcpHelper.delegate = self;
	[tcpHelper connectToServer];
	return self;
}

- (void) dealloc {
	[tcpHelper release];
	[super dealloc];
}

// TCPHelperDelegate

- (void) tcpHelperStartedRunning:(TCPHelper *)helper {
	NSLog(@"Listening on port %@", helper.port);
}

- (void) tcpHelperConnected:(TCPHelper *)helper {
	NSLog(@"Connected on port %@, receiving data...", helper.port);
	[helper receiveDataOfMaxLength:64];
}

- (void) tcpHelper:(TCPHelper *)helper receivedData:(NSData *)data {
	NSLog(@"Data received: %s (%d bytes) - disconnecting.", (char *)[data bytes], [data length]);
	[helper disconnect];
}

- (void) tcpHelperDisconnected:(TCPHelper *)helper {
	NSLog(@"Disconnected, exiting.");
	exit(0);
}

@end

int main(int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSRunLoop *rl = [NSRunLoop currentRunLoop];
	NSDate *now = [[NSDate alloc] init];
	// keep the run loop alive
	NSTimer *tmr = [[NSTimer alloc] initWithFireDate:now interval:60.0 target:NULL selector:NULL userInfo:NULL repeats:YES];
	[now release];
	[rl addTimer:tmr forMode:NSDefaultRunLoopMode];
	[tmr release];
	NSString *host = [NSString stringWithUTF8String:argv[1]];
	NSString *port = [NSString stringWithUTF8String:argv[2]]; // ./server example.com 5555
	Client *client = [[Client alloc] initWithHost:host port:port];
	[rl run];
	[pool release];
	return 0;
}

