/*****************************************************************************
 * VLCGoogleDriveTableViewController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <nitz.carola # googlemail.com>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCGoogleDriveTableViewController.h"
#import "VLCCloudStorageTableViewCell.h"
#import "VLCGoogleDriveController.h"
#import "VLCAppDelegate.h"
#import "UIBarButtonItem+Theme.h"
#import "VLCProgressView.h"

@interface VLCGoogleDriveTableViewController () <VLCCloudStorageTableViewCell, VLCGoogleDriveController>
{
    GTLDriveFile *_selectedFile;
    GTMOAuth2ViewControllerTouch *_authController;

    NSString *_currentFolderId;

    UIBarButtonItem *_backButton;
    UIBarButtonItem *_backToMenuButton;

    UIBarButtonItem *_numberOfFilesBarButtonItem;
    UIBarButtonItem *_progressBarButtonItem;

    VLCProgressView *_progressView;

    UIActivityIndicatorView *_activityIndicator;

    BOOL _authorizationInProgress;
    VLCGoogleDriveController *_googleDriveController;
}

@end

@implementation VLCGoogleDriveTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.modalPresentationStyle = UIModalPresentationFormSheet;

    _googleDriveController = [VLCGoogleDriveController sharedInstance];
    _googleDriveController.delegate = self;
    [_googleDriveController startSession];

    _authorizationInProgress = NO;

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DriveWhite"]];
    self.navigationItem.titleView.contentMode = UIViewContentModeScaleAspectFit;

    _backButton = [UIBarButtonItem themedBackButtonWithTarget:self andSelector:@selector(goBack:)];
    _backToMenuButton = [UIBarButtonItem themedRevealMenuButtonWithTarget:self andSelector:@selector(goBack:)];
    self.navigationItem.leftBarButtonItem = _backToMenuButton;

    self.tableView.rowHeight = [VLCCloudStorageTableViewCell heightOfCell];
    self.tableView.separatorColor = [UIColor VLCDarkBackgroundColor];
    self.view.backgroundColor = [UIColor VLCDarkBackgroundColor];

    _numberOfFilesBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"NUM_OF_FILES", nil), 0] style:UIBarButtonItemStylePlain target:nil action:nil];
    [_numberOfFilesBarButtonItem setTitleTextAttributes:@{ UITextAttributeFont : [UIFont systemFontOfSize:11.] } forState:UIControlStateNormal];

    _progressView = [VLCProgressView new];
    _progressBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_progressView];

    [self.cloudStorageLogo setImage:[UIImage imageNamed:@"DriveWhite"]];

    if (!SYSTEM_RUNS_IOS7_OR_LATER) {
        self.flatLoginButton.hidden = YES;
        [self.loginButton setTitle:NSLocalizedString(@"DROPBOX_LOGIN", nil) forState:UIControlStateNormal];
    } else {
        self.loginButton.hidden = YES;
        [self.flatLoginButton setTitle:NSLocalizedString(@"DROPBOX_LOGIN", nil) forState:UIControlStateNormal];
    }

    [self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"sudHeaderBg"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];

    [self _showProgressInToolbar:NO];

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.hidesWhenStopped = YES;
    _activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_activityIndicator];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_activityIndicator attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_activityIndicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
}

- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    _authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDrive
                                                                clientID:kVLCGoogleDriveClientID
                                                            clientSecret:kVLCGoogleDriveClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return _authController;
}

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController finishedWithAuth:(GTMOAuth2Authentication *)authResult error:(NSError *)error
{
    _authorizationInProgress = NO;
    if (error != nil) {
        _googleDriveController.driveService.authorizer = nil;
    } else {
        _googleDriveController.driveService.authorizer = authResult;
    }
    [self updateViewAfterSessionChange];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    [self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"bottomBlackBar"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [self updateViewAfterSessionChange];
    [super viewWillAppear:animated];

    [self.cloudStorageLogo sizeToFit];
    self.cloudStorageLogo.center = self.view.center;
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.navigationController.toolbarHidden = YES;
    if ((VLCAppDelegate*)[UIApplication sharedApplication].delegate.window.rootViewController.presentedViewController == nil) {
        [_googleDriveController stopSession];
        [self.tableView reloadData];
    }
    [super viewWillDisappear:animated];
}

- (void)_showProgressInToolbar:(BOOL)value
{
    if (!value)
        [self setToolbarItems:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], _numberOfFilesBarButtonItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]] animated:YES];
    else {
        _progressView.progressBar.progress = 0.;
        [self setToolbarItems:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], _progressBarButtonItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]] animated:YES];
    }
}

- (void)_requestInformationForCurrentFolderId
{
    [_activityIndicator startAnimating];
    [_googleDriveController requestDirectoryListingWithFolderId:_currentFolderId];

    self.navigationItem.leftBarButtonItem = ![_currentFolderId isEqualToString:@""] ? _backButton : _backToMenuButton;
}

- (IBAction)goBack:(id)sender
{
    if (![_currentFolderId isEqualToString:@""] && [_currentFolderId length] > 0) {
        _currentFolderId = [_currentFolderId stringByDeletingLastPathComponent];
        [self _requestInformationForCurrentFolderId];
    } else
        [[(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController] toggleSidebar:![(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController].sidebarShowing duration:kGHRevealSidebarDefaultAnimationDuration];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _googleDriveController.currentListFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"GoogleDriveCell";

    VLCCloudStorageTableViewCell *cell = (VLCCloudStorageTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
        cell = [VLCCloudStorageTableViewCell cellWithReuseIdentifier:CellIdentifier];

    cell.driveFile = _googleDriveController.currentListFiles[indexPath.row];
    if ([cell.driveFile.mimeType isEqualToString:@"application/vnd.google-apps.folder"])
        [cell setIsDownloadable:NO];
    else
        [cell setIsDownloadable:YES];

    cell.delegate = self;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = (indexPath.row % 2 == 0)? [UIColor blackColor]: [UIColor VLCDarkBackgroundColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _selectedFile = _googleDriveController.currentListFiles[indexPath.row];
    if (![_selectedFile.mimeType isEqualToString:@"application/vnd.google-apps.folder"]) {
        [_googleDriveController streamFile:_selectedFile];
    } else {
        /* dive into subdirectory */
        if (![_currentFolderId isEqualToString:@""])
            _currentFolderId = [_currentFolderId stringByAppendingString:@"/"];
        _currentFolderId = [_currentFolderId stringByAppendingString:_selectedFile.identifier];
        [self _requestInformationForCurrentFolderId];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)triggerDownloadForCell:(VLCCloudStorageTableViewCell *)cell
{
    _selectedFile = _googleDriveController.currentListFiles[[self.tableView indexPathForCell:cell].row];

    /* selected item is a proper file, ask the user if s/he wants to download it */
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DROPBOX_DOWNLOAD", nil) message:[NSString stringWithFormat:NSLocalizedString(@"DROPBOX_DL_LONG", nil), _selectedFile.title, [[UIDevice currentDevice] model]] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", nil) otherButtonTitles:NSLocalizedString(@"BUTTON_DOWNLOAD", nil), nil];
    [alert show];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSInteger currentOffset = scrollView.contentOffset.y;
    NSInteger maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;

    if (maximumOffset - currentOffset <= - self.tableView.rowHeight) {
        if (_googleDriveController.hasMoreFiles && !_activityIndicator.isAnimating) {
            [self _requestInformationForCurrentFolderId];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
        [_googleDriveController downloadFileToDocumentFolder:_selectedFile];
    _selectedFile = nil;
}

#pragma mark - google drive controller delegate

- (void)mediaListUpdated
{
    [_activityIndicator stopAnimating];

    [self.tableView reloadData];

    NSUInteger count = _googleDriveController.currentListFiles.count;
    if (count == 0)
        _numberOfFilesBarButtonItem.title = NSLocalizedString(@"NO_FILES", nil);
    else if (count != 1)
        _numberOfFilesBarButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"NUM_OF_FILES", nil), count];
    else
        _numberOfFilesBarButtonItem.title = NSLocalizedString(@"ONE_FILE", nil);
}

- (void)operationWithProgressInformationStarted
{
    [self _showProgressInToolbar:YES];
}

- (void)updateRemainingTime:(NSString *)time
{
    [_progressView updateTime:time];
}

- (void)currentProgressInformation:(float)progress {
    [_progressView.progressBar setProgress:progress animated:YES];
}

- (void)operationWithProgressInformationStopped
{
    [self _showProgressInToolbar:NO];
}

#pragma mark - communication with app delegate

- (void)updateViewAfterSessionChange
{
    if(_authorizationInProgress) {
        if (self.loginToCloudStorageView.superview)
            [self.loginToCloudStorageView removeFromSuperview];
        return;
    }
    if (![_googleDriveController isAuthorized]) {
        [self _showLoginPanel];
        return;
    } else if (self.loginToCloudStorageView.superview)
        [self.loginToCloudStorageView removeFromSuperview];

    //reload if we didn't come back from streaming
    _currentFolderId = @"";
    if([_googleDriveController.currentListFiles count] == 0)
        [self _requestInformationForCurrentFolderId];
}

#pragma mark - login dialog

- (void)_showLoginPanel
{
    self.loginToCloudStorageView.frame = self.tableView.frame;
    [self.view addSubview:self.loginToCloudStorageView];
}

- (IBAction)loginAction:(id)sender
{
    if (![_googleDriveController isAuthorized]) {
        _authorizationInProgress = YES;
        [self.navigationController pushViewController:[self createAuthController] animated:YES];
    } else {
        [_googleDriveController logout];
    }
}

@end
