//
//  MessageManager.h
//  SendBird-iOS
//
//  Created by sendbird-young on 2018. 5. 14..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MessageCollection;

@interface MessageManager : NSObject

+ (nonnull MessageCollection *)createMessageCollectionWithChannelUrl:(nonnull NSString *)channelUrl;
+ (NSTimeInterval)connectedAt;

@end
