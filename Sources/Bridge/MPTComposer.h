#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// AVFoundation 合成桥（ObjC 实现）：拼接 / 转场 / 字幕烧录 / BGM 混音 / 画幅 / 导出
/// 对应原版 services/video.py + video_composer.py（ffmpeg 等价的 AVFoundation 实现）
@interface MPTComposer : NSObject

/// 合成视频
/// clips          素材本地 URL 列表
/// subtitleImages 与 clips 等长的字幕 PNG URL（NSNull 表示该片段无字幕），可为空数组
/// narration      配音音频 URL（可空），bgm 背景乐 URL（可空）
/// config 键：width/height/clipDuration/fitCover/transition/voiceVolume/bgmVolume
+ (void)composeClips:(NSArray<NSURL *> *)clips
           subtitles:(NSArray *)subtitleImages
           narration:(nullable NSURL *)narration
                 bgm:(nullable NSURL *)bgm
              config:(NSDictionary<NSString *, id> *)config
              outURL:(NSURL *)outURL
            progress:(nullable void (^)(double value))progress
          completion:(void (^)(NSError * _Nullable error))completion;

/// 本机语音快速试听（正式配音仍走 Edge/Azure）
+ (void)previewVoice:(NSString *)text rate:(float)rate;

@end

NS_ASSUME_NONNULL_END
