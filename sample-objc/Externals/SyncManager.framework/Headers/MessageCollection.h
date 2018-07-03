//
//  MessageCollection.h
//  SyncManager
//
//  Created by gyuyoung Hwang on 23/06/2018.
//  Copyright © 2018 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBDBaseMessage;

@protocol MessageCollectionDelegate <NSObject>

- (void)itemsAreLoaded:(nonnull NSArray <SBDBaseMessage *> *)messages;

@end

@interface MessageCollection : NSObject

@property (weak, atomic, nullable) id<MessageCollectionDelegate> delegate;
@property (copy, readonly, nonnull) NSString *channelUrl;

+ (void)setLimitOfMessageLoading:(NSUInteger)limit;
- (nullable instancetype)initWithMessages:(nullable NSArray<SBDBaseMessage *> *)messages
                               channelUrl:(nonnull NSString *)channelUrl
                           connectionTime:(NSTimeInterval)connectionTime
NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithChannelUrl:(NSString *)channelUrl
                             connectionTime:(NSTimeInterval)connectionTime;
- (nullable instancetype)init
NS_UNAVAILABLE;

- (void)loadPreviousMessagesFromReferenceTime:(NSTimeInterval)referenceTime;
- (void)loadPreviousMessagesFromReferenceMessageId:(long long)referenceMessageId;

- (void)loadAllMessagesToConnectionTimeFromReferenceTime:(NSTimeInterval)referenceTime;

//@property (strong, readonly, nonnull) NSArray <SBDBaseMessage *> *messages;
//@property (assign, atomic, nullable) SBDBaseMessage *earliestContinuousMessage;
//@property (assign, atomic, getter=isCompletelyContinuous) BOOL continuous;
//
//- (instancetype)initWithChannelUrl:(nonnull NSString *)channelUrl;
//- (void)addMessages:(nonnull NSArray <SBDBaseMessage *> *)messages;
//- (void)addMessages:(nonnull NSArray <SBDBaseMessage *> *)messages
//        continutity:(BOOL)continuity;
//- (void)appendMessage:(nonnull SBDBaseMessage *)message;
//- (void)updateMessage:(nonnull SBDBaseMessage *)message;
//- (void)removeMessage:(long long)messageId;
//- (nonnull NSArray <SBDBaseMessage *> *)messagesBeforeReferenceTime:(NSTimeInterval)referenceTime;
//- (BOOL)hasContinuousMessagesOfCount:(NSUInteger)count
//                              before:(NSTimeInterval)referenceTime;
//- (void)completeContinuity;
//- (void)clearContinuity;

@end
