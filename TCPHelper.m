/*
 * TCPHelper.m
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Released into the public domain
 */

#import <dispatch/dispatch.h>

#import "TCPHelper.h"
#import "tcpconnect.h"


@interface TCPHelper()

@property (nonatomic, readwrite, assign) TCPHelperState state;
@property (nonatomic, readwrite, copy) NSString *port;
@property (nonatomic, readwrite, copy) NSString *host;

@property (nonatomic, assign) int sockfd;
@property (nonatomic, assign) BOOL ioInProgress;

@end

@implementation TCPHelper

- (instancetype)initWithHost:(NSString *)theHost port:(NSString *)thePort {
	if ((self = [super init])) {
		self.host = theHost;
		self.port = thePort;
		self.state = TCPHelperStateInactive;
		/* default chunk size is 512 kB */
		self.chunkSize = 512 * 1024;
		self.ioInProgress = NO;
	}
	return self;
}

- (void)dealloc {
	[self disconnect];
}

- (BOOL)isRunning {
	return self.state != TCPHelperStateInactive;
}

- (BOOL)isConnected {
	return self.state == TCPHelperStateServerConnected
	    || self.state == TCPHelperStateClientConnected;
}

- (BOOL)isServer {
	return self.state == TCPHelperStateServerConnected
	    || self.state == TCPHelperStateServerRunning;
}

- (BOOL)isClient {
	return self.state == TCPHelperStateClientConnected
	    || self.state == TCPHelperStateClientRunning;
}

- (void)startServer {
	// don't connect twice (however, we can reconnect,
	// even for an other purpose (i. e., server instead of client or
	// vice versa) if we have already called -disconnect)
	if ([self isRunning]) {
		return;
	}

	if (self.port.length == 0) {
		// cannot connect without a port
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorNoHostOrPort
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (self.timeout > 0) {
		[NSTimer scheduledTimerWithTimeInterval:self.timeout
																		 target:self
																	 selector:@selector(timedOut)
																	 userInfo:nil
																		repeats:NO];
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self startServerInternal];
	});
}

- (void)startClient {
	if ([self isRunning]) {
		// don't connect twice (however, we can reconnect,
		// even for an other purpose (i. e., server instead of client or
		// vice versa) if we have already called -disconnect)
		return;
	}

	if (self.port.length == 0 || self.host.length == 0) {
		// cannot connect without a port and a host
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorNoHostOrPort
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (self.timeout > 0) {
		[NSTimer scheduledTimerWithTimeInterval:self.timeout
																		 target:self
																	 selector:@selector(timedOut)
																	 userInfo:nil
																		repeats:NO];
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self startClientInternal];
	});
}

- (void)disconnect {
	if (self.ioInProgress) {
		// don't disconnect while sending or receiving data
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorBusy
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (self.state == TCPHelperStateInactive) {
		// don't disconnect twice
		return;
	}

	close(self.sockfd);
	self.state = TCPHelperStateInactive;

	if (self.disconnectedHandler) {
		self.disconnectedHandler();
	}
}

- (void)receiveData {
	if ([self isConnected] == NO) {
		// can't read() without an open file descriptor
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				code:TCPHelperErrorDisconnected
																		userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (self.ioInProgress) {
		// can't read() simultaneously from the same descriptor
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorBusy
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	self.ioInProgress = YES;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self receiveDataInternal];
	});

}

- (void)sendData:(NSData *)data {
	if ([self isConnected] == NO) {
		// can't write() without an open file descriptor
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorDisconnected
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (self.ioInProgress) {
		// can't write() simultaneously from the same descriptor
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorBusy
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	if (data == nil) {
		// if there's nothing, can't send anything
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorNoData
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	self.ioInProgress = YES;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self sendDataInternal:data];
	});
}

//
// Internal helper methods
//

- (void)timedOut {
	if ([self isRunning] && [self isConnected] == NO) {
		[self disconnect];
		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																			 code:TCPHelperErrorTimedOut
																	 userInfo:nil];
			self.errorHandler(err);
		}
	}
}

- (void)startServerInternal {
	self.state = TCPHelperStateServerRunning;
	self.sockfd = tcpconnect_start_server(self.port.UTF8String);

	if (self.sockfd < 0) {
		// error from socket(), setsockopt(), getaddrinfo(),
		// connect(), bind(), listen() or accept()
		self.state = TCPHelperStateInactive;

		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorSocket
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	self.state = TCPHelperStateServerConnected;

	if (self.connectedHandler) {
		self.connectedHandler();
	}
}

- (void)startClientInternal {
	self.state = TCPHelperStateClientRunning;
	self.sockfd = tcpconnect_start_client(self.host.UTF8String, self.port.UTF8String);

	if (self.sockfd < 0) {
		// error from socket(), setsockopt(), getaddrinfo(),
		// connect(), bind(), listen() or accept()
		self.state = TCPHelperStateInactive;

		if (self.errorHandler) {
			NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																				 code:TCPHelperErrorSocket
																		 userInfo:nil];
			self.errorHandler(err);
		}
		return;
	}

	self.state = TCPHelperStateClientConnected;

	if (self.connectedHandler) {
		self.connectedHandler();
	}
}

- (void)receiveDataInternal {
	char *buf = malloc(self.chunkSize);
	ssize_t length = 0;

	do {
		// Be prepared to non-blocking sockets
		length = read(self.sockfd, buf, self.chunkSize);
		if (length < 0) {
			// error
			self.ioInProgress = NO;
			if (self.errorHandler) {
				NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																					 code:TCPHelperErrorIO
																			 userInfo:nil];
				self.errorHandler(err);
			}

			free(buf);
			return;
		}

		if (length > 0 && self.receivedDataHandler) {
			NSData *data = [NSData dataWithBytes:buf length:length];
			self.receivedDataHandler(data);
		}
	} while (length); /* length == 0 means EOF */

	free(buf);
	self.ioInProgress = NO;

	if (self.finishedReceivingHandler) {
		self.finishedReceivingHandler();
	}
}

- (void)sendDataInternal:(NSData *)data {
	ssize_t length = data.length;
	const char *buf = data.bytes;

	while (length) {
		// Be prepared to non-blocking sockets
		size_t sendlen = length < self.chunkSize ? length : self.chunkSize;
		ssize_t len_written = write(self.sockfd, buf, sendlen);

		if (len_written < 0) {
			// error
			self.ioInProgress = NO;
			if (self.errorHandler) {
				NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain
																					 code:TCPHelperErrorIO
																			 userInfo:nil];
				self.errorHandler(err);
			}
			return;
		}

		if (self.sentDataHandler) {
			NSData *data = [NSData dataWithBytes:buf length:len_written];
			self.sentDataHandler(data);
		}

		length -= len_written;
		buf += len_written;
	}

	self.ioInProgress = NO;
	if (self.finishedSendingHandler) {
		self.finishedSendingHandler();
	}
}

@end
