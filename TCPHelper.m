/*
  TCPHelper.m
  TCPHelper
  
  Created by Árpád Goretity on 01/01/2012.
  Released into the public domain
*/

#import "TCPHelper.h"
#import "NSError+TCPHelper.h"
#import "tcpconnect.h"


@implementation TCPHelper

@synthesize state;
@synthesize port;
@synthesize host;
@synthesize delegate;

- (id) initWithHost:(NSString *)theHost port:(NSString *)thePort {
	self = [super init];
	host = [theHost copy];
	port = [thePort copy];
	state = TCPHelperStateInactive;
	ioInProgress = NO;
	return self;
}

- (void) dealloc {
	[self disconnect];
	[host release];
	[port release];
	[super dealloc];
}

- (BOOL) isRunning {
	return self.state != TCPHelperStateInactive;
}

- (BOOL) isConnected {
	return self.state == TCPHelperStateServerConnected || self.state == TCPHelperStateClientConnected;
}

- (BOOL) isServer {
	return self.state == TCPHelperStateServerConnected || self.state == TCPHelperStateServerRunning;
}

- (BOOL) isClient {
	return self.state == TCPHelperStateClientConnected || self.state == TCPHelperStateClientRunning;
}

- (void) startServer {
	if ([self isRunning]) {
		/* don't connect twice (however, we can reconnect,
		even for an other purpose (i. e., server instead of client or
		vice versa) if we have already called -disconnect) */
		return;
	}
	if (![self.port length]) {
		/* cannot connect without a port */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoHostOrPort];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	[self performSelector:@selector(startServerInternal) withObject:NULL afterDelay:0.0];
}

- (void) connectToServer {
	if ([self isRunning]) {
		/* don't connect twice (however, we can reconnect,
		even for an other purpose (i. e., server instead of client or
		vice versa) if we have already called -disconnect) */
		return;
	}
	if (![self.port length] || ![self.host length]) {
		/* cannot connect without a port and a host */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoHostOrPort];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	[self performSelector:@selector(connectToServerInternal) withObject:NULL afterDelay:0.0];
}

- (void) disconnect {
	if (ioInProgress) {
		/* don't disconnect while sending or receiving data */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (self.state == TCPHelperStateInactive) {
		/* don't disconnect twice */
		return;
	}
	close(sockfd);
	state = TCPHelperStateInactive;
	if ([self.delegate respondsToSelector:@selector(tcpHelperDisconnected:)]) {
		[self.delegate tcpHelperDisconnected:self];
	}
}

- (void) receiveDataOfMaxLength:(size_t)length {
	if (![self isConnected]) {
		/* can't read() without an open file descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorDisconnected];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (ioInProgress) {
		/* can't read() simultaneously from the same descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	ioInProgress = YES;
	NSNumber *num = [[NSNumber alloc] initWithUnsignedInt:length];
	[self performSelector:@selector(receiveDataInternal:) withObject:num afterDelay:0.0];
	[num release];
}

- (void) sendData:(NSData *)data {
	if (![self isConnected]) {
		/* can't write() without an open file descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorDisconnected];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (ioInProgress) {
		/* can't write() simultaneously from the same descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (!data) {
		/* if there's nothing, can't send anything */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoData];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	ioInProgress = YES;
	[self performSelector:@selector(sendDataInternal:) withObject:data afterDelay:0.0];
}

/* Internal helper methods */

- (void) startServerInternal {
	state = TCPHelperStateServerRunning;
	if ([self.delegate respondsToSelector:@selector(tcpHelperStartedRunning:)]) {
		[self.delegate tcpHelperStartedRunning:self];
	}
	sockfd = tcpconnect_start_server([self.port UTF8String]);
	if (sockfd < 0) {
		/* error from socket(), setsockopt(), getaddrinfo(), connect(), bind(), listen() or accept() */
		state = TCPHelperStateInactive;
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorSocket];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	state = TCPHelperStateServerConnected;
	if ([self.delegate respondsToSelector:@selector(tcpHelperConnected:)]) {
		[self.delegate tcpHelperConnected:self];
	}
}

- (void) connectToServerInternal {
	state = TCPHelperStateClientRunning;
	if ([self.delegate respondsToSelector:@selector(tcpHelperStartedRunning:)]) {
		[self.delegate tcpHelperStartedRunning:self];
	}
	sockfd = tcpconnect_start_client([self.host UTF8String], [self.port UTF8String]);
	if (sockfd < 0) {
		/* error from socket(), setsockopt(), getaddrinfo(), connect(), bind(), listen() or accept() */
		state = TCPHelperStateInactive;
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorSocket];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	state = TCPHelperStateClientConnected;
	if ([self.delegate respondsToSelector:@selector(tcpHelperConnected:)]) {
		[self.delegate tcpHelperConnected:self];
	}
}

- (void) receiveDataInternal:(NSNumber *)num {
	size_t max_len = [num unsignedIntValue];
	char *buf = malloc(max_len);
	size_t length = read(sockfd, buf, max_len);
	NSData *data = [NSData dataWithBytes:buf length:length];
	free(buf);
	ioInProgress = NO;
	if ([self.delegate respondsToSelector:@selector(tcpHelper:receivedData:)]) {
		[self.delegate tcpHelper:self receivedData:data];
	}
}

- (void) sendDataInternal:(NSData *)data {
	write(sockfd, [data bytes], [data length]);
	ioInProgress = NO;
	if ([self.delegate respondsToSelector:@selector(tcpHelper:sentData:)]) {
		[self.delegate tcpHelper:self sentData:data];
	}
}

@end

