//
//  SBDChannelQuery+Manager.h
//  SyncManager
//
//  Created by sendbird-young on 2018. 6. 21..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SBDChannelQueryCompletionHandler)(NSArray<SBDBaseChannel *> * _Nullable channels, SBDError * _Nullable error);

@protocol SBDChannelQuery <NSObject>

- (BOOL)isEqualToQuery:(id<SBDChannelQuery> _Nonnull)query;
- (nonnull NSPredicate *)predicateFromQuery;
- (void)loadNextPageWithCompletionHandler:(nonnull SBDChannelQueryCompletionHandler)completionHandler;

@end
