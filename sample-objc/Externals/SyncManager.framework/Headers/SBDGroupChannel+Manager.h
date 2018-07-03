//
//  SBDGroupChannel+Manager.h
//  SendBird-iOS
//
//  Created by gyuyoung Hwang on 2018. 5. 31..
//  Copyright © 2018년 SendBird. All rights reserved.
//

#import <SendBirdSDK/SendBirdSDK.h>
#import "SBDBaseChannel+Manager.h"

@interface SBDGroupChannel (Manager)

- (BOOL)isEqualToChannelMembers:(nonnull SBDGroupChannel *)channel;

@end
