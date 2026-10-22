import SwiftUI

/// 卡片容器（对应原版 st.container(border=True)）
struct MPTCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s3) {
            Text(title)
                .font(MPTStyle.title(15))
                .foregroundColor(MPTStyle.textPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MPTStyle.s4)
        .background(MPTStyle.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: MPTStyle.radiusLarge)
            .stroke(MPTStyle.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusLarge))
    }
}

/// 行标签
struct MPTRowLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(MPTStyle.body())
            .foregroundColor(MPTStyle.textPrimary)
    }
}

/// 文本输入（单行）
struct MPTTextField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            MPTRowLabel(text: title)
            TextField(placeholder, text: $text)
                .font(MPTStyle.body())
                .padding(.horizontal, MPTStyle.s3)
                .padding(.vertical, MPTStyle.s2)
                .background(MPTStyle.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall))
        }
    }
}

/// 多行文本
struct MPTMultilineField: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            MPTRowLabel(text: title)
            TextEditor(text: $text)
                .font(MPTStyle.body())
                .frame(minHeight: minHeight)
                .padding(MPTStyle.s2)
                .scrollContentBackground(.hidden)
                .background(MPTStyle.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall))
        }
    }
}

/// 下拉选择（原版 selectbox）
struct MPTSelectRow: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            MPTRowLabel(text: title)
            Picker(title, selection: $selection) {
                ForEach(options.indices, id: \.self) { i in
                    Text(options[i].1).tag(options[i].0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(MPTStyle.brand)
            .font(MPTStyle.body())
        }
    }
}

/// 分段单选（原版 radio buttons，选中态粉色）
struct MPTSegmentRow: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            MPTRowLabel(text: title)
            HStack(spacing: MPTStyle.s2) {
                ForEach(options.indices, id: \.self) { i in
                    let opt = options[i]
                    Button {
                        selection = opt.0
                    } label: {
                        Text(opt.1)
                            .font(MPTStyle.body())
                            .foregroundColor(selection == opt.0 ? MPTStyle.primary : MPTStyle.textSecondary)
                            .padding(.horizontal, MPTStyle.s3)
                            .padding(.vertical, MPTStyle.s2)
                            .background(selection == opt.0 ? MPTStyle.selectedBackground : MPTStyle.controlBackground)
                            .overlay(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall)
                                .stroke(selection == opt.0 ? MPTStyle.primary : Color.clear, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// 滑块
struct MPTSliderRow: View {
    let title: String
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    @Binding var value: Double
    var valueText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            HStack {
                MPTRowLabel(text: title)
                Spacer()
                Text(valueText ?? String(format: "%g", value))
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(MPTStyle.brand)
        }
    }
}

/// 颜色选择（色块 + 原版 hex 值）
struct MPTColorRow: View {
    let title: String
    @Binding var hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            MPTRowLabel(text: title)
            HStack(spacing: MPTStyle.s2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: hex))
                    .frame(width: 26, height: 26)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(MPTStyle.border, lineWidth: 1))
                Text(hex.uppercased())
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
                Spacer()
            }
        }
    }
}

/// 勾选
struct MPTCheckRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: MPTStyle.s2) {
            Button { isOn.toggle() } label: {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? MPTStyle.primary : MPTStyle.textTertiary)
            }
            .buttonStyle(.plain)
            MPTRowLabel(text: title)
            Spacer(minLength: 0)
        }
    }
}

/// 强调按钮（原版 st.button）
struct MPTAccentButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MPTStyle.s2) {
                if let icon { Image(systemName: icon) }
                Text(title).font(MPTStyle.body())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MPTStyle.s2)
            .foregroundColor(.white)
            .background(MPTStyle.brand)
            .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall))
        }
        .buttonStyle(.plain)
    }
}
