/*
 * NSError+TCPHelper.h
 * TCPHelper
 *
 * Created by Árpád Goretity on 01/01/2012.
 * Released into the public domain
*/

#import <Foundation/Foundation.h>
#import "TCPHelper.h"


@interface NSError (TCPHelper)
- (id) initWithTCPHelperError:(TCPHelperError)code;
@end

