//
//  ChannelMessageCollection.h
//  SyncManager
//
//  Created by gyuyoung Hwang on 23/06/2018.
//  Copyright © 2018 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MessageCollection;

@interface ChannelMessageCollection : NSObject

- (nonnull MessageCollection *)messageCollectionWithChannelUrl:(nonnull NSString *)channelUrl;

//@property (strong, readonly, nonnull) NSDictionary <NSString *, MessageCollection *> *channelMessages;
//
//- (void)addMessages:(nonnull NSArray <SBDBaseMessage *> *)messages
//         channelUrl:(nonnull NSString *)channelUrl
//         continuity:(BOOL)continuity;
//- (void)appendMessage:(nonnull SBDBaseMessage *)message;
//- (void)updateMessage:(nonnull SBDBaseMessage *)message;
//- (void)removeMessage:(long long)messageId channelUrl:(nonnull NSString *)channelUrl;
//- (BOOL)hasContinuousMessagesOfCount:(NSUInteger)count before:(NSTimeInterval)referenceTime channelUrl:(nonnull NSString *)channelUrl;
//- (void)clearAllContinuities;
//- (void)removeChannelMessagesWithChannelUrl:(nonnull NSString *)channelUrl;

@end
