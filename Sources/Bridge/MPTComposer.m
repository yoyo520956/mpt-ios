#import "MPTComposer.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

@implementation MPTComposer

/// KVC 容错写入：不同 SDK 里同一语义属性可能换名，逐个 key 尝试
+ (void)setValue:(id)value forKeys:(NSArray<NSString *> *)keys on:(id)obj {
    for (NSString *k in keys) {
        @try { [obj setValue:value forKey:k]; return; } @catch (NSException *e) { }
    }
}

/// 音量参数对象（运行时构造，避免头文件差异）
+ (nullable id)mixInput:(CMPersistentTrackID)trackID volume:(float)volume {
    Class cls = NSClassFromString(@"AVMutableAudioMixInputTrack");
    if (!cls) return nil;
    id obj = [[cls alloc] init];
    @try {
        [obj setValue:@(trackID) forKey:@"trackID"];
        [obj setValue:@(volume) forKey:@"volume"];
        return obj;
    } @catch (NSException *e) {
        return nil;
    }
}

+ (void)composeClips:(NSArray<NSURL *> *)clips
           subtitles:(NSArray *)subtitleImages
           narration:(NSURL *)narration
                 bgm:(NSURL *)bgm
              config:(NSDictionary<NSString *, id> *)config
              outURL:(NSURL *)outURL
            progress:(void (^)(double))progress
          completion:(void (^)(NSError *))completion {

    int W = config[@"width"] ? [config[@"width"] intValue] : 1080;
    int H = config[@"height"] ? [config[@"height"] intValue] : 1920;
    double clipDuration = config[@"clipDuration"] ? [config[@"clipDuration"] doubleValue] : 5.0;
    BOOL fitCover = [config[@"fitCover"] boolValue];
    NSString *transition = [config[@"transition"] isKindOfClass:[NSString class]] ? config[@"transition"] : @"none";
    float voiceVolume = config[@"voiceVolume"] ? [config[@"voiceVolume"] floatValue] : 1.0f;
    float bgmVolume = config[@"bgmVolume"] ? [config[@"bgmVolume"] floatValue] : 0.2f;

    AVMutableComposition *comp = [AVMutableComposition composition];
    NSMutableArray *instructions = [NSMutableArray array];
    CMTime cursor = kCMTimeZero;

    for (NSUInteger i = 0; i < clips.count; i++) {
        @autoreleasepool {
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:clips[i] options:nil];
            AVAssetTrack *srcTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
            if (!srcTrack) continue;

            double n = CMTimeGetSeconds(asset.duration);
            double dur = (n > 0.3) ? MIN(MAX(n - 0.4, 0.8), clipDuration) : clipDuration;
            CMTime clipLen = CMTimeMakeWithSeconds(dur, 600);

            AVMutableCompositionTrack *vt = [comp addMutableTrackWithMediaType:AVMediaTypeVideo
                                                             preferredTrackID:kCMPersistentTrackID_Invalid];
            if (!vt) continue;
            NSError *insErr = nil;
            if (![vt insertTimeRange:CMTimeRangeMake(kCMTimeZero, clipLen)
                             ofTrack:srcTrack
                              atTime:cursor
                               error:&insErr]) {
                continue;
            }

            CGSize size = srcTrack.naturalSize;
            if (size.width < 1 || size.height < 1) size = CGSizeMake(W, H);
            double s = fitCover ? MAX((double)W / size.width, (double)H / size.height)
                                : MIN((double)W / size.width, (double)H / size.height);
            double scale = s * (fitCover ? 1.10 : 1.0);

            AVMutableVideoCompositionLayerInstruction *li =
                [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:vt];
            CGAffineTransform start = CGAffineTransformMakeScale(scale, scale);
            CGAffineTransform end = start;
            CMTime endTime = CMTimeAdd(cursor, clipLen);
            if ([transition isEqualToString:@"ZoomIn"]) {
                start = CGAffineTransformMakeScale(scale * 0.82, scale * 0.82);
            } else if ([transition isEqualToString:@"ZoomOut"]) {
                end = CGAffineTransformMakeScale(scale * 0.82, scale * 0.82);
            } else if ([transition isEqualToString:@"SlideIn"]) {
                start = CGAffineTransformMakeTranslation(-size.width * scale, 0);
            } else if ([transition isEqualToString:@"SlideOut"]) {
                end = CGAffineTransformMakeTranslation(size.width * scale, 0);
            }
            [li setTransform:start atTime:cursor];
            [li setTransform:end atTime:endTime];

            AVMutableVideoCompositionInstruction *instr =
                [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            NSValue *trValue = [NSValue value:&(CMTimeRange){cursor, clipLen} withObjCType:@encode(CMTimeRange)];
            [MPTComposer setValue:trValue forKeys:@[@"timeRange"] on:instr];
            [MPTComposer setValue:@[li] forKeys:@[@"layerInstructions", @"videoLayerInstructions"] on:instr];

            if (i < subtitleImages.count && [subtitleImages[i] isKindOfClass:[NSURL class]]) {
                CIImage *ci = [CIImage imageWithContentsOfURL:subtitleImages[i]];
                CIFilter *f = [CIFilter filterWithName:@"CIComposite"];
                if (ci && f) {
                    [f setValue:@"videoLayer" forKey:kCIInputImageKey];
                    [f setValue:ci forKey:@"inCompositeImage"];
                    [MPTComposer setValue:@[f] forKeys:@[@"filters"] on:instr];
                }
            }

            [instructions addObject:instr];
            cursor = endTime;
            if (progress) {
                double p = 0.4 * (double)(i + 1) / (double)MAX((NSUInteger)1, clips.count);
                progress(p);
            }
        }
    }

    if (instructions.count == 0) {
        if (completion) {
            completion([NSError errorWithDomain:@"MPTComposer" code:1
                                       userInfo:@{NSLocalizedDescriptionKey: @"没有可用素材片段"}]);
        }
        return;
    }

    // ---- 音轨：配音 + BGM（循环填充）----
    CMTime total = cursor;
    double totalSec = CMTimeGetSeconds(total);
    NSMutableArray *mixInputs = [NSMutableArray array];

    if (narration) {
        AVURLAsset *na = [AVURLAsset URLAssetWithURL:narration options:nil];
        AVAssetTrack *nt = [[na tracksWithMediaType:AVMediaTypeAudio] firstObject];
        if (nt) {
            AVMutableCompositionTrack *ct = [comp addMutableTrackWithMediaType:AVMediaTypeAudio
                                                             preferredTrackID:kCMPersistentTrackID_Invalid];
            double nd = CMTimeGetSeconds(na.duration);
            double len = (nd > 0 && nd < totalSec) ? nd : totalSec;
            if (ct && len > 0.1) {
                NSError *e = nil;
                if ([ct insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(len, 600))
                                ofTrack:nt atTime:kCMTimeZero error:&e]) {
                    id p = [MPTComposer mixInput:ct.trackID volume:voiceVolume];
                    if (p) [mixInputs addObject:p];
                }
            }
        }
    }

    if (bgm) {
        AVURLAsset *ba = [AVURLAsset URLAssetWithURL:bgm options:nil];
        AVAssetTrack *bt = [[ba tracksWithMediaType:AVMediaTypeAudio] firstObject];
        double bd = bt ? CMTimeGetSeconds(ba.duration) : 0;
        if (bt && bd > 0.2 && totalSec > 0.2) {
            AVMutableCompositionTrack *ct = [comp addMutableTrackWithMediaType:AVMediaTypeAudio
                                                             preferredTrackID:kCMPersistentTrackID_Invalid];
            if (ct) {
                CMTime off = kCMTimeZero;
                BOOL ok = YES;
                while (CMTimeGetSeconds(off) < totalSec - 0.05) {
                    double seg = MIN(bd, totalSec - CMTimeGetSeconds(off));
                    NSError *e = nil;
                    if (![ct insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(seg, 600))
                                     ofTrack:bt atTime:off error:&e]) { ok = NO; break; }
                    off = CMTimeAdd(off, CMTimeMakeWithSeconds(seg, 600));
                }
                if (ok) {
                    id p = [MPTComposer mixInput:ct.trackID volume:bgmVolume];
                    if (p) [mixInputs addObject:p];
                }
            }
        }
    }

    AVMutableAudioMix *mix = nil;
    if (mixInputs.count > 0) {
        mix = [AVMutableAudioMix audioMix];
        [MPTComposer setValue:mixInputs forKeys:@[@"inputs", @"inputParameters"] on:mix];
    }

    // ---- 导出 ----
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:comp
                                                                    presetName:AVAssetExportPresetHighestQuality];
    if (!session) {
        if (completion) {
            completion([NSError errorWithDomain:@"MPTComposer" code:2
                                       userInfo:@{NSLocalizedDescriptionKey: @"无法创建导出会话"}]);
        }
        return;
    }
    session.outputURL = outURL;
    session.outputFileType = AVFileTypeMPEG4;
    session.videoComposition = vc;
    if (mix) session.audioMix = mix;
    session.shouldOptimizeForNetworkUse = YES;

    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                              (uint64_t)(0.4 * NSEC_PER_SEC), (uint64_t)(0.05 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if (progress) progress(0.4 + 0.55 * (double)session.progress);
    });
    dispatch_resume(timer);

    [session exportAsynchronouslyWithCompletionHandler:^{
        dispatch_source_cancel(timer);
        NSError *err = session.error;
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(err); });
        }
    }];
}

@end
