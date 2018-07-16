//
//  OpenChannelListViewController.m
//  SendBird-iOS
//
//  Created by Jed Kyung on 9/20/16.
//  Copyright © 2016 SendBird. All rights reserved.
//

#import <SendBirdSDK/SendBirdSDK.h>

#import "OpenChannelListViewController.h"
#import "OpenChannelListTableViewCell.h"
#import "OpenChannelChattingViewController.h"
#import "NSBundle+SendBird.h"
#import "ConnectionManager.h"

#import <SyncManager/SyncManager.h>

@interface OpenChannelListViewController () <ConnectionManagerDelegate, QueryCollectionDelegate>

@property (weak, nonatomic) IBOutlet UINavigationItem *navItem;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) UIRefreshControl *refreshControl;

/**
 *  new properties with channel manager
 */
@property (strong, atomic, nonnull) NSMutableArray<SBDOpenChannel *> *channels;
@property (strong, nonatomic, nullable) QueryCollection *queryCollection;

@end

@implementation OpenChannelListViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil) {
        _channels = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configureView];
    
    [ConnectionManager addConnectionObserver:self];
    if ([SBDMain getConnectState] == SBDWebSocketClosed) {
        [ConnectionManager loginWithCompletionHandler:^(SBDUser * _Nullable user, NSError * _Nullable error) {
            if (error != nil) {
                return;
            }
        }];
    }
    else {
        self.queryCollection.delegate = self;
        [self.queryCollection load];
    }
}

- (void)dealloc {
    [ConnectionManager removeConnectionObserver:self];
    self.queryCollection.delegate = nil;
}

- (void)configureView {
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[OpenChannelListTableViewCell nib] forCellReuseIdentifier:[OpenChannelListTableViewCell cellReuseIdentifier]];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshChannel) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    UIBarButtonItem *negativeLeftSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeLeftSpacer.width = -2;
    UIBarButtonItem *negativeRightSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeRightSpacer.width = -2;
    
    UIBarButtonItem *leftBackItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStyleDone target:self action:@selector(back)];
    UIBarButtonItem *rightCreateOpenChannelItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_plus"] style:UIBarButtonItemStyleDone target:self action:@selector(createOpenChannel)];
    
    self.navItem.leftBarButtonItems = @[negativeLeftSpacer, leftBackItem];
    self.navItem.rightBarButtonItems = @[negativeRightSpacer, rightCreateOpenChannelItem];
}

- (QueryCollection *)queryCollection {
    if (_queryCollection == nil) {
        _queryCollection = [self createQueryCollection];
    }
    return _queryCollection;
}

- (QueryCollection *)createQueryCollection {
    QueryCollection *queryCollection = [ChannelManager createQueryCollectionWithQuery:[self query]];
    return queryCollection;
}

- (id<SBDChannelQuery>)query {
    SBDOpenChannelListQuery *query = [SBDOpenChannel createOpenChannelListQuery];
    query.limit = 20;
    return query;
}

- (void)refreshChannel {
    [self.channels removeAllObjects];
    [self.tableView reloadData];
    [ChannelManager removeQueryCollection:self.queryCollection];
    self.queryCollection = [self createQueryCollection];
    self.queryCollection.delegate = self;
    [self.queryCollection load];
}

- (void)back {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)createOpenChannel {
    CreateOpenChannelViewController *vc = [[CreateOpenChannelViewController alloc] init];
    vc.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:vc animated:NO completion:nil];
    });
}

#pragma mark - CreateOpenChannelViewControllerDelegate
- (void)refreshView:(UIViewController *)vc {
    [self.queryCollection resetWithQuery:[self query]];
    [self.queryCollection load];
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [self.channels[indexPath.row] enterChannelWithCompletionHandler:^(SBDError * _Nullable error) {
        if (error != nil) {
            UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
            [vc addAction:closeAction];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:vc animated:YES completion:nil];
            });
            
            return;
        }
        
        OpenChannelChattingViewController *vc = [[OpenChannelChattingViewController alloc] init];
        vc.channel = self.channels[indexPath.row];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:vc animated:NO completion:nil];
        });
    }];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OpenChannelListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OpenChannelListTableViewCell cellReuseIdentifier]];
    
    [cell setModel:self.channels[indexPath.row]];
    [cell setRow:indexPath.row];
    
    if (self.channels.count > 0 && indexPath.row + 1 == self.channels.count) {
        [self.queryCollection load];
    }
    
    return cell;
}

#pragma mark - Connection Manager Delegate
- (void)didConnect:(BOOL)isReconnection {
    [self.queryCollection load];
}

#pragma mark - Channel Query Collection Delegate
- (void)queryCollection:(QueryCollection *)queryCollection
        itemsAreUpdated:(NSArray<SBDBaseChannel *> *)updatedChannels
                 action:(ChangeLogAction)action
                  error:(NSError *)error {
    if (self.queryCollection != queryCollection) {
        return;
    }
    
    if (error != nil) {
        return;
    }
    
    if (updatedChannels == nil || updatedChannels.count == 0) {
        return;
    }
    
    if (action == ChangeLogActionCleared) {
        [self clearAllChannelsWithCompletionHandler:nil];
        return;
    }
    // get old channels data source
    
    // make updated channels data source
    
    // get change logs between olds and updateds
    NSArray <ChangeLog *> *changeLogs = [Util changeLogsBetweenOldChannels:self.channels
                                                        andUpdatedChannels:updatedChannels
                                                                    action:action
                                                           queryCollection:queryCollection];
    
    // update ui view
    switch (action) {
        case ChangeLogActionNew:
            [self insertChangeLogs:changeLogs completionHandler:nil];
            break;
            
        case ChangeLogActionChanged:
            [self changeChangeLogs:changeLogs completionHandler:nil];
            break;
            
        case ChangeLogActionDeleted:
            [self deleteChangeLogs:changeLogs completionHandler:nil];
            break;
            
        case ChangeLogActionMoved:
            [self moveChangeLogs:changeLogs completionHandler:nil];
            break;
            
        case ChangeLogActionCleared:
        case ChangeLogActionNone:
            break;
    }
    
    [self.refreshControl endRefreshing];
}

#pragma mark - UI Update with Change Log
- (void)performBatchUpdates:(nonnull void (^)(UITableView * _Nonnull tableView))updateProcess
                 completion:(nullable void(^)(BOOL finished))completionHandler {
    if (@available(iOS 11.0, *)) {
        [self.tableView performBatchUpdates:^{
            updateProcess(self.tableView);
        } completion:completionHandler];
    } else {
        // Fallback on earlier versions
        [self.tableView beginUpdates];
        updateProcess(self.tableView);
        [self.tableView endUpdates];
    }
}

- (void)insertChangeLogs:(NSArray <ChangeLog *> *)changeLogs
       completionHandler:(ChattingViewCompletionHandler)completionHandler {
    @synchronized (self.channels) {
        NSMutableArray *indexPaths = [NSMutableArray array];
        for (ChangeLog *changeLog in changeLogs) {
            NSUInteger index = changeLog.index;
            [self.channels insertObject:changeLog.item atIndex:index];
            [indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
        
        [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
            [tableView insertRowsAtIndexPaths:[indexPaths copy] withRowAnimation:UITableViewRowAnimationNone];
        } completion:^(BOOL finished) {
            if (finished && completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

- (void)deleteChangeLogs:(NSArray <ChangeLog *> *)changeLogs
       completionHandler:(ChattingViewCompletionHandler)completionHandler {
    @synchronized (self.channels) {
        NSMutableArray *indexPaths = [NSMutableArray array];
        for (ChangeLog *changeLog in changeLogs) {
            NSUInteger index = changeLog.index;
            [self.channels removeObjectAtIndex:index];
            [indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
        
        [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
            [tableView deleteRowsAtIndexPaths:[indexPaths copy] withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            if (finished && completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

- (void)changeChangeLogs:(NSArray <ChangeLog *> *)changeLogs
       completionHandler:(ChattingViewCompletionHandler)completionHandler {
    @synchronized (self.channels) {
        NSMutableArray *indexPaths = [NSMutableArray array];
        for (ChangeLog *changeLog in changeLogs) {
            NSUInteger index = changeLog.index;
            [self.channels replaceObjectAtIndex:index withObject:changeLog.item];
            [indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
        
        [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
            [tableView reloadRowsAtIndexPaths:[indexPaths copy] withRowAnimation:UITableViewRowAnimationNone];
        } completion:^(BOOL finished) {
            if (finished && completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

- (void)moveChangeLogs:(NSArray <ChangeLog *> *)changeLogs
     completionHandler:(ChattingViewCompletionHandler)completionHandler {
    @synchronized (self.channels) {
        for (ChangeLog *changeLog in changeLogs) {
            NSUInteger atIndex = changeLog.atIndex;
            NSUInteger toIndex = changeLog.toIndex;
            NSIndexPath *atIndexPath = [NSIndexPath indexPathForRow:atIndex inSection:0];
            NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:toIndex inSection:0];
            [self.channels removeObjectAtIndex:atIndex];
            [self.channels insertObject:changeLog.item atIndex:toIndex];
            
            __weak OpenChannelListViewController *weakSelf = self;
            [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
                [tableView moveRowAtIndexPath:atIndexPath toIndexPath:toIndexPath];
            } completion:^(BOOL finished) {
                __strong OpenChannelListViewController *strongSelf = weakSelf;
                [strongSelf performBatchUpdates:^(UITableView * _Nonnull tableView) {
                    [tableView reloadRowsAtIndexPaths:@[toIndexPath] withRowAnimation:UITableViewRowAnimationNone];
                } completion:^(BOOL finished) {
                    if (finished && completionHandler != nil) {
                        completionHandler();
                    }
                }];
            }];
        }
    }
}

- (void)clearAllChannelsWithCompletionHandler:(ChattingViewCompletionHandler)completionHandler {
    @synchronized (self.channels) {
        [self.channels removeAllObjects];
        [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
            [tableView reloadData];
        } completion:^(BOOL finished) {
            if (finished && completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

@end
