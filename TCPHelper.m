/*
 * TCPHelper.m
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Released into the public domain
*/

#import "TCPHelper.h"
#import "NSError+TCPHelper.h"
#import "tcpconnect.h"


@implementation TCPHelper

@synthesize	state = state,
		port = port,
		host = host,
		timeout = timeout,
		chunkSize = chunkSize,
		delegate = delegate;

- (id) initWithHost:(NSString *)theHost port:(NSString *)thePort
{
	if ((self = [super init]))
	{
		host = [theHost copy];
		port = [thePort copy];
		state = TCPHelperStateInactive;
		/* default chunk size is 512 kB */
		self.chunkSize = 512 * 1024;
		ioInProgress = NO;
	}
	return self;
}

- (void) dealloc
{
	[self disconnect];
	[host release];
	[port release];
	[super dealloc];
}

- (BOOL) isRunning
{
	return self.state != TCPHelperStateInactive;
}

- (BOOL) isConnected
{
	return self.state == TCPHelperStateServerConnected || self.state == TCPHelperStateClientConnected;
}

- (BOOL) isServer
{
	return self.state == TCPHelperStateServerConnected || self.state == TCPHelperStateServerRunning;
}

- (BOOL) isClient
{
	return self.state == TCPHelperStateClientConnected || self.state == TCPHelperStateClientRunning;
}

- (void) startServer
{
	if ([self isRunning])
	{
		/* don't connect twice (however, we can reconnect,
		even for an other purpose (i. e., server instead of client or
		vice versa) if we have already called -disconnect) */
		return;
	}
	if (![self.port length])
	{
		/* cannot connect without a port */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoHostOrPort];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	
	if (self.timeout > 0)
	{
		[NSTimer scheduledTimerWithTimeInterval:self.timeout target:self selector:@selector(timedOut) userInfo:NULL repeats:NO];
	}
	
	[NSThread detachNewThreadSelector:@selector(startServerInternal) toTarget:self withObject:NULL];
	if ([self.delegate respondsToSelector:@selector(tcpHelperStartedRunning:)])
	{
		[self.delegate tcpHelperStartedRunning:self];
	}
}

- (void) connectToServer
{
	if ([self isRunning])
	{
		/* don't connect twice (however, we can reconnect,
		even for an other purpose (i. e., server instead of client or
		vice versa) if we have already called -disconnect) */
		return;
	}
	if (![self.port length] || ![self.host length])
	{
		/* cannot connect without a port and a host */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)]) {
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoHostOrPort];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (self.timeout > 0)
	{
		[NSTimer scheduledTimerWithTimeInterval:self.timeout target:self selector:@selector(timedOut) userInfo:NULL repeats:NO];
	}
	[NSThread detachNewThreadSelector:@selector(connectToServerInternal) toTarget:self withObject:NULL];
	if ([self.delegate respondsToSelector:@selector(tcpHelperStartedRunning:)])
	{
		[self.delegate tcpHelperStartedRunning:self];
	}
}

- (void) disconnect
{
	if (ioInProgress)
	{
		/* don't disconnect while sending or receiving data */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (self.state == TCPHelperStateInactive)
	{
		/* don't disconnect twice */
		return;
	}
	close(sockfd);
	state = TCPHelperStateInactive;
	if ([self.delegate respondsToSelector:@selector(tcpHelperDisconnected:)])
	{
		[self.delegate tcpHelperDisconnected:self];
	}
}

- (void) receiveData
{
	if (![self isConnected])
	{
		/* can't read() without an open file descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorDisconnected];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (ioInProgress)
	{
		/* can't read() simultaneously from the same descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	ioInProgress = YES;
	[NSThread detachNewThreadSelector:@selector(receiveDataInternal) toTarget:self withObject:NULL];
}

- (void) sendData:(NSData *)data
{
	if (![self isConnected])
	{
		/* can't write() without an open file descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorDisconnected];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (ioInProgress)
	{
		/* can't write() simultaneously from the same descriptor */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorBusy];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	if (!data)
	{
		/* if there's nothing, can't send anything */
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorNoData];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	ioInProgress = YES;
	[NSThread detachNewThreadSelector:@selector(sendDataInternal:) toTarget:self withObject:data];
}

/* Internal helper methods */

- (void) timedOut
{
	if ([self isRunning] && ![self isConnected])
	{
		[self disconnect];
		NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorTimedOut];
		[self.delegate tcpHelper:self errorOccurred:err];
		[err release];
	}
}

- (void) startServerInternal
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	state = TCPHelperStateServerRunning;
	sockfd = tcpconnect_start_server([self.port UTF8String]);
	if (sockfd < 0)
	{
		/* error from socket(), setsockopt(), getaddrinfo(), connect(), bind(), listen() or accept() */
		state = TCPHelperStateInactive;
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorSocket];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	state = TCPHelperStateServerConnected;
	if ([self.delegate respondsToSelector:@selector(tcpHelperConnected:)])
	{
		[self.delegate tcpHelperConnected:self];
	}
	[pool release];
}

- (void) connectToServerInternal
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	state = TCPHelperStateClientRunning;
	sockfd = tcpconnect_start_client([self.host UTF8String], [self.port UTF8String]);
	if (sockfd < 0)
	{
		/* error from socket(), setsockopt(), getaddrinfo(), connect(), bind(), listen() or accept() */
		state = TCPHelperStateInactive;
		if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
		{
			NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorSocket];
			[self.delegate tcpHelper:self errorOccurred:err];
			[err release];
		}
		return;
	}
	state = TCPHelperStateClientConnected;
	if ([self.delegate respondsToSelector:@selector(tcpHelperConnected:)])
	{
		[self.delegate tcpHelperConnected:self];
	}
	[pool release];
}

- (void) receiveDataInternal
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	char *buf = malloc(self.chunkSize);
	ssize_t length = 0;
	do
	{
		/* Be prepared to non-blocking sockets */
		length = read(sockfd, buf, self.chunkSize);
		if (length < 0)
		{
			/* error */
			ioInProgress = NO;
			if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
			{
				NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorIO];
				[self.delegate tcpHelper:self errorOccurred:err];
				[err release];
			}
			free(buf);
			return;
		}
		if ([self.delegate respondsToSelector:@selector(tcpHelper:receivedData:)])
		{
			NSData *data = [[NSData alloc] initWithBytes:buf length:length];
			[self.delegate tcpHelper:self receivedData:data];
			[data release];
		}
	} while (length); /* length == 0 means EOF */
	free(buf);
	ioInProgress = NO;
	if ([self.delegate respondsToSelector:@selector(tcpHelperFinishedReceivingData:)])
	{
		[self.delegate tcpHelperFinishedReceivingData:self];
	}
	[pool release];
}

- (void) sendDataInternal:(NSData *)data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ssize_t length = [data length];
	const char *buf = [data bytes];
	while (length)
	{
		/* Be prepared to non-blocking sockets */
		size_t sendlen = length < self.chunkSize ? length : self.chunkSize;
		ssize_t len_written = write(sockfd, buf, sendlen);
		if (len_written < 0)
		{
			/* error */
			ioInProgress = NO;
			if ([self.delegate respondsToSelector:@selector(tcpHelper:errorOccurred:)])
			{
				NSError *err = [[NSError alloc] initWithTCPHelperError:TCPHelperErrorIO];
				[self.delegate tcpHelper:self errorOccurred:err];
				[err release];
			}
			return;
		}
		if ([self.delegate respondsToSelector:@selector(tcpHelper:sentData:)])
		{
			NSData *subdata = [[NSData alloc] initWithBytes:buf length:len_written];
			[self.delegate tcpHelper:self sentData:subdata];
			[subdata release];
		}
		length -= len_written;
		buf += len_written;
	}
	ioInProgress = NO;
	if ([self.delegate respondsToSelector:@selector(tcpHelperFinishedSendingData:)])
	{
		[self.delegate tcpHelperFinishedSendingData:self];
	}
	[pool release];
}

@end

