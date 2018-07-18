//
//  GroupChannelListViewController.m
//  SendBird-iOS
//
//  Created by Jed Kyung on 9/20/16.
//  Copyright © 2016 SendBird. All rights reserved.
//

#import <MGSwipeTableCell/MGSwipeButton.h>

#import "GroupChannelListViewController.h"
#import "GroupChannelListTableViewCell.h"
#import "GroupChannelListEditableTableViewCell.h"
#import "GroupChannelChattingViewController.h"
#import "NSBundle+SendBird.h"
#import "Constants.h"
#import "Utils.h"
#import "ConnectionManager.h"

#import <SyncManager/SyncManager.h>

@interface GroupChannelListViewController () <ConnectionManagerDelegate, QueryCollectionDelegate>
@property (weak, nonatomic) IBOutlet UILabel *noChannelLabel;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItem;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) UIRefreshControl *refreshControl;

@property (strong, atomic, nonnull) NSMutableArray<SBDGroupChannel *> *channels;

@property (atomic) BOOL editableChannel;
@property (strong, nonatomic) NSMutableArray<NSString *> *typingAnimationChannelList;

/**
 *  new properties with channel manager
 */
@property (strong, nonatomic, nullable) QueryCollection *queryCollection;

@end

@implementation GroupChannelListViewController

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
    
    self.editableChannel = NO;
    
    self.typingAnimationChannelList = [[NSMutableArray alloc] init];
    self.noChannelLabel.hidden = YES;
    
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

- (void)configureView {
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.editing = NO;
    [self.tableView registerNib:[GroupChannelListTableViewCell nib] forCellReuseIdentifier:[GroupChannelListTableViewCell cellReuseIdentifier]];
    [self.tableView registerNib:[GroupChannelListEditableTableViewCell nib] forCellReuseIdentifier:[GroupChannelListEditableTableViewCell cellReuseIdentifier]];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshChannel) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    [self setDefaultNavigationItems];
}

- (void)dealloc {
    [ConnectionManager removeConnectionObserver:self];
    self.queryCollection.delegate = nil;
}

- (void)setDefaultNavigationItems {
    UIBarButtonItem *negativeLeftSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeLeftSpacer.width = -2;
    UIBarButtonItem *negativeRightSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeRightSpacer.width = -2;
    
    UIBarButtonItem *leftBackItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStyleDone target:self action:@selector(back)];
    UIBarButtonItem *rightCreateGroupChannelItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_plus"] style:UIBarButtonItemStyleDone target:self action:@selector(createGroupChannel)];
    UIBarButtonItem *rightEditItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_edit"] style:UIBarButtonItemStyleDone target:self action:@selector(editGroupChannel)];
    rightEditItem.imageInsets = UIEdgeInsetsMake(0, 14, 0, -14);
    
    self.navItem.leftBarButtonItems = @[negativeLeftSpacer, leftBackItem];
    self.navItem.rightBarButtonItems = @[negativeRightSpacer, rightCreateGroupChannelItem, rightEditItem];
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
    SBDGroupChannelListQuery *query = [SBDGroupChannel createMyGroupChannelListQuery];
    query.limit = 10;
    query.order = SBDGroupChannelListOrderLatestLastMessage;
    return query;
}

- (void)refreshChannel {
    [self.queryCollection resetWithQuery:[self query]];
    [self.queryCollection load];
}

- (void)back {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)createGroupChannel {
    CreateGroupChannelUserListViewController *vc = [[CreateGroupChannelUserListViewController alloc] init];
    vc.delegate = self;
    vc.userSelectionMode = 0;
    [self presentViewController:vc animated:NO completion:nil];
}

- (void)editGroupChannel {
    self.editableChannel = YES;
    [self setEditableNavigationItems];
    [self.tableView reloadData];
}

- (void)setEditableNavigationItems {
    UIBarButtonItem *negativeLeftSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeLeftSpacer.width = -2;
    
    UIBarButtonItem *leftDoneItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle sbLocalizedStringForKey:@"DoneButton"] style:UIBarButtonItemStylePlain target:self action:@selector(done)];
    [leftDoneItem setTitleTextAttributes:@{NSFontAttributeName: [Constants navigationBarButtonItemFont]} forState:UIControlStateNormal];
    
    self.navItem.leftBarButtonItems = @[negativeLeftSpacer, leftDoneItem];
    self.navItem.rightBarButtonItems = @[];
}

- (void)done {
    self.editableChannel = NO;
    [self setDefaultNavigationItems];
    [self.tableView reloadData];
}

- (void)hideEmptyTableStyle {
    if (self.channels.count > 0 && self.noChannelLabel.hidden) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.noChannelLabel.hidden = YES;
    }
}

- (void)showEmptyTableStyle {
    if (self.channels.count == 0 && !self.noChannelLabel.hidden) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.noChannelLabel.hidden = NO;
    }
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 90;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 90;
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
    if (self.editableChannel == NO) {
        GroupChannelChattingViewController *vc = [[GroupChannelChattingViewController alloc] init];
        vc.channel = self.channels[indexPath.row];

        [self presentViewController:vc animated:NO completion:nil];
    }
    else {
        MGSwipeTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [cell showSwipe:MGSwipeDirectionRightToLeft animated:YES];
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.channels count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MGSwipeTableCell *cell = nil;
    if (self.editableChannel) {
        cell = [tableView dequeueReusableCellWithIdentifier:[GroupChannelListEditableTableViewCell cellReuseIdentifier]];
        MGSwipeButton *leaveButton = [MGSwipeButton buttonWithTitle:[NSBundle sbLocalizedStringForKey:@"LeaveButton"] backgroundColor:[Constants leaveButtonColor]];
        MGSwipeButton *hideButton = [MGSwipeButton buttonWithTitle:[NSBundle sbLocalizedStringForKey:@"HideButton"] backgroundColor:[Constants hideButtonColor]];
        
        hideButton.titleLabel.font = [Constants hideButtonFont];
        leaveButton.titleLabel.font = [Constants leaveButtonFont];
        
        cell.rightButtons = @[hideButton, leaveButton];
        [(GroupChannelListEditableTableViewCell *)cell setModel:self.channels[indexPath.row]];
        cell.delegate = self;
    }
    else {
        cell = [tableView dequeueReusableCellWithIdentifier:[GroupChannelListTableViewCell cellReuseIdentifier]];
        if (self.channels[indexPath.row].isTyping == YES) {
            if ([self.typingAnimationChannelList indexOfObject:self.channels[indexPath.row].channelUrl] == NSNotFound) {
                [self.typingAnimationChannelList addObject:self.channels[indexPath.row].channelUrl];
            }
        }
        else {
            [self.typingAnimationChannelList removeObject:self.channels[indexPath.row].channelUrl];
        }

        SBDGroupChannel *channel = self.channels[indexPath.row];
        [(GroupChannelListTableViewCell *)cell setModel:channel];
    }
    
    if (self.channels.count > 0 && indexPath.row + 1 == self.channels.count) {
        [self.queryCollection load];
    }
    
    return cell;
}

#pragma mark - MGSwipeTableCellDelegate
- (BOOL)swipeTableCell:(MGSwipeTableCell *) cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion {
    // 0: right, 1: left
    NSInteger row = [self.tableView indexPathForCell:cell].row;
    SBDGroupChannel *selectedChannel = self.channels[row];
    if (index == 0) {
        // Hide
        [selectedChannel hideChannelWithHidePreviousMessages:NO completionHandler:^(SBDError * _Nullable error) {
            if (error != nil) {
                UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                [vc addAction:closeAction];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:vc animated:YES completion:nil];
                });
                
                return;
            }
            
            [self.channels removeObject:selectedChannel];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
    else {
        // Leave
        [selectedChannel leaveChannelWithCompletionHandler:^(SBDError * _Nullable error) {
            if (error != nil) {
                UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                [vc addAction:closeAction];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:vc animated:YES completion:nil];
                });
                
                return;
            }
            
            [self.channels removeObject:selectedChannel];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
    
    return YES;
}

#pragma mark - CreateGroupChannelUserListViewControllerDelegate
- (void)openGroupChannel:(SBDGroupChannel *)channel viewController:(UIViewController *)vc {
    dispatch_async(dispatch_get_main_queue(), ^{
        GroupChannelChattingViewController *vc = [[GroupChannelChattingViewController alloc] init];
        vc.channel = channel;
        [self presentViewController:vc animated:NO completion:nil];
    });
}

#pragma mark - Connection Manager Delegate
- (void)didConnect:(BOOL)isReconnection {
    //
}

#pragma mark - Channel Query Collection Delegate
- (void)queryCollection:(QueryCollection *)queryCollection
        itemsAreUpdated:(NSArray <SBDBaseChannel *> *)updatedChannels
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
            [self hideEmptyTableStyle];
            break;
            
        case ChangeLogActionChanged:
            [self changeChangeLogs:changeLogs completionHandler:nil];
            break;
            
        case ChangeLogActionDeleted:
            [self deleteChangeLogs:changeLogs completionHandler:nil];
            [self showEmptyTableStyle];
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
            
            __weak GroupChannelListViewController *weakSelf = self;
            [self performBatchUpdates:^(UITableView * _Nonnull tableView) {
                [tableView moveRowAtIndexPath:atIndexPath toIndexPath:toIndexPath];
            } completion:^(BOOL finished) {
                __strong GroupChannelListViewController *strongSelf = weakSelf;
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
        [self.tableView reloadData];
        if (completionHandler != nil) {
            completionHandler();
        }
    }
}

#pragma mark - SBDChannelDelegate
- (void)channelDidUpdateTypingStatus:(SBDGroupChannel * _Nonnull)sender {
    if (self.editableChannel == YES) {
        return;
    }

    NSUInteger row = [self.channels indexOfObject:sender];
    if (row != NSNotFound) {
        GroupChannelListTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];

        [cell startTypingAnimation];
    }
}

- (void)channel:(SBDGroupChannel * _Nonnull)sender userDidLeave:(SBDUser * _Nonnull)user {
    if ([user.userId isEqualToString:[SBDMain getCurrentUser].userId]) {
        [self.channels removeObject:sender];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

- (void)channelWasChanged:(SBDBaseChannel * _Nonnull)sender {
    if ([sender isKindOfClass:[SBDGroupChannel class]]) {
        NSUInteger index = [self.channels indexOfObject:(SBDGroupChannel *)sender];
        if (index != NSNotFound) {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
            [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        else {
            
        }
    }
}

@end
