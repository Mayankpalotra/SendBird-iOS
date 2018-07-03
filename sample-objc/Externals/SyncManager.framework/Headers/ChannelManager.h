//
//  ChannelManager.h
//  SendBird-iOS
//
//  Created by sendbird-young on 2018. 5. 14..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SBDChannelQuery;
@class QueryCollection;
@class SBDBaseChannel;

@interface ChannelManager : NSObject

+ (nonnull QueryCollection *)createQueryCollectionWithQuery:(id<SBDChannelQuery> _Nonnull)query;
+ (nullable SBDBaseChannel *)channelWithChannelUrl:(nonnull NSString *)channelUrl;

+ (void)updateChannels:(nonnull NSArray <SBDBaseChannel *> *)channels;
+ (void)appendChannels:(nonnull NSArray <SBDBaseChannel *> *)channels;

@end
