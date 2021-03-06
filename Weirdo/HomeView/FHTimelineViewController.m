//
//  FHTimelineViewController.m
//  Weirdo
//
//  Created by FengHuan on 14-4-10.
//  Copyright (c) 2014年 FengHuan. All rights reserved.
//

#import "FHTimelineViewController.h"
#import "FHOPViewController.h"
#import "FHPostViewController.h"
#import "FHWebViewController.h"
#import "FHImageScrollView.h"
#import "FHFirstViewController.h"

#define REFRESH_TIMEINTERVAL 15*60

@interface FHTimelineViewController ()
{
    NSMutableArray *posts;
    BOOL needRefresh;
    FHWebViewController *webVC;
    NSMutableArray *reportedIDs;
}

@end

@implementation FHTimelineViewController

@synthesize pullTableView, category;

- (id)initWithTimeline:(TimelineCategory)timelineCategory
{
    self = [super init];
    if (self) {
        category = timelineCategory;
        posts = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    reportedIDs = [[NSMutableArray alloc] init];
    needRefresh = YES;
    pullTableView = [[PullTableView alloc] initWithFrame:self.view.frame style:UITableViewStylePlain];
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, [UIScreen mainScreen].bounds.size.height - 64);
    pullTableView = [[PullTableView alloc] initWithFrame:frame style:UITableViewStylePlain];
    [self.view addSubview:pullTableView];
    [pullTableView setDelegate:self];
    [pullTableView setDataSource:self];
    [pullTableView setPullDelegate:self];
    self.pullTableView.pullArrowImage = [UIImage imageNamed:@"grayArrow"];
    self.pullTableView.pullBackgroundColor = [UIColor whiteColor];
    self.pullTableView.pullTextColor = [UIColor grayColor];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (self.category != TimelineCategoryHome && [UIDevice currentDevice].systemVersion.doubleValue == 7.0) {
        CGRect frame = pullTableView.frame;
        frame.origin.y = 64;
        pullTableView.frame = frame;
        
    }
    [super viewWillAppear:animated];
    if(!self.pullTableView.pullTableIsRefreshing && needRefresh) {
        self.pullTableView.pullTableIsRefreshing = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    if (needRefresh) {
        [self pullDownToRefresh];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (self.category == TimelineCategoryHome && [UIDevice currentDevice].systemVersion.doubleValue == 7.0) {
        CGRect frame = pullTableView.frame;
        frame.origin.y = 64;
        pullTableView.frame = frame;
        
    }
    needRefresh = NO;
}

- (void)viewDidUnload
{
    [self setPullTableView:nil];
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) loadMoreDataToTable
{
    if (!pullTableView.pullTableIsLoadingMore) {
        [self pullUpToRefresh];
    }
}

- (void)pullDownToRefresh
{
    FHConnectionInterationProperty *property = [[FHConnectionInterationProperty alloc ] init];
    [property setAfterFailedTarget:self];
    [property setAfterFailedSelector:@selector(fetchFailedWithNetworkError:)];
    [property setAfterFinishedTarget:self];
    [property setAfterFinishedSelector:@selector(fetchNewerFinishedWithResponseDic:)];
    
    FHPost *post = (posts && posts.count > 0) ? [posts objectAtIndex:0] : nil;
    if (pullTableView.pullLastRefreshDate) {
        NSTimeInterval interval = [[NSDate new] timeIntervalSinceDate:pullTableView.pullLastRefreshDate];
        if (interval > REFRESH_TIMEINTERVAL) {
            post = nil;
        }
    }
    
    switch (category) {
        case TimelineCategoryHome:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchHomePostsNewer:YES thanPost:post interactionProperty:property];
            break;
        case TimelineCategoryFriends:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchBilateralPostsNewer:YES thanPost:post interactionProperty:property];
            break;
        case TimelineCategoryPublic:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchPublicPostsWithInteractionProperty:property];
            break;
        default:
            break;
    }
}

- (void)pullUpToRefresh
{
    FHConnectionInterationProperty *property = [[FHConnectionInterationProperty alloc ] init];
    [property setAfterFailedTarget:self];
    [property setAfterFailedSelector:@selector(fetchFailedWithNetworkError:)];
    [property setAfterFinishedTarget:self];
    [property setAfterFinishedSelector:@selector(fetchLaterFinishedWithResponseDic:)];
    switch (category) {
        case TimelineCategoryHome:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchHomePostsNewer:NO thanPost:[posts lastObject] interactionProperty:property];
            break;
        case TimelineCategoryFriends:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchBilateralPostsNewer:NO thanPost:[posts lastObject] interactionProperty:property];
            break;
        case TimelineCategoryPublic:
            [[FHWeiBoAPI sharedWeiBoAPI] fetchPublicPostsWithInteractionProperty:property];
            break;
        default:
            break;
    }
}

- (void)fetchNewerFinishedWithResponseDic:(NSDictionary *)responseDic
{
    
    NSArray *postsArray = [responseDic objectForKey:@"statuses"];
    
    NSTimeInterval interval = MAXFLOAT;
    if (pullTableView.pullLastRefreshDate) {
        interval = [[NSDate new] timeIntervalSinceDate:pullTableView.pullLastRefreshDate];
    }
    
    NSMutableArray *freshPosts;
    if (interval > REFRESH_TIMEINTERVAL) {
        freshPosts = [[NSMutableArray alloc] init];
    }else{
        freshPosts = [NSMutableArray arrayWithArray:posts];
    }
    if (postsArray && postsArray.count > 0)
    {
        for (int i = (int)postsArray.count; i>0; i--) {
            NSDictionary *postDic = [postsArray objectAtIndex:i-1];
            FHPost *post = [[FHPost alloc] initWithPostDic:postDic];
            if ([reportedIDs containsObject:post.ID]) {
                continue;
            }
            [freshPosts insertObject:post atIndex:0];
        }
        posts = freshPosts;
        [pullTableView reloadData];
    }
    self.pullTableView.pullLastRefreshDate = [NSDate date];
    self.pullTableView.pullTableIsRefreshing = NO;
}

- (void)fetchLaterFinishedWithResponseDic:(NSDictionary *)responseDic
{
    NSArray *postsArray = [responseDic objectForKey:@"statuses"];
    if (postsArray && postsArray.count > 0) {
        NSMutableArray *freshPosts = [NSMutableArray arrayWithArray:posts];
        for (int i=0; i<postsArray.count; i++) {
            if (i == 0) {
                continue;
            }
            FHPost *post = [[FHPost alloc] initWithPostDic:[postsArray objectAtIndex:i]];
            if ([reportedIDs containsObject:post.ID]) {
                continue;
            }
            [freshPosts addObject:post];
        }
        posts = freshPosts;
        [pullTableView reloadData];
    }
    self.pullTableView.pullTableIsLoadingMore = NO;
}

- (void)fetchFailedWithNetworkError:(NSError *)error
{
    self.pullTableView.pullTableIsLoadingMore = NO;
    self.pullTableView.pullTableIsRefreshing = NO;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"出错啦" message:error.localizedDescription delegate:self cancelButtonTitle:@"知道啦" otherButtonTitles:nil, nil];
    alert.tag = error.code;
    [alert show];
}

#pragma mark
#pragma mark - Table view data source & delagate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return posts ? posts.count : 0;;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FHTimelinePostCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PostCell"];
    if (cell == nil) {
        cell = [[FHTimelinePostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PostCell"];
    }
    
    [cell updateCellWithPost:[posts objectAtIndex:indexPath.row] isPostOnly:NO];
    [cell setIndexPath:indexPath];
    [cell setDelegate:self];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [FHTimelinePostCell cellHeightWithPost:[posts objectAtIndex:indexPath.row] isPostOnly:NO];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FHPostViewController *postVC = [[FHPostViewController alloc] init];
    [postVC setPost:[posts objectAtIndex:indexPath.row]];
    [self.navigationController pushViewController:postVC animated:YES];
}

#pragma mark
#pragma mark - timelinePostCell delegate

- (void)timelinePostCell:(FHTimelinePostCell *)cell didSelectAtIndexPath:(NSIndexPath *)indexPath withClickedType:(CellClickedType)clickedType contentIndex:(NSUInteger)index
{

    switch (clickedType) {
        case CellClickedTypeRetweet:{
            FHOPViewController *opVC = [[FHOPViewController alloc] init];
            [opVC setupWithPost:[posts objectAtIndex:indexPath.row] operation:StatusOperationRetweet];
            [self presentViewController:opVC animated:YES completion:NULL];
            break;
        }
        case CellClickedTypeComment:{
            FHOPViewController *opVC = [[FHOPViewController alloc] init];
            [opVC setupWithPost:[posts objectAtIndex:indexPath.row] operation:StatusOperationComment];
            [self presentViewController:opVC animated:YES completion:NULL];
            break;
        }
        case CellClickedTypeVote:
            NSLog(@"index: %d, vote", (int)indexPath.row);
            break;
        case CellClickedTypePictures:
        {
            NSArray *imageURLs;
            FHPost *post = [posts objectAtIndex:indexPath.row];
            if (post.picURLs.count > 0) {
                imageURLs = post.picURLs;
            }else
                imageURLs = post.retweeted.picURLs;
            if (index < imageURLs.count) {
                FHImageScrollView *imageScrollView = [[FHImageScrollView alloc] initWithImageURLs:imageURLs currentIndex:index];
                [self.navigationController.view addSubview:imageScrollView];
                [imageScrollView show];
            }
            break;
        }
        case CellClickedTypeUserImage:
            break;
        case CellClickedTypeReport:{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"举报" message:@"已收到举报信息，将尽快反馈给新浪微博，在此期间，Weirdo暂时屏蔽此条微博！感谢您的支持与理解" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
            [alert show];
            FHPost *post = [posts objectAtIndex:indexPath.row];
            [reportedIDs addObject:post.ID];
            [pullTableView beginUpdates];
            [posts removeObjectAtIndex:indexPath.row];
            [pullTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [pullTableView endUpdates];
            break;
        }
        default:
            break;
    }
    needRefresh = NO;
}

- (void)timelinePostCell:(FHTimelinePostCell *)cell didSelectLink:(NSString *)link
{
    if (!webVC) {
        webVC = [[FHWebViewController alloc] initWithLink:link];
    }else
        [webVC setLink:link];
    [self.navigationController pushViewController:webVC animated:YES];
}

#pragma mark
#pragma mark - PullTableViewDelegate

- (void)pullTableViewDidTriggerRefresh:(PullTableView *)pullTableView
{
    [self pullDownToRefresh];
}

- (void)pullTableViewDidTriggerLoadMore:(PullTableView *)pullTableView
{
    [self pullUpToRefresh];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == ERROR_TOKEN_INVALID) {
        FHFirstViewController *relogin = [[FHFirstViewController alloc] init];
        relogin.reLogin = YES;
        [self presentViewController:relogin animated:YES completion:NULL];
    }
}

@end
