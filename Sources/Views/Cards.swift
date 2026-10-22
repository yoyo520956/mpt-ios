import SwiftUI

// 1:1 还原原版四张设置卡片（docs/webui.jpg 实测控件清单）

struct ScriptCard: View {
    @EnvironmentObject private var config: ConfigStore
    @State private var showAdvanced = false
    @State private var busy = false

    var body: some View {
        MPTCard(title: "文案设置") {
            MPTTextField(title: "视频主题 (AI 将根据主题生成视频文案)",
                         placeholder: "例如：人工智能如何改变日常生活",
                         text: $config.params.videoSubject)
            MPTSelectRow(title: "生成视频脚本的语言",
                         options: MPTConst.scriptLanguages,
                         selection: $config.params.videoLanguage)
            DisclosureGroup("高级脚本设置", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: MPTStyle.s2) {
                    MPTSelectRow(title: "段落数",
                                 options: [("1", "1"), ("2", "2"), ("3", "3"), ("4", "4"), ("5", "5")],
                                 selection: $config.params.paragraphNumberRaw)
                    MPTMultilineField(title: "自定义系统提示词", text: $config.params.customSystemPrompt)
                    MPTMultilineField(title: "视频脚本提示词", text: $config.params.videoScriptPrompt)
                }
                .padding(.top, MPTStyle.s2)
            }
            .font(MPTStyle.body())
            MPTAccentButton(title: "点击使用AI生成视频文案和关键词", icon: "sparkles") {
                Task { await generateScript() }
            }
            MPTMultilineField(title: "视频文案（可选）", text: $config.params.videoScript)
            MPTAccentButton(title: "点击使用AI根据文案生成视频关键词", icon: "sparkles") {
                Task { await generateTerms() }
            }
            MPTMultilineField(title: "视频关键词（英文，可选）", text: $config.params.videoTerms)
        }
    }

    private func generateScript() async {
        busy = true
        defer { busy = false }
        do {
            let s = try await LLMService.shared.generateScript(
                subject: config.params.videoSubject, language: config.params.videoLanguage,
                paragraphNumber: config.params.paragraphNumber,
                scriptPrompt: config.params.videoScriptPrompt,
                systemPrompt: config.params.customSystemPrompt, config: config)
            config.params.videoScript = s
        } catch { MPTLog.error("脚本生成失败 \(error.localizedDescription)") }
    }

    private func generateTerms() async {
        do {
            let t = try await LLMService.shared.generateTerms(
                subject: config.params.videoSubject, script: config.params.videoScript,
                amount: 5, config: config)
            config.params.videoTerms = t
        } catch { MPTLog.error("关键词生成失败 \(error.localizedDescription)") }
    }
}

struct VideoCard: View {
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        MPTCard(title: "视频设置") {
            MPTSelectRow(title: "视频来源",
                         options: MPTConst.videoSources,
                         selection: $config.params.videoSource)
            MPTSelectRow(title: "视频拼接模式",
                         options: MPTConst.concatModes,
                         selection: $config.params.videoConcatModeRaw)
            MPTCheckRow(title: "按文案顺序匹配画面", isOn: $config.params.matchMaterialsToScript)
            MPTSelectRow(title: "视频转场模式",
                         options: MPTConst.transitionModes,
                         selection: $config.params.videoTransitionModeRaw)
            MPTSelectRow(title: "视频比例",
                         options: VideoAspect.allCases.map { ($0.rawValue, $0.rawValue) },
                         selection: $config.params.videoAspectRaw)
            MPTSelectRow(title: "单个片段最大时长（秒）",
                         options: [("3", "3"), ("5", "5"), ("10", "10")],
                         selection: $config.params.videoClipDurationRaw)
            MPTSelectRow(title: "同时生成视频数量",
                         options: [("1", "1"), ("2", "2"), ("3", "3")],
                         selection: $config.params.videoCountRaw)
            MPTSelectRow(title: "视频编码器",
                         options: [("default", "默认（推荐）"), ("libx264", "libx264")],
                         selection: $config.params.videoCodec)
        }
    }
}

struct AudioCard: View {
    @EnvironmentObject private var config: ConfigStore
    @State private var voices: [(String, String)] = [("zh-CN-XiaoxiaoNeural-Female", "zh-CN-Xiaoxiao-女性")]

    var body: some View {
        MPTCard(title: "音频设置") {
            MPTSegmentRow(title: "配音方式",
                          options: MPTConst.voiceModes,
                          selection: $config.params.voiceMode)
            MPTSelectRow(title: "配音服务",
                         options: MPTConst.voiceProviders,
                         selection: $config.params.voiceProvider)
            MPTSelectRow(title: "配音声音（与文案语言保持一致）",
                         options: voices,
                         selection: $config.params.voiceName)
            MPTSliderRow(title: "配音音量", range: 0...1, step: 0.05,
                         value: $config.params.voiceVolume,
                         valueText: "\(Int(config.params.voiceVolume * 100))%")
            MPTSliderRow(title: "配音语速", range: 0.5...2, step: 0.1,
                         value: $config.params.voiceRate,
                         valueText: String(format: "%.1f×", config.params.voiceRate))
            MPTAccentButton(title: "试听配音", icon: "music.note") {
                let t = config.params.videoScript.isEmpty
                    ? "你好，我是配音试听。文案生成后这里会朗读成片文案。"
                    : String(config.params.videoScript.prefix(60))
                MPTComposer.previewVoice(t, rate: Float(config.params.voiceRate))
            }
            MPTSelectRow(title: "背景音乐来源",
                         options: MPTConst.bgmTypes,
                         selection: $config.params.bgmType)
            MPTSliderRow(title: "背景音乐音量", range: 0...1, step: 0.05,
                         value: $config.params.bgmVolume,
                         valueText: "\(Int(config.params.bgmVolume * 100))%")
        }
        .task {
            let list = await VoiceService.shared.azureVoices()
            if list.count > 1 { voices = list }
        }
    }
}

struct SubtitleCard: View {
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        MPTCard(title: "字幕设置") {
            MPTCheckRow(title: "启用字幕", isOn: $config.params.subtitleEnabled)
            MPTSelectRow(title: "字幕字体",
                         options: MPTConst.fontNames.map { ($0, $0) },
                         selection: $config.params.fontName)
            MPTSelectRow(title: "字幕位置",
                         options: [("top", "顶部"), ("center", "居中"), ("bottom", "底部（推荐）"),
                                   ("two_thirds_bottom", "距底部 2/3"), ("custom", "自定义")],
                         selection: $config.params.subtitlePosition)
            MPTColorRow(title: "字幕颜色", hex: $config.params.textForeColor)
            MPTSliderRow(title: "字幕大小", range: 10...120, step: 1,
                         value: $config.params.fontSizeDouble,
                         valueText: String(Int(config.params.fontSize)))
            MPTColorRow(title: "描边颜色", hex: $config.params.strokeColor)
            MPTSliderRow(title: "描边粗细", range: 0...10, step: 0.5,
                         value: $config.params.strokeWidth,
                         valueText: String(format: "%.2f", config.params.strokeWidth))
            MPTCheckRow(title: "启用字幕背景", isOn: $config.params.subtitleBackgroundEnabled)
            MPTColorRow(title: "字幕背景颜色", hex: $config.params.subtitleBackgroundColor)
            MPTCheckRow(title: "启用圆角半透明字幕背景", isOn: $config.params.roundedSubtitleBackground)
            MPTAccentButton(title: "恢复默认字幕设置", icon: "arrow.clockwise") {
                config.resetSubtitle()
            }
        }
    }
}
