//
//  QueryCollection.h
//  SyncManager
//
//  Created by sendbird-young on 2018. 6. 20..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBDBaseChannel;

@protocol QueryCollectionDelegate <NSObject>

- (void)itemsAreLoaded:(nonnull NSArray <SBDBaseChannel *> *)channel;

@end

@interface QueryCollection : NSObject

@property (weak, nullable) id<QueryCollectionDelegate> delegate;

- (nullable instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithQuery:(id _Nonnull)query;
- (void)load;
- (void)updateChannels:(nonnull NSArray <SBDBaseChannel *> *)channels;

@end
