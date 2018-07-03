//
//  ChannelContainer.h
//  SyncManager
//
//  Created by sendbird-young on 2018. 6. 20..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBDBaseChannel;

@interface ChannelContainer : NSObject

- (nullable SBDBaseChannel *)channelWithChannelUrl:(nonnull NSString *)channelUrl;
- (void)updateChannels:(nonnull NSArray <SBDBaseChannel *> *)channels;

@end
