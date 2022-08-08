//
//  HomeMusicPlayerView.m
//  Music
//
//  Created by edward lannister on 2022/08/05.
//  Copyright © 2022 KeKeStudio. All rights reserved.
//

#import "HomeMusicPlayerView.h"
#import "KKVideoPlayer.h"
#import "MusicControlView.h"
#import "MusicCell.h"

@interface HomeMusicPlayerView ()<KKVideoPlayerDelegate,MusicControlViewDelegate,UITableViewDataSource,UITableViewDelegate,KKRefreshHeaderViewDelegate>

@property (nonatomic , strong)UITableView *table;

@property (nonatomic , strong) MusicNavigationBarView *navBarView;
@property (nonatomic , strong) KKVideoPlayer *player;
@property (nonatomic , strong) MusicControlView *controlView;

@property (nonatomic , strong) NSMutableArray *dataSource;
@property (nonatomic , assign) NSInteger currentPlayIndex;
@property (nonatomic , assign) NSInteger playType;
@property (nonatomic , copy) NSString *playerIdentifer;
@property (nonatomic , assign) CGFloat tableViewOffset;

@property (nonatomic , copy) NSString *sys_artist_name;//歌手
@property (nonatomic , copy) NSString *sys_artist_album;//专辑名
@property (nonatomic , copy) UIImage *sys_artist_image;//图片

@end

@implementation HomeMusicPlayerView

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self kk_observeNotification:KKNotificationName_UIEventSubtypeRemoteControl selector:@selector(KKNotificationName_UIEventSubtypeRemoteControl:)];
        [self kk_observeNotification:KKNotificationName_StartPlayDataSouce selector:@selector(KKNotification_StartPlayDataSouce:)];
        [self kk_observeNotification:NotificationName_MusicDeleteFinished selector:@selector(Notification_MusicDeleteFinished:)];
        self.dataSource = [[NSMutableArray alloc] init];
        NSArray *array = [MusicDBManager.defaultManager DBQuery_Media_All];
        [self.dataSource addObjectsFromArray:array];
        self.playType = 1;
        
        self.currentPlayIndex = -1;
        [self initUI];
        
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
    return self;
}

- (void)initUI{
    self.navBarView = [[MusicNavigationBarView alloc] initWithFrame:CGRectMake(0, 0, KKScreenWidth, KKStatusBarAndNavBarHeight)];
    [self addSubview:self.navBarView];
    [self.navBarView setNavLeftButtonImage:KKThemeImage(@"Music_orderRandom") selector:@selector(navPlayTypeButtonClicked) target:self];
    [self.navBarView addShadow];
    
    //控制
    self.controlView = [[MusicControlView alloc] initWithFrame:CGRectMake(0, self.kk_height-160, self.kk_width, 160)];
    self.controlView.delegate = self;
    self.controlView.backgroundColor = [UIColor whiteColor];
    [self addSubview:self.controlView];
    
    self.table = [UITableView kk_initWithFrame:CGRectMake(0, self.navBarView.kk_height, KKScreenWidth, self.kk_height-self.navBarView.kk_height) style:UITableViewStylePlain delegate:self datasource:self];
    self.table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.table.separatorColor = [UIColor colorWithRed:0.86f green:0.87f blue:0.87f alpha:1.00f];
    [self addSubview:self.table];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, KKScreenWidth, 0.5)];
    [self.table setTableFooterView:header];
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, KKScreenWidth, self.controlView.kk_height)];
    [self.table setTableFooterView:footer];
    
    [self bringSubviewToFront:self.controlView];
    [self bringSubviewToFront:self.navBarView];
}

- (void)navPlayTypeButtonClicked{
    if (self.playType==0) {
        self.playType=1;
        [self.navBarView setNavLeftButtonImage:KKThemeImage(@"Music_orderRandom") selector:@selector(navPlayTypeButtonClicked) target:self];
    }
    else if (self.playType==1){
        self.playType=2;
        [self.navBarView setNavLeftButtonImage:KKThemeImage(@"Music_orderReplay") selector:@selector(navPlayTypeButtonClicked) target:self];
    }
    else{
        self.playType=0;
        [self.navBarView setNavLeftButtonImage:KKThemeImage(@"Music_order") selector:@selector(navPlayTypeButtonClicked) target:self];
    }
}


- (void)playPrev{
    //顺序播放
    if (self.playType==0) {
        self.currentPlayIndex = self.currentPlayIndex - 1;
        if (self.currentPlayIndex<0) {
            self.currentPlayIndex = self.dataSource.count-1;
        }
    }
    //随机播放
    else if (self.playType==1){
        self.currentPlayIndex = [NSNumber kk_randomIntegerBetween:0 and:(int)self.dataSource.count];
    }
    //单曲循环
    else{
        if (self.currentPlayIndex<0 || self.currentPlayIndex>=self.dataSource.count) {
            self.currentPlayIndex = 0;
        }
    }
    [self startPlayer];
}

- (void)playNext{
    //顺序播放
    if (self.playType==0) {
        self.currentPlayIndex = self.currentPlayIndex + 1;
        if (self.currentPlayIndex>=self.dataSource.count) {
            self.currentPlayIndex = 0;
        }
    }
    //随机播放
    else if (self.playType==1){
        self.currentPlayIndex = [NSNumber kk_randomIntegerBetween:0 and:(int)self.dataSource.count];
    }
    //单曲循环
    else{
        if (self.currentPlayIndex<0 || self.currentPlayIndex>=self.dataSource.count) {
            self.currentPlayIndex = 0;
        }
    }
    [self startPlayer];
}

- (void)startPlayer{
    [self clearPlayer];
    
    NSDictionary *info = [self.dataSource objectAtIndex:self.currentPlayIndex];
    NSString *identifier = [info kk_validStringForKey:Table_Media_identifier];
    NSString *local_name = [info kk_validStringForKey:Table_Media_local_name];
    [self.navBarView setTitle:local_name autoResize:YES];
    NSString *filePath = [KKFileCacheManager cacheDataPath:identifier];
    long long fileSize = [NSFileManager kk_fileSizeAtPath:filePath];
    if (fileSize>(1024*2)) {
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        self.player = [[KKVideoPlayer alloc] initWithFrame:CGRectMake(0, 0, 1, 1) URLString:[fileURL absoluteString]];
        self.player.delegate = self;
        [self addSubview:self.player];
        self.player.hidden = YES;
        [self.player.player  setPauseInBackground:NO];
        self.playerIdentifer = [NSString kk_randomString:10];
        self.player.kk_tagInfo = self.playerIdentifer;
        [self.player startPlay];

        AVURLAsset *avURLAsset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
        for (NSString *format in [avURLAsset availableMetadataFormats]) {
            for (AVMetadataItem *metadata in [avURLAsset metadataForFormat:format]) {
//                //歌名
//                if([metadata.commonKey isEqualToString:@"title"]){
//                    NSString *title = (NSString*)metadata.value;
//                }
                //歌手
                if([metadata.commonKey isEqualToString:@"artist"]){
                    NSString *title = (NSString*)metadata.value;
                    self.sys_artist_name = title;
                }
                //专辑名
                if([metadata.commonKey isEqualToString:@"albumName"]){
                    NSString *title = (NSString*)metadata.value;
                    self.sys_artist_album = title;
                }
                
                //图片
                if([metadata.commonKey isEqualToString:@"artwork"]){
                    if (metadata.value && [metadata.value isKindOfClass:[NSData class]]) {
                        self.sys_artist_image = [UIImage imageWithData:(NSData*)metadata.value];
                    }
                }
            }
        }

        
        [self.table reloadData];
        [self.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.currentPlayIndex inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:NO];
        self.controlView.hidden = NO;
    }
    else{
        [self.dataSource removeObject:info];
        [self playNext];
    }
}

- (void)clearPlayer{
    if (self.player) {
        self.sys_artist_name = nil;
        self.sys_artist_album = nil;
        self.sys_artist_image = nil;
        self.playerIdentifer = nil;
        [self.player stopPlay];
        [self.player removeFromSuperview];
        self.player = nil;
    }
}

#pragma mark ==================================================
#pragma mark == 通知
#pragma mark ==================================================
- (void)KKNotification_StartPlayDataSouce:(NSNotification*)notice{
    NSArray *array = notice.object;
    [self.dataSource removeAllObjects];
    [self.dataSource addObjectsFromArray:array];
    [self.table reloadData];
    
    [self clearPlayer];
    self.currentPlayIndex = -1;
    [self playNext];
}

- (void)KKNotificationName_UIEventSubtypeRemoteControl:(NSNotification*)notice{
    
    UIEventSubtype subType = [notice.object integerValue];
    switch (subType) {
        case UIEventSubtypeNone:{
            break;
        }
        case UIEventSubtypeMotionShake:{
            break;
        }
        case UIEventSubtypeRemoteControlPlay:{//点击播放按钮或者耳机线控中间那个按钮
            if (self.player) {
                [self.player startPlay];
            }
            else{
                [self playNext];
            }
            break;
        }
        case UIEventSubtypeRemoteControlPause:{//点击暂停按钮
            if (self.player) {
                [self.player pausePlay];
            }
            break;
        }
        case UIEventSubtypeRemoteControlStop:{//点击停止按钮
            [self clearPlayer];
            break;
        }
        case UIEventSubtypeRemoteControlTogglePlayPause:{//点击播放与暂停开关按钮(iphone抽屉中使用这个)
            break;
        }
        case UIEventSubtypeRemoteControlNextTrack:{//点击下一曲按钮或者耳机中间按钮两下
            [self playNext];
            break;
        }
        case UIEventSubtypeRemoteControlPreviousTrack:{//点击上一曲按钮或者耳机中间按钮三下
            [self playPrev];
            break;
        }
        case UIEventSubtypeRemoteControlBeginSeekingBackward:{//快退开始 点击耳机中间按钮三下不放开
            break;
        }
        case UIEventSubtypeRemoteControlEndSeekingBackward:{//快退结束 耳机快退控制松开后
            break;
        }
        case UIEventSubtypeRemoteControlBeginSeekingForward:{//开始快进 耳机中间按钮两下不放开
            break;
        }
        case UIEventSubtypeRemoteControlEndSeekingForward:{//快进结束 耳机快进操作松开后
            break;
        }
        default:
            break;
    }
}

- (void)Notification_MusicDeleteFinished:(NSNotification*)notice{
    NSString *delIdentifier = notice.object;
    
    for (NSInteger i=0; i<[self.dataSource count]; i++) {
        NSDictionary *info = [self.dataSource objectAtIndex:i];
        NSString *identifier = [info kk_validStringForKey:Table_Media_identifier];
        if ([identifier isEqualToString:delIdentifier]) {
            if (i==self.currentPlayIndex) {
                [self clearPlayer];
                [self.dataSource removeObject:info];
                [self.table reloadData];
                [self playNext];
                break;;
            }
            else{
                [self.dataSource removeObject:info];
                [self.table reloadData];
                break;;
            }
        }
    }
}

#pragma mark ==================================================
#pragma mark == MusicControlViewDelegate
#pragma mark ==================================================
- (void)MusicControlView_PrevButtonClicked:(MusicControlView*)aView{
    [self playPrev];
}

- (void)MusicControlView_NextButtonClicked:(MusicControlView*)aView{
    [self playNext];
}

- (void)MusicControlView_PlayButtonClicked:(MusicControlView*)aView{
    if (self.player) {
        [self.player startPlay];
    }
    else{
        [self playNext];
    }
}

- (void)MusicControlView_PauseButtonClicked:(MusicControlView*)aView{
    [self.player pausePlay];
}

- (void)MusicControlView:(MusicControlView*)aView currentTimeChanged:(NSTimeInterval)aCurrentTime{
    [self.player seekToBackTime:aCurrentTime];
}


#pragma mark ==================================================
#pragma mark == KKVideoPlayerDelegate
#pragma mark ==================================================
//准备播放
- (void)KKVideoPlayer_IJKMediaPlaybackIsPreparedToPlayDidChange:(NSDictionary*)aVideoInfo
                                                      audioInfo:(NSDictionary*)aAudioInfo{
    
}

//获取到视频信息
- (void)KKVideoPlayer_VideoInfoDecoded:(NSDictionary*)aVideoInfo{
    
}

//播放开始
- (void)KKVideoPlayer_PlayDidStart:(KKVideoPlayer*)player{
    [self.controlView setButtonStatusPlaying];
}

//继续开始
- (void)KKVideoPlayer_PlayDidContinuePlay:(KKVideoPlayer*)player{
    [self.controlView setButtonStatusPlaying];
}

//播放结束
- (void)KKVideoPlayer_PlayDidFinished:(KKVideoPlayer*)player{
    [self.controlView setButtonStatusStop];
    self.controlView.currentTime = 0;
    self.controlView.durationtime = 1.0;
    self.controlView.mySlider.value = 0;
    
    if ([self.playerIdentifer isEqualToString:player.kk_tagInfo]) {
        [self playNext];
    }
}

//播放暂停
- (void)KKVideoPlayer_PlayDidPause:(KKVideoPlayer*)player{
    [self.controlView setButtonStatusStop];
}

//播放错误
- (void)KKVideoPlayer_CanNotPlay:(KKVideoPlayer*)player{
    [self.controlView setButtonStatusStop];
    self.controlView.currentTime = 0;
    self.controlView.durationtime = 1.0;
    self.controlView.mySlider.value = 0;

    if ([self.playerIdentifer isEqualToString:player.kk_tagInfo]) {
        [self playNext];
    }
}

//播放时间改变
- (void)KKVideoPlayer:(KKVideoPlayer*)player playBackTimeChanged:(NSTimeInterval)currentTime durationtime:(NSTimeInterval)durationtime{
    
    NSDictionary *info = [self.dataSource objectAtIndex:self.currentPlayIndex];
    NSString *local_name = [info kk_validStringForKey:Table_Media_local_name];

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
   //设置歌曲题目
   [dict setObject:local_name forKey:MPMediaItemPropertyTitle];
   //设置歌手名
    [dict setObject:self.sys_artist_name?self.sys_artist_name:@"" forKey:MPMediaItemPropertyArtist];
   //设置专辑名
   [dict setObject:self.sys_artist_album?self.sys_artist_album:@"" forKey:MPMediaItemPropertyAlbumTitle];
   //设置显示的图片
    if (self.sys_artist_image) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(KKScreenWidth, KKScreenWidth) requestHandler:^UIImage * _Nonnull(CGSize size) {
            return self.sys_artist_image;
        }];
        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }
    else{
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(KKScreenWidth, KKScreenWidth) requestHandler:^UIImage * _Nonnull(CGSize size) {
            return KKThemeImage(@"Music_placeholder");
        }];
        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }
   //设置歌曲时长
   [dict setObject:[NSNumber numberWithDouble:durationtime] forKey:MPMediaItemPropertyPlaybackDuration];
   //设置已经播放时长
   [dict setObject:[NSNumber numberWithDouble:currentTime] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
   //更新字典
   [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];

    if (self.controlView.isSliderTouched==NO) {
        self.controlView.currentTime = currentTime;
        self.controlView.durationtime = durationtime;
        self.controlView.mySlider.value = currentTime;
    }
}

#pragma mark ========================================
#pragma mark ==UITableView
#pragma mark ========================================
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self.dataSource count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 0.1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, KKScreenWidth, 0.1)];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return 0.1;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, KKScreenWidth, 0.1)];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return [MusicCell cellHeightWithInformation:[self.dataSource objectAtIndex:indexPath.row]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellIdentifier1=@"cellIdentifier1";
    MusicCell *cell=[tableView dequeueReusableCellWithIdentifier:cellIdentifier1];
    if (!cell) {
        cell=[[MusicCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier1];
        cell.accessoryType=UITableViewCellAccessoryNone;
    }
    
    NSDictionary *info = [self.dataSource objectAtIndex:indexPath.row];;
    [cell reloadWithInformation:info];
    if (indexPath.row==self.currentPlayIndex) {
        cell.name_Label.textColor = Theme_Color_D31925;
    }
    else{
        cell.name_Label.textColor = [UIColor blackColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    self.currentPlayIndex = indexPath.row;
    [self startPlayer];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if (scrollView.contentOffset.y>self.tableViewOffset+25) {
        self.tableViewOffset = scrollView.contentOffset.y;
        self.controlView.hidden = YES;
    }
    else if (self.tableViewOffset > scrollView.contentOffset.y+25)
    {
        self.tableViewOffset = scrollView.contentOffset.y;
        self.controlView.hidden = NO;
    }
    
//    if (scrollView.contentOffset.y>self.tableViewOffset+5) {
//        self.controlView.hidden = YES;
//    }
//    else{
//        self.controlView.hidden = NO;
//    }
}

// called on start of dragging (may require some time and or distance to move)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.tableViewOffset = scrollView.contentOffset.y;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if (decelerate==NO) {
        self.controlView.hidden = NO;
    }
}

//- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
//    self.controlView.hidden = NO;
//}
//
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    self.controlView.hidden = NO;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    KKWeakSelf(self);
    //删除
    UIContextualAction *deleteRowAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        NSDictionary *info = [weakself.dataSource objectAtIndex:indexPath.row];
        NSString *identifier = [info kk_validStringForKey:Table_Media_identifier];
        
        //删除缓存数据
        [KKFileCacheManager deleteCacheData:identifier];
        //删除音乐-Tag关系表
        [MusicDBManager.defaultManager DBDelete_MediaTag_WithMediaIdentifer:identifier];
        //删除音乐表
        [MusicDBManager.defaultManager DBDelete_Media_WithIdentifer:identifier];
        
        completionHandler (YES);
        
        [weakself.dataSource removeObject:info];
        [weakself.table reloadData];
    }];
    deleteRowAction.backgroundColor = [UIColor kk_colorWithHexString:@"#FF4646"];

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteRowAction]];
    return config;
}


@end
