//
//  GroupChannelChattingViewController.m
//  SendBird-iOS
//
//  Created by Jed Kyung on 9/27/16.
//  Copyright © 2016 SendBird. All rights reserved.
//

#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <Photos/Photos.h>
#import <NYTPhotoViewer/NYTPhotosViewController.h>
#import <HTMLKit/HTMLKit.h>

#import "AppDelegate.h"
#import "GroupChannelChattingViewController.h"
#import "MemberListViewController.h"
#import "BlockedUserListViewController.h"
#import "NSBundle+SendBird.h"
#import "Utils.h"
#import "ChatImage.h"
#import "FLAnimatedImageView+ImageCache.h"
#import "CreateGroupChannelUserListViewController.h"
#import "ConnectionManager.h"
#import "Application.h"

#import <SyncManager/SyncManager.h>

@interface GroupChannelChattingViewController () <ConnectionManagerDelegate, MessageCollectionDelegate>

@property (weak, nonatomic) IBOutlet ChattingView *chattingView;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItem;
@property (strong, nonatomic) NSString *delegateIdentifier;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomMargin;
@property (weak, nonatomic) IBOutlet UIView *imageViewerLoadingView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *imageViewerLoadingIndicator;
@property (weak, nonatomic) IBOutlet UINavigationItem *imageViewerLoadingViewNavItem;

@property (atomic) BOOL hasNext;
@property (atomic) BOOL refreshInViewDidAppear;

@property (atomic) BOOL isLoading;
@property (atomic) BOOL keyboardShown;

@property (strong, nonatomic) NYTPhotosViewController *photosViewController;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *navigationBarHeight;

/**
 *  new properties with message manager
 */
@property (strong, nonatomic, nullable) MessageCollection *messageCollection;

@end

@implementation GroupChannelChattingViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil) {
        _delegateIdentifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configureView];

    [SBDMain addChannelDelegate:self identifier:self.delegateIdentifier];
    [ConnectionManager addConnectionObserver:self];
    
    if ([SBDMain getConnectState] == SBDWebSocketClosed) {
        [ConnectionManager loginWithCompletionHandler:^(SBDUser * _Nullable user, NSError * _Nullable error) {
            if (error != nil) {
                return;
            }
        }];
    }
    else {
        self.messageCollection.delegate = self;
        self.isLoading = YES;
        [self.messageCollection loadPreviousMessagesFromNow];
    }
}

- (void)configureView {
    // Do any additional setup after loading the view from its nib.
    UILabel *titleView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width - 100, 64)];
    titleView.attributedText = [Utils generateNavigationTitle:[NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount] subTitle:nil];
    titleView.numberOfLines = 2;
    titleView.textAlignment = NSTextAlignmentCenter;
    
    UITapGestureRecognizer *titleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickReconnect)];
    titleView.userInteractionEnabled = YES;
    [titleView addGestureRecognizer:titleTapRecognizer];
    
    self.navItem.titleView = titleView;
    
    UIBarButtonItem *negativeLeftSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeLeftSpacer.width = -2;
    UIBarButtonItem *negativeRightSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeRightSpacer.width = -2;
    
    UIBarButtonItem *leftCloseItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_close"] style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    UIBarButtonItem *rightOpenMoreMenuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_more"] style:UIBarButtonItemStyleDone target:self action:@selector(openMoreMenu)];
    
    self.navItem.leftBarButtonItems = @[negativeLeftSpacer, leftCloseItem];
    self.navItem.rightBarButtonItems = @[negativeRightSpacer, rightOpenMoreMenuItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    
    UIBarButtonItem *negativeLeftSpacerForImageViewerLoading = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeLeftSpacerForImageViewerLoading.width = -2;
    
    UIBarButtonItem *leftCloseItemForImageViewerLoading = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_close"] style:UIBarButtonItemStyleDone target:self action:@selector(hideImageViewerLoading)];
    
    self.imageViewerLoadingViewNavItem.leftBarButtonItems = @[negativeLeftSpacerForImageViewerLoading, leftCloseItemForImageViewerLoading];
    
    self.hasNext = YES;
    self.isLoading = NO;
    
    self.chattingView.delegate = self;
    [self.chattingView configureChattingViewWithChannel:self.channel];
    [self.chattingView.fileAttachButton addTarget:self action:@selector(sendFileMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.chattingView.sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
}

- (void)dealloc {
    [ConnectionManager removeConnectionObserver:self];
    self.messageCollection.delegate = nil;
}

- (void)keyboardDidShow:(NSNotification *)notification {
    self.keyboardShown = YES;
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardFrameBeginRect = [keyboardFrameBegin CGRectValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bottomMargin.constant = keyboardFrameBeginRect.size.height;
        [self.view layoutIfNeeded];
        self.chattingView.stopMeasuringVelocity = YES;
        [self.chattingView scrollToBottomWithForce:NO];
    });
}

- (void)keyboardDidHide:(NSNotification *)notification {
    self.keyboardShown = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bottomMargin.constant = 0;
        [self.view layoutIfNeeded];
        [self.chattingView scrollToBottomWithForce:NO];
    });
}

- (void)close {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)openMoreMenu {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *seeMemberListAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"SeeMemberListButton"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MemberListViewController *mlvc = [[MemberListViewController alloc] init];
            [mlvc setChannel:self.channel];
            [self presentViewController:mlvc animated:NO completion:nil];
        });
    }];

    UIAlertAction *inviteUserListAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"InviteUserButton"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CreateGroupChannelUserListViewController *vc = [[CreateGroupChannelUserListViewController alloc] init];
            vc.userSelectionMode = 1;
            vc.groupChannel = self.channel;
            [self presentViewController:vc animated:NO completion:nil];
        });
    }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
    [vc addAction:seeMemberListAction];
    [vc addAction:inviteUserListAction];
    [vc addAction:closeAction];
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)sendUrlPreview:(NSURL * _Nonnull)url message:(NSString * _Nonnull)message tempModel:(OutgoingGeneralUrlPreviewTempModel * _Nonnull)aTempModel {
    NSURL *preViewUrl = url;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            [self sendMessageWithReplacement:aTempModel];
            [session invalidateAndCancel];
            
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *contentType = (NSString *)httpResponse.allHeaderFields[@"Content-Type"];
        if ([contentType containsString:@"text/html"]) {
            NSString *htmlBody = [NSString stringWithUTF8String:[data bytes]];

            HTMLParser *parser = [[HTMLParser alloc] initWithString:htmlBody];
            HTMLDocument *document = [parser parseDocument];
            HTMLElement *head = document.head;
            
            NSString *title = nil;
            NSString *desc = nil;
            
            NSString *ogUrl = nil;
            NSString *ogSiteName = nil;
            NSString *ogTitle = nil;
            NSString *ogDesc = nil;
            NSString *ogImage = nil;
            
            NSString *twtUrl = nil;
            NSString *twtSiteName = nil;
            NSString *twtTitle = nil;
            NSString *twtDesc = nil;
            NSString *twtImage = nil;
            
            NSString *finalUrl = nil;
            NSString *finalTitle = nil;
            NSString *finalSiteName = nil;
            NSString *finalDesc = nil;
            NSString *finalImage = nil;
            
            for (id node in head.childNodes) {
                if ([node isKindOfClass:[HTMLElement class]]) {
                    HTMLElement *element = (HTMLElement *)node;
                    if ([element.tagName isEqualToString:@"meta"]) {
                        if (element.attributes[@"property"] != nil && ![element.attributes[@"property"] isKindOfClass:[NSNull class]]) {
                            if (ogUrl == nil && [element.attributes[@"property"] isEqualToString:@"og:url"]) {
                                ogUrl = element.attributes[@"content"];
                                NSLog(@"URL - %@", element.attributes[@"content"]);
                            }
                            else if (ogSiteName == nil && [element.attributes[@"property"] isEqualToString:@"og:site_name"]) {
                                ogSiteName = element.attributes[@"content"];
                                NSLog(@"Site Name - %@", element.attributes[@"content"]);
                            }
                            else if (ogTitle == nil && [element.attributes[@"property"] isEqualToString:@"og:title"]) {
                                ogTitle = element.attributes[@"content"];
                                NSLog(@"Title - %@", element.attributes[@"content"]);
                            }
                            else if (ogDesc == nil && [element.attributes[@"property"] isEqualToString:@"og:description"]) {
                                ogDesc = element.attributes[@"content"];
                                NSLog(@"Description - %@", element.attributes[@"content"]);
                            }
                            else if (ogImage == nil && [element.attributes[@"property"] isEqualToString:@"og:image"]) {
                                ogImage = element.attributes[@"content"];
                                NSLog(@"Image - %@", element.attributes[@"content"]);
                            }
                        }
                        else if (element.attributes[@"name"] != nil && ![element.attributes[@"name"] isKindOfClass:[NSNull class]]) {
                            if (twtSiteName == nil && [element.attributes[@"name"] isEqualToString:@"twitter:site"]) {
                                twtSiteName = element.attributes[@"content"];
                                NSLog(@"Site Name - %@", element.attributes[@"content"]);
                            }
                            else if (twtTitle == nil && [element.attributes[@"name"] isEqualToString:@"twitter:title"]) {
                                twtTitle = element.attributes[@"content"];
                                NSLog(@"Title - %@", element.attributes[@"content"]);
                            }
                            else if (twtDesc == nil && [element.attributes[@"name"] isEqualToString:@"twitter:description"]) {
                                twtDesc = element.attributes[@"content"];
                                NSLog(@"Description - %@", element.attributes[@"content"]);
                            }
                            else if (twtImage == nil && [element.attributes[@"name"] isEqualToString:@"twitter:image"]) {
                                twtImage = element.attributes[@"content"];
                                NSLog(@"Image - %@", element.attributes[@"content"]);
                            }
                            else if (desc == nil && [element.attributes[@"name"] isEqualToString:@"description"]) {
                                desc = element.attributes[@"content"];
                            }
                        }
                    }
                    else if ([element.tagName isEqualToString:@"title"]) {
                        if (element.childNodes.count > 0) {
                            if ([element.childNodes[0] isKindOfClass:[HTMLText class]]) {
                                title = ((HTMLText *)element.childNodes[0]).data;
                            }
                        }
                    }
                }
            }
            
            if (ogUrl != nil) {
                finalUrl = ogUrl;
            }
            else if (twtUrl != nil) {
                finalUrl = twtUrl;
            }
            else {
                finalUrl = [preViewUrl absoluteString];
            }
            
            if (ogSiteName != nil) {
                finalSiteName = ogSiteName;
            }
            else if (twtSiteName != nil) {
                finalSiteName = twtSiteName;
            }
            
            if (ogTitle != nil) {
                finalTitle = ogTitle;
            }
            else if (twtTitle != nil) {
                finalTitle = twtTitle;
            }
            else if (title != nil) {
                finalTitle = title;
            }
            
            if (ogDesc != nil) {
                finalDesc = ogDesc;
            }
            else if (twtDesc != nil) {
                finalDesc = twtDesc;
            }
            
            if (ogImage != nil) {
                finalImage = ogImage;
            }
            else if (twtImage != nil) {
                finalImage = twtImage;
            }
            
            if (!(finalSiteName == nil || finalTitle == nil || finalDesc == nil)) {
                NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                data[@"site_name"] = finalSiteName;
                data[@"title"] = finalTitle;
                data[@"description"] = finalDesc;
                if (finalImage != nil) {
                    data[@"image"] = finalImage;
                }
                
                if (finalUrl != nil) {
                    data[@"url"] = finalUrl;
                }
                
                NSError *err;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&err];
                NSString *dataString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                
                [self.channel sendUserMessage:message data:dataString customType:@"url_preview" completionHandler:^(SBDUserMessage * _Nullable userMessage, SBDError * _Nullable error) {
                    // Do nothing.
                    
                    if (error != nil) {
                        [self sendMessageWithReplacement:aTempModel];
                        
                        return;
                    }

                    [self.chattingView replaceMessageFrom:aTempModel
                                                       to:userMessage
                                        messageCollection:self.messageCollection
                                        completionHandler:nil];
                }];
            }
            else {
                [self sendMessageWithReplacement:aTempModel];
            }
        }

        [session invalidateAndCancel];
    }] resume];
}

#pragma mark - Message Manager
- (MessageCollection *)messageCollection {
    if (_messageCollection == nil) {
        _messageCollection = [self createMessageCollection];
    }
    return _messageCollection;
}

- (MessageCollection *)createMessageCollection {
    NSDictionary *filter = @{};
    MessageCollection *collection = [MessageManager createMessageCollectionWithChannelUrl:self.channel.channelUrl filter:filter];
    return collection;
}

#pragma mark - Message Collection Delegate
- (void)messageCollection:(MessageCollection *)messageCollection
          itemsAreUpdated:(NSArray<SBDBaseMessage *> *)updatedMessages
                   action:(ChangeLogAction)action
                    error:(NSError *)error {
    self.isLoading = NO;
    self.chattingView.initialLoading = NO;
    if (self.messageCollection != messageCollection) {
        return;
    }
    
    if (error != nil) {
        return;
    }
    
    if (updatedMessages == nil || updatedMessages.count == 0) {
        return;
    }
    
    __weak GroupChannelChattingViewController *weakSelf = self;
    [self.chattingView updateMessages:updatedMessages messageCollection:self.messageCollection changeAction:action completionHandler:^{
        __strong GroupChannelChattingViewController *strongSelf = weakSelf;
        if ([Utils isTopViewController:strongSelf]) {
            [strongSelf.channel markAsRead];
        }
    }];
}

#pragma mark - SendBird SDK
- (void)sendMessageWithReplacement:(OutgoingGeneralUrlPreviewTempModel * _Nonnull)replacement {
    SBDUserMessage *preSendMessage = [self.channel sendUserMessage:replacement.message data:@"" customType:@"" targetLanguages:@[@"ar", @"de", @"fr", @"nl", @"ja", @"ko", @"pt", @"es", @"zh-CHS"] completionHandler:^(SBDUserMessage * _Nullable userMessage, SBDError * _Nullable error) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            SBDUserMessage *preSendMessage = (SBDUserMessage *)self.chattingView.preSendMessages[userMessage.requestId];
            [self.chattingView.preSendMessages removeObjectForKey:userMessage.requestId];
            
            if (error != nil) {
                self.chattingView.resendableMessages[userMessage.requestId] = userMessage;
                [self.chattingView.chattingTableView reloadData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.chattingView scrollToBottomWithForce:YES];
                });
                
                return;
            }
            
            [self.chattingView replaceMessageFrom:preSendMessage
                                               to:userMessage
                                messageCollection:self.messageCollection
                                completionHandler:nil];
        });
    }];
    self.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
    [self.chattingView replaceMessageFrom:replacement
                                       to:preSendMessage
                        messageCollection:self.messageCollection 
                        completionHandler:nil];
}

- (void)sendMessage {
    if (self.chattingView.messageTextView.text.length > 0) {
        [self.channel endTyping];
        NSString *message = [self.chattingView.messageTextView.text copy];
        self.chattingView.messageTextView.text = @"";
        
        NSError *error = nil;
        NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
        if (error == nil) {
            NSArray *matches = [detector matchesInString:message options:0 range:NSMakeRange(0, message.length)];
            NSURL *url = nil;
            for (NSTextCheckingResult *match in matches) {
                url = [match URL];
                break;
            }
            
            if (url != nil) {
                OutgoingGeneralUrlPreviewTempModel *tempModel = [[OutgoingGeneralUrlPreviewTempModel alloc] init];
                tempModel.createdAt = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
                tempModel.message = message;
                
                __weak GroupChannelChattingViewController *weakSelf = self;
                [self.chattingView updateMessages:@[tempModel] messageCollection:self.messageCollection changeAction:ChangeLogActionNew completionHandler:^{
                    __strong GroupChannelChattingViewController *strongSelf = weakSelf;
                    // Send preview;
                    [strongSelf sendUrlPreview:url message:message tempModel:tempModel];
                }];

                return;
            }
        }
        
        self.chattingView.sendButton.enabled = NO;
        SBDUserMessage *preSendMessage = [self.channel sendUserMessage:message data:@"" customType:@"" targetLanguages:@[@"ar", @"de", @"fr", @"nl", @"ja", @"ko", @"pt", @"es", @"zh-CHS"] completionHandler:^(SBDUserMessage * _Nullable userMessage, SBDError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SBDUserMessage *preSendMessage = (SBDUserMessage *)self.chattingView.preSendMessages[userMessage.requestId];
                [self.chattingView.preSendMessages removeObjectForKey:userMessage.requestId];
                
                if (error != nil) {
                    self.chattingView.resendableMessages[userMessage.requestId] = userMessage;
                    [self.chattingView.chattingTableView reloadData];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.chattingView scrollToBottomWithForce:YES];
                    });
                    
                    return;
                }
                
                [self.chattingView replaceMessageFrom:preSendMessage
                                                   to:userMessage
                                    messageCollection:self.messageCollection
                                    completionHandler:nil];
            });
        }];
        
        self.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
        __weak GroupChannelChattingViewController *weakSelf = self;
        [self.chattingView updateMessages:@[preSendMessage] messageCollection:self.messageCollection changeAction:ChangeLogActionNew completionHandler:^{
            __strong GroupChannelChattingViewController *strongSelf = weakSelf;
            strongSelf.chattingView.sendButton.enabled = YES;
        }];
    }
}

- (void)sendFileMessage {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status != PHAuthorizationStatusAuthorized) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
                mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                NSMutableArray *mediaTypes = [[NSMutableArray alloc] initWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                mediaUI.mediaTypes = mediaTypes;
                [mediaUI setDelegate:self];
                self.refreshInViewDidAppear = NO;
                [self presentViewController:mediaUI animated:YES completion:nil];
            }
        }];
    }
    else {
        UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
        mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        NSMutableArray *mediaTypes = [[NSMutableArray alloc] initWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
        mediaUI.mediaTypes = mediaTypes;
        [mediaUI setDelegate:self];
        [self presentViewController:mediaUI animated:YES completion:nil];
    }
}

- (void)clickReconnect {
    if ([SBDMain getConnectState] != SBDWebSocketOpen && [SBDMain getConnectState] != SBDWebSocketConnecting) {
        [SBDMain reconnect];
    }
}

#pragma mark - Connection Manager Delegate
- (void)didConnect:(BOOL)isReconnection {
    [self.messageCollection loadPreviousMessagesFromNow];
    
    [self.channel refreshWithCompletionHandler:^(SBDError * _Nullable error) {
        if (error == nil) {
            if (self.navItem.titleView != nil && [self.navItem.titleView isKindOfClass:[UILabel class]]) {
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *title = [NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount];
                NSString *subtitle = [NSBundle sbLocalizedStringForKey:@"ReconnectedSubTitle"];
                UILabel *label = (UILabel *)self.navItem.titleView;
                label.attributedText = [Utils generateNavigationTitle:title subTitle:subtitle];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    NSString *title = [NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount];
                    UILabel *label = (UILabel *)self.navItem.titleView;
                    label.attributedText = [Utils generateNavigationTitle:title subTitle:nil];
                });
            });
        }
    }];
}

- (void)didDisconnect {
    if (self.navItem.titleView != nil && [self.navItem.titleView isKindOfClass:[UILabel class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *title = [NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount];
            NSString *subtitle = [NSBundle sbLocalizedStringForKey:@"ReconnectionFailedSubTitle"];
            UILabel *label = (UILabel *)self.navItem.titleView;
            label.attributedText = [Utils generateNavigationTitle:title subTitle:subtitle];
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *title = [NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount];
            NSString *subtitle = [NSBundle sbLocalizedStringForKey:@"ReconnectingSubTitle"];
            UILabel *label = (UILabel *)self.navItem.titleView;
            label.attributedText = [Utils generateNavigationTitle:title subTitle:subtitle];
        });
    }
}

#pragma mark - SBDChannelDelegate
- (void)channelDidUpdateReadReceipt:(SBDGroupChannel * _Nonnull)sender {
    // TODO: move to cell
    if (sender == self.channel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.chattingView.chattingTableView reloadData];
        });
    }
}

- (void)channelDidUpdateTypingStatus:(SBDGroupChannel * _Nonnull)sender {
    if (sender == self.channel) {
        if (sender.getTypingMembers.count == 0) {
            [self.chattingView endTypingIndicator];
        }
        else {
            if (sender.getTypingMembers.count == 1) {
                [self.chattingView startTypingIndicator:[NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"TypingMessageSingular"], sender.getTypingMembers[0].nickname]];
            }
            else {
                [self.chattingView startTypingIndicator:[NSBundle sbLocalizedStringForKey:@"TypingMessagePlural"]];
            }
        }
    }
}

- (void)channel:(SBDGroupChannel * _Nonnull)sender userDidJoin:(SBDUser * _Nonnull)user {
    if (self.navItem.titleView != nil && [self.navItem.titleView isKindOfClass:[UILabel class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ((UILabel *)self.navItem.titleView).attributedText = [Utils generateNavigationTitle:[NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount] subTitle:nil];
        });
    }
}

- (void)channel:(SBDGroupChannel * _Nonnull)sender userDidLeave:(SBDUser * _Nonnull)user {
    if (self.navItem.titleView != nil && [self.navItem.titleView isKindOfClass:[UILabel class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ((UILabel *)self.navItem.titleView).attributedText = [Utils generateNavigationTitle:[NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount] subTitle:nil];
        });
    }
}

- (void)channelWasChanged:(SBDBaseChannel * _Nonnull)sender {
    if (sender == self.channel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.navItem.title = [NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"GroupChannelTitle"], self.channel.memberCount];
        });
    }
}

- (void)channelWasDeleted:(NSString * _Nonnull)channelUrl channelType:(SBDChannelType)channelType {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ChannelDeletedTitle"] message:[NSBundle sbLocalizedStringForKey:@"ChannelDeletedMessage"] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self close];
    }];
    [vc addAction:closeAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:vc animated:YES completion:nil];
    });
}

#pragma mark - ChattingViewDelegate
- (void)loadMoreMessage:(UIView *)view {
    [self.messageCollection loadPreviousMessages];
}

- (void)startTyping:(UIView *)view {
    [self.channel startTyping];
}

- (void)endTyping:(UIView *)view {
    [self.channel endTyping];
}

- (void)hideKeyboardWhenFastScrolling:(UIView *)view {
    if (self.keyboardShown == NO) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bottomMargin.constant = 0;
        [self.view layoutIfNeeded];
        [self.chattingView scrollToBottomWithForce:NO];
    });
    [self.view endEditing:YES];
}

#pragma mark - MessageDelegate
- (void)clickProfileImage:(UITableViewCell *)viewCell user:(SBDUser *)user {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:user.nickname message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *seeBlockUserAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"BlockUserButton"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [SBDMain blockUser:user completionHandler:^(SBDUser * _Nullable blockedUser, SBDError * _Nullable error) {
            if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                    [vc addAction:closeAction];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self presentViewController:vc animated:YES completion:nil];
                    });
                });
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"UserBlockedTitle"] message:[NSString stringWithFormat:[NSBundle sbLocalizedStringForKey:@"UserBlockedMessage"], user.nickname] preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                [vc addAction:closeAction];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:vc animated:YES completion:nil];
                });
            });
        }];
        
    }];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
    [vc addAction:seeBlockUserAction];
    [vc addAction:closeAction];
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)clickMessage:(UIView *)view message:(SBDBaseMessage *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *deleteMessageAction = nil;
    UIAlertAction *openFileAction = nil;
    NSMutableArray<UIAlertAction *> *openURLsAction = [[NSMutableArray alloc] init];
    
    if ([message isKindOfClass:[SBDBaseMessage class]]) {
        __block SBDBaseMessage *baseMessage = message;
        if ([baseMessage isKindOfClass:[SBDUserMessage class]]) {
            SBDUserMessage *userMessage = (SBDUserMessage *)baseMessage;
            if (userMessage.customType != nil && [userMessage.customType isEqualToString:@"url_preview"]) {
                NSData *data = [userMessage.data dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *previewData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSURL *url = [NSURL URLWithString:previewData[@"url"]];
                [Application openURL:url];
            }
            else {
                SBDUser *sender = ((SBDUserMessage *)baseMessage).sender;
                if ([sender.userId isEqualToString:[SBDMain getCurrentUser].userId] && self.chattingView.preSendMessages[((SBDUserMessage *)baseMessage).requestId] == nil) {
                    deleteMessageAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"DeleteMessageButton"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                        [self.channel deleteMessage:baseMessage completionHandler:^(SBDError * _Nullable error) {
                            if (error != nil) {
                                UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                                [alert addAction:closeAction];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self presentViewController:alert animated:YES completion:nil];
                                });
                            }
                        }];
                    }];
                }
                
                NSError *error = nil;
                NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
                if (error == nil) {
                    NSArray *matches = [detector matchesInString:((SBDUserMessage *)message).message options:0 range:NSMakeRange(0, ((SBDUserMessage *)message).message.length)];
                    for (NSTextCheckingResult *match in matches) {
                        __block NSURL *url = [match URL];
                        UIAlertAction *openURLAction = [UIAlertAction actionWithTitle:[url relativeString] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [Application openURL:url];
                        }];
                        [openURLsAction addObject:openURLAction];
                    }
                }
            }
        }
        else if ([baseMessage isKindOfClass:[SBDFileMessage class]]) {
            SBDFileMessage *fileMessage = (SBDFileMessage *)baseMessage;
            SBDUser *sender = ((SBDFileMessage *)baseMessage).sender;
            __block NSString *type = fileMessage.type;
            __block NSString *url = fileMessage.url;
            
            if ([sender.userId isEqualToString:[SBDMain getCurrentUser].userId] && self.chattingView.preSendMessages[fileMessage.requestId] == nil) {
                deleteMessageAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"DeleteMessageButton"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    [self.channel deleteMessage:baseMessage completionHandler:^(SBDError * _Nullable error) {
                        if (error != nil) {
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ErrorTitle"] message:error.domain preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
                            [alert addAction:closeAction];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self presentViewController:alert animated:YES completion:nil];
                            });
                        }
                    }];
                }];
            }
            
            if ([type hasPrefix:@"video"]) {
                NSURL *videoUrl = [NSURL URLWithString:url];
                AVPlayer *player = [[AVPlayer alloc] initWithURL:videoUrl];
                AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
                vc.player = player;
                [self presentViewController:vc animated:YES completion:^{
                    [player play];
                }];
                
                return;
            }
            else if ([type hasPrefix:@"audio"]) {
                NSURL *audioUrl = [NSURL URLWithString:url];
                AVPlayer *player = [[AVPlayer alloc] initWithURL:audioUrl];
                AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
                vc.player = player;
                [self presentViewController:vc animated:YES completion:^{
                    [player play];
                }];
                
                return;
            }
            else if ([type hasPrefix:@"image"]) {
                [self showImageViewerLoading];
                ChatImage *photo = [[ChatImage alloc] init];
                NSData *cachedData = [FLAnimatedImageView cachedImageForURL:[NSURL URLWithString:url]];
                if (cachedData != nil) {
                    photo.imageData = cachedData;
                    
                    self.photosViewController = [[NYTPhotosViewController alloc] initWithPhotos:@[photo]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.photosViewController.rightBarButtonItems = nil;
                        self.photosViewController.rightBarButtonItem = nil;
                        
                        UIBarButtonItem *negativeLeftSpacerForImageViewerLoading = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
                        negativeLeftSpacerForImageViewerLoading.width = -2;
                        
                        UIBarButtonItem *leftCloseItemForImageViewerLoading = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_close"] style:UIBarButtonItemStyleDone target:self action:@selector(closeImageViewer)];
                        
                        self.photosViewController.leftBarButtonItems = @[negativeLeftSpacerForImageViewerLoading, leftCloseItemForImageViewerLoading];
                    
                    
                        [self presentViewController:self.photosViewController animated:YES completion:^{
                            [self hideImageViewerLoading];
                        }];
                    });
                }
                else {
                    NSURLSession *session = [NSURLSession sharedSession];
                    __block NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
                    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                        if (error != nil) {
                            [self hideImageViewerLoading];
                            
                            return;
                        }
                        
                        NSHTTPURLResponse *resp = (NSHTTPURLResponse *)response;
                        if ([resp statusCode] >= 200 && [resp statusCode] < 300) {
                            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
                            [[AppDelegate imageCache] storeCachedResponse:cachedResponse forRequest:request];

                            ChatImage *photo = [[ChatImage alloc] init];
                            photo.imageData = data;
                            
                            self.photosViewController = [[NYTPhotosViewController alloc] initWithPhotos:@[photo]];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                self.photosViewController.rightBarButtonItems = nil;
                                self.photosViewController.rightBarButtonItem = nil;
                                
                                UIBarButtonItem *negativeLeftSpacerForImageViewerLoading = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
                                negativeLeftSpacerForImageViewerLoading.width = -2;
                                
                                UIBarButtonItem *leftCloseItemForImageViewerLoading = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_close"] style:UIBarButtonItemStyleDone target:self action:@selector(closeImageViewer)];
                                
                                self.photosViewController.leftBarButtonItems = @[negativeLeftSpacerForImageViewerLoading, leftCloseItemForImageViewerLoading];
                            
                            
                                [self presentViewController:self.photosViewController animated:NO completion:^{
                                    [self hideImageViewerLoading];
                                }];
                            });
                        }
                        else {
                            [self hideImageViewerLoading];
                        }
                    }] resume];
                }
                
                return;
            }
            else {
                // TODO: Download file.
            }
        }
        else if ([baseMessage isKindOfClass:[SBDAdminMessage class]]) {
            return;
        }
        
        [alert addAction:closeAction];
        if (openFileAction != nil) {
            [alert addAction:openFileAction];
        }
        
        if (openURLsAction.count > 0) {
            for (UIAlertAction *action in openURLsAction) {
                [alert addAction:action];
            }
        }
        
        if (deleteMessageAction != nil) {
            [alert addAction:deleteMessageAction];
        }
        
        if (openFileAction != nil || openURLsAction.count > 0 || deleteMessageAction != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    }
}

- (void)clickResend:(UIView *)view message:(SBDBaseMessage *)message {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"ResendFailedMessageTitle"] message:[NSBundle sbLocalizedStringForKey:@"ResendFailedMessageDescription"] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *resendAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"ResendFailedMessageButton"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if ([message isKindOfClass:[SBDUserMessage class]]) {
            SBDUserMessage *resendableUserMessage = (SBDUserMessage *)message;
            NSArray<NSString *> *targetLanguages = nil;
            if (resendableUserMessage.translations != nil) {
                targetLanguages = [resendableUserMessage.translations allKeys];
            }
            
            NSError *error = nil;
            NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
            if (error == nil) {
                NSArray *matches = [detector matchesInString:resendableUserMessage.message options:0 range:NSMakeRange(0, resendableUserMessage.message.length)];
                NSURL *url = nil;
                for (NSTextCheckingResult *match in matches) {
                    url = [match URL];
                    break;
                }
                
                if (url != nil) {
                    OutgoingGeneralUrlPreviewTempModel *tempModel = [[OutgoingGeneralUrlPreviewTempModel alloc] init];
                    tempModel.createdAt = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
                    tempModel.message = resendableUserMessage.message;
                    
                    __weak GroupChannelChattingViewController *weakSelf = self;
                    [self.chattingView replaceMessageFrom:tempModel to:resendableUserMessage messageCollection:self.messageCollection completionHandler:^{
                        __strong GroupChannelChattingViewController *strongSelf = weakSelf;
                        [strongSelf.chattingView.resendableMessages removeObjectForKey:resendableUserMessage.requestId];
                    }];
                    
                    // Send preview;
                    [self sendUrlPreview:url message:resendableUserMessage.message tempModel:tempModel];
                    
                    return;
                }
            }

            SBDUserMessage *preSendMessage = [self.channel sendUserMessage:resendableUserMessage.message data:resendableUserMessage.data customType:resendableUserMessage.customType targetLanguages:targetLanguages completionHandler:^(SBDUserMessage * _Nullable userMessage, SBDError * _Nullable error) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    SBDUserMessage *preSendMessage = (SBDUserMessage *)self.chattingView.preSendMessages[userMessage.requestId];
                    [self.chattingView.preSendMessages removeObjectForKey:userMessage.requestId];
                    
                    if (error != nil) {
                        self.chattingView.resendableMessages[userMessage.requestId] = userMessage;
                        [self.chattingView.chattingTableView reloadData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.chattingView scrollToBottomWithForce:YES];
                        });

                        return;
                    }
                    
                    [self.chattingView replaceMessageFrom:preSendMessage
                                                       to:userMessage
                                        messageCollection:self.messageCollection
                                        completionHandler:nil];
                });
            }];
            
            __weak GroupChannelChattingViewController *weakSelf = self;
            [self.chattingView replaceMessageFrom:resendableUserMessage to:preSendMessage messageCollection:self.messageCollection completionHandler:^{
                __strong GroupChannelChattingViewController *strongSelf = weakSelf;
                strongSelf.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
                [strongSelf.chattingView.resendableMessages removeObjectForKey:resendableUserMessage.requestId];
            }];
        }
        else if ([message isKindOfClass:[SBDFileMessage class]]) {
            __block SBDFileMessage *resendableFileMessage = (SBDFileMessage *)message;
            
            NSMutableArray<SBDThumbnailSize *> *thumbnailsSizes = [[NSMutableArray alloc] init];
            for (SBDThumbnail *thumbnail in resendableFileMessage.thumbnails) {
                [thumbnailsSizes addObject:[SBDThumbnailSize makeWithMaxCGSize:thumbnail.maxSize]];
            }
            __block SBDFileMessage *preSendMessage = [self.channel sendFileMessageWithBinaryData:(NSData *)self.chattingView.resendableFileData[resendableFileMessage.requestId][@"data"] filename:resendableFileMessage.name type:resendableFileMessage.type size:resendableFileMessage.size thumbnailSizes:thumbnailsSizes data:resendableFileMessage.data customType:resendableFileMessage.customType progressHandler:nil completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    SBDFileMessage *preSendMessage = (SBDFileMessage *)self.chattingView.preSendMessages[fileMessage.requestId];
                    [self.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                    
                    if (error != nil) {
                        self.chattingView.resendableMessages[fileMessage.requestId] = fileMessage;
                        self.chattingView.resendableFileData[fileMessage.requestId] = self.chattingView.preSendFileData[fileMessage.requestId];
                        [self.chattingView.preSendFileData removeObjectForKey:fileMessage.requestId];
                        [self.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                        [self.chattingView.chattingTableView reloadData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.chattingView scrollToBottomWithForce:YES];
                        });

                        return;
                    }
                    
                    [self.chattingView replaceMessageFrom:preSendMessage
                                                       to:fileMessage
                                        messageCollection:self.messageCollection
                                        completionHandler:nil];
                });
            }];
            
            __weak GroupChannelChattingViewController *weakSelf = self;
            [self.chattingView replaceMessageFrom:resendableFileMessage to:preSendMessage messageCollection:self.messageCollection completionHandler:^{
                __strong GroupChannelChattingViewController *strongSelf = weakSelf;
                strongSelf.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
                strongSelf.chattingView.preSendFileData[preSendMessage.requestId] = strongSelf.chattingView.resendableFileData[resendableFileMessage.requestId];
                [strongSelf.chattingView.resendableMessages removeObjectForKey:resendableFileMessage.requestId];
                [strongSelf.chattingView.resendableFileData removeObjectForKey:resendableFileMessage.requestId];
            }];
        }
    }];
    
    [vc addAction:closeAction];
    [vc addAction:resendAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:vc animated:YES completion:nil];
    });
}

- (void)clickDelete:(UIView *)view message:(SBDBaseMessage *)message {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:[NSBundle sbLocalizedStringForKey:@"DeleteFailedMessageTitle"] message:[NSBundle sbLocalizedStringForKey:@"DeleteFailedMessageDescription"] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"CloseButton"] style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:[NSBundle sbLocalizedStringForKey:@"DeleteFailedMessageButton"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *requestId = nil;
        if ([message isKindOfClass:[SBDUserMessage class]]) {
            requestId = ((SBDUserMessage *)message).requestId;
        }
        else if ([message isKindOfClass:[SBDFileMessage class]]) {
            requestId = ((SBDFileMessage *)message).requestId;
        }
        [self.chattingView.resendableFileData removeObjectForKey:requestId];
        [self.chattingView.resendableMessages removeObjectForKey:requestId];
        [self.chattingView.messages removeObject:message];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.chattingView.chattingTableView reloadData];
        });
    }];
    
    [vc addAction:closeAction];
    [vc addAction:deleteAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:vc animated:YES completion:nil];
    });
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    __weak GroupChannelChattingViewController *weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        GroupChannelChattingViewController *strongSelf = weakSelf;
        if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
            NSURL *imagePath = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
            NSString *imageName = [imagePath lastPathComponent];

            NSString *ext = [imageName pathExtension];
            NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
            NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);

            PHAsset *asset = [[PHAsset fetchAssetsWithALAssetURLs:@[imagePath] options:nil] lastObject];
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.synchronous = YES;
            options.networkAccessAllowed = NO;
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            
            if ([mimeType isEqualToString:@"image/gif"]) {
                [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                    NSNumber *isError = [info objectForKey:PHImageErrorKey];
                    NSNumber *isCloud = [info objectForKey:PHImageResultIsInCloudKey];
                    if ([isError boolValue] || [isCloud boolValue] || !imageData) {
                        // fail
                    } else {
                        // success, data is in imageData
                        /***********************************/
                        /* Thumbnail is a premium feature. */
                        /***********************************/
                        SBDThumbnailSize *thumbnailSize = [SBDThumbnailSize makeWithMaxWidth:320.0 maxHeight:320.0];
                        
                        SBDFileMessage *preSendMessage = [strongSelf.channel sendFileMessageWithBinaryData:imageData filename:[imageName lowercaseString] type:mimeType size:imageData.length thumbnailSizes:@[thumbnailSize] data:@"" customType:@"" progressHandler:nil completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                                SBDFileMessage *preSendMessage = (SBDFileMessage *)strongSelf.chattingView.preSendMessages[fileMessage.requestId];
                                [strongSelf.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                                
                                if (error != nil) {
                                    strongSelf.chattingView.resendableMessages[fileMessage.requestId] = preSendMessage;
                                    strongSelf.chattingView.resendableFileData[preSendMessage.requestId] = @{
                                                                                                             @"data": imageData,
                                                                                                             @"type": mimeType
                                                                                                             };
                                    [strongSelf.chattingView.chattingTableView reloadData];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.chattingView scrollToBottomWithForce:YES];
                                    });
                                    
                                    return;
                                }
                                
                                if (fileMessage != nil) {
                                    [self.chattingView.resendableMessages removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView.resendableFileData removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView replaceMessageFrom:preSendMessage
                                                                       to:fileMessage
                                                        messageCollection:self.messageCollection
                                                        completionHandler:nil];
                                }
                            });
                        }];
                        
                        self.chattingView.preSendFileData[preSendMessage.requestId] = @{@"data": imageData,
                                                                                        @"type": mimeType};
                        self.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
                        [self.chattingView updateMessages:@[preSendMessage]
                                        messageCollection:self.messageCollection
                                             changeAction:ChangeLogActionNew
                                        completionHandler:nil];
                    }
                }];
            }
            else {
                [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                    if (result != nil) {
                        // success, data is in imageData
                        /***********************************/
                        /* Thumbnail is a premium feature. */
                        /***********************************/
                        NSData *imageData = UIImageJPEGRepresentation(result, 1.0);
                        
                        SBDThumbnailSize *thumbnailSize = [SBDThumbnailSize makeWithMaxWidth:320.0 maxHeight:320.0];
                        
                        SBDFileMessage *preSendMessage = [strongSelf.channel sendFileMessageWithBinaryData:imageData filename:[imageName lowercaseString] type:mimeType size:imageData.length thumbnailSizes:@[thumbnailSize] data:@"" customType:@"" progressHandler:nil completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                                SBDFileMessage *preSendMessage = (SBDFileMessage *)strongSelf.chattingView.preSendMessages[fileMessage.requestId];
                                [strongSelf.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                                
                                if (error != nil) {
                                    strongSelf.chattingView.resendableMessages[fileMessage.requestId] = preSendMessage;
                                    strongSelf.chattingView.resendableFileData[preSendMessage.requestId] = @{
                                                                                                             @"data": imageData,
                                                                                                             @"type": mimeType
                                                                                                             };
                                    [strongSelf.chattingView.chattingTableView reloadData];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.chattingView scrollToBottomWithForce:YES];
                                    });
                                    
                                    return;
                                }
                                
                                if (fileMessage != nil) {
                                    [self.chattingView.resendableMessages removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView.resendableFileData removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                                    [self.chattingView replaceMessageFrom:preSendMessage
                                                                       to:fileMessage
                                                        messageCollection:self.messageCollection
                                                        completionHandler:nil];
                                }
                            });
                        }];
                        
                        self.chattingView.preSendFileData[preSendMessage.requestId] = @{@"data": imageData,
                                                                                        @"type": mimeType};
                        self.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
                        [self.chattingView updateMessages:@[preSendMessage]
                                        messageCollection:self.messageCollection
                                             changeAction:ChangeLogActionNew
                                        completionHandler:nil];
                    }
                }];
            }
        }
        else if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
            NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
            NSData *videoFileData = [NSData dataWithContentsOfURL:videoURL];
            NSString *videoName = [videoURL lastPathComponent];

            NSString *ext = [videoName pathExtension];
            NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
            NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
            
            // success, data is in imageData
            /***********************************/
            /* Thumbnail is a premium feature. */
            /***********************************/
            SBDThumbnailSize *thumbnailSize = [SBDThumbnailSize makeWithMaxWidth:320.0 maxHeight:320.0];
            
            SBDFileMessage *preSendMessage = [strongSelf.channel sendFileMessageWithBinaryData:videoFileData filename:videoName type:mimeType size:videoFileData.length thumbnailSizes:@[thumbnailSize] data:@"" customType:@"" progressHandler:nil completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    SBDFileMessage *preSendMessage = (SBDFileMessage *)strongSelf.chattingView.preSendMessages[fileMessage.requestId];
                    [strongSelf.chattingView.preSendMessages removeObjectForKey:fileMessage.requestId];
                    
                    if (error != nil) {
                        strongSelf.chattingView.resendableMessages[fileMessage.requestId] = preSendMessage;
                        strongSelf.chattingView.resendableFileData[preSendMessage.requestId] = @{
                                                                                                 @"data": videoFileData,
                                                                                                 @"type": mimeType
                                                                                                 };
                        [strongSelf.chattingView.chattingTableView reloadData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.chattingView scrollToBottomWithForce:YES];
                        });

                        return;
                    }
                    
                    if (fileMessage != nil) {
                        [self.chattingView.resendableMessages removeObjectForKey:fileMessage.requestId];
                        [self.chattingView.resendableFileData removeObjectForKey:fileMessage.requestId];
                        [self.chattingView replaceMessageFrom:preSendMessage
                                                           to:fileMessage
                                            messageCollection:self.messageCollection
                                            completionHandler:nil];
                    }
                });
            }];
            
            self.chattingView.preSendFileData[preSendMessage.requestId] = @{@"data": videoFileData,
                                                                            @"type": mimeType};
            self.chattingView.preSendMessages[preSendMessage.requestId] = preSendMessage;
            [self.chattingView updateMessages:@[preSendMessage]
                            messageCollection:self.messageCollection
                                 changeAction:ChangeLogActionNew
                            completionHandler:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)showImageViewerLoading {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageViewerLoadingView.hidden = NO;
        self.imageViewerLoadingIndicator.hidden = NO;
        [self.imageViewerLoadingIndicator startAnimating];
    });
}

- (void)hideImageViewerLoading {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageViewerLoadingView.hidden = YES;
        self.imageViewerLoadingIndicator.hidden = YES;
        [self.imageViewerLoadingIndicator stopAnimating];
    });
}

- (void)closeImageViewer {
    if (self.photosViewController != nil) {
        [self.photosViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end





