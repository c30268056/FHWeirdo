//
//  FHTimelinePostCell.h
//  Weirdo
//
//  Created by FengHuan on 14-3-31.
//  Copyright (c) 2014年 FengHuan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FHContentImageView.h"
#import "FHTweetLabel.h"

@class FHTimelinePostCell;

typedef enum : NSUInteger {
    CellClickedTypePictures,
    CellClickedTypeRetweet,
    CellClickedTypeComment,
    CellClickedTypeVote,
} CellClickedType;

@protocol FHTimelinPostCellDelegate <NSObject>

- (void)timelinePostCell:(FHTimelinePostCell *)cell didSelectAtIndexPath:(NSIndexPath *)indexPath withClickedType:(CellClickedType)clickedType contentIndex:(NSUInteger)index;

@end

@interface FHTimelinePostCell : UITableViewCell <FHContentImageViewDelegate>

@property (strong, nonatomic) UIImageView *userImage;
@property (strong, nonatomic) UILabel *userNameLB;
@property (strong, nonatomic) UILabel *timeLB;
@property (strong, nonatomic) UILabel *fromLB;
@property (nonatomic, strong) FHTweetLabel *content;
@property (nonatomic, strong) UIImageView *retweetStatusBackground;
@property (nonatomic, strong) FHTweetLabel *retweetContent;
@property (nonatomic, strong) FHContentImageView *contentImageView;
@property (strong, nonatomic) UILabel *voteCountLB;
@property (strong, nonatomic) UILabel *retweetCountLB;
@property (strong, nonatomic) UILabel *commentCountLB;
@property (strong, nonatomic) NSIndexPath *indexPath;
@property (strong, nonatomic) id<FHTimelinPostCellDelegate> delegate;

- (void)updateCellWithPost:(FHPost *)post;
+ (float)cellHeightWithPost:(FHPost *)post;

@end
