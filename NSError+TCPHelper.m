/*
  NSError+TCPHelper.m
  TCPHelper
  
  Created by Árpád Goretity on 01/01/2012.
  Released into the public domain
*/

#import "NSError+TCPHelper.h"


@implementation NSError (TCPHelper)

- (id) initWithTCPHelperError:(TCPHelperError)code
{
	NSString *desc = NULL;
	if (code == TCPHelperErrorSocket)
	{
		desc = NSLocalizedString(@"Error creating a socket. Either insufficient amount of resources is available or the specified host or port name is invalid.", NULL);
	}
	else if (code == TCPHelperErrorBusy)
	{
		desc = NSLocalizedString(@"Currently receiving or sending data, cannot perform multiple read/write operations on the same socket simultaneously. Please wait for the current I/O operation to finish.", NULL);
	}
	else if (code == TCPHelperErrorDisconnected)
	{
		desc = NSLocalizedString(@"The TCPHelper object is disconnected, so it can't perform network opertions. Please start it either in server or in client mode.", NULL);
	}
	else if (code == TCPHelperErrorNoHostOrPort)
	{
		desc = NSLocalizedString(@"No host or port specified. Please assign a valid port number or service name. In case of a client TCPHelper instance, you must also specify a valid host name or IP address.", NULL);
	}
	else if (code == TCPHelperErrorNoData)
	{
		desc = NSLocalizedString(@"Cannot send nil data. Please specify an initialized NSData object to be sent.", NULL);
	}
	else if (code == TCPHelperErrorIO)
	{
		desc = NSLocalizedString(@"I/O error; read() or write() returned -1.", NULL);
	}
	else if (code == TCPHelperErrorTimedOut)
	{
		desc = NSLocalizedString(@"The connection timed out.", NULL);
	}
	else
	{
		desc = NSLocalizedString(@"Unknown TCP error", NULL);
	}
	NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:desc, TCPHelperErrorDescriptionKey, NULL];
	self = [self initWithDomain:TCPHelperErrorDomain code:code userInfo:userInfo];
	[userInfo release];
	return self;
}

@end

