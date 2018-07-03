//
//  DataBase.h
//  SendBird-iOS
//
//  Created by sendbird-young on 2018. 5. 16..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBDBaseChannel, SBDBaseMessage;

@interface DataBase : NSObject

+ (void)updateChannelsWithChannels:(nonnull NSArray <SBDBaseChannel *> *)channels;
+ (nonnull NSDictionary <NSString *, SBDBaseChannel *> *)allchannels;
+ (void)deleteChannelUrl:(nonnull NSString *)channelUrl;

+ (void)updateMessages:(nonnull NSArray <SBDBaseMessage *> *)messages
            channelUrl:(nonnull NSString *)channelUrl;
+ (nonnull NSDictionary <NSString *, NSMutableArray <SBDBaseMessage *> *> *)messagesWithChannelUrls:(nonnull NSArray <NSString *> *)channelUrls;

@end
