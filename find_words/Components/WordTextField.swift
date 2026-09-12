//
//  WordTextField.swift
//  find_words
//
//  首页「输入一个词就开始」的那个框，用真正的 UITextField 实现（UIViewRepresentable 包装）。
//
//  为什么不是 SwiftUI 的 TextField（见 ad_layout skill 8.1）：
//    · 隐藏广告面板的口令判定要挂在真实控件的 EditingChanged 上逐字比较，UITextField 的
//      target/action 是最直接的接入点；
//    · 程序化赋值（外部插件写入文本）不会触发 EditingChanged，因此不会即时命中口令，
//      只能被 5-10 秒后的延时检查捞出 —— 这两条路径必须能区分，UITextField 天然满足。
//
//  视觉与手感与产品原有输入框保持一致：白色圆角卡片、居中、黑色圆体大字、不使用自动大写 /
//  自动更正 / 拼写检查，Return 键 = 开始计时，键盘上方保留「Start Timer」工具条
//  （页面下方的按钮在软键盘弹出时可能点不到，键盘层这一份是兜底）。
//

import SwiftUI
import UIKit

/// 直接持有 UITextField 的句柄：口令命中时需要「先收键盘」，而 SwiftUI 拿不到 UIKit 实例。
final class WordFieldHandle {
    weak var field: UITextField?

    /// 收起系统键盘。
    func resignFirstResponder() {
        field?.resignFirstResponder()
    }

    /// 让输入框重新获得焦点（当前产品流程不在出现时自动聚焦，保留给以后使用）。
    func becomeFirstResponder() {
        field?.becomeFirstResponder()
    }
}

struct WordTextField: UIViewRepresentable {

    @Binding var text: String

    /// 由调用方持有，用于在口令命中时收起键盘。
    var handle: WordFieldHandle?

    /// 每次 EditingChanged（手动逐字输入）后回调。
    var onEditingChanged: (String) -> Void = { _ in }

    /// Return 键。
    var onSubmit: () -> Void = {}

    /// 键盘上方工具条的标题与动作。
    var accessoryTitle: String = "Start Timer"
    var onAccessoryTap: (() -> Void)?

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )

        field.text = text
        field.textAlignment = .center
        field.font = Self.wordFont(size: 34)
        field.textColor = UIColor(PartyTheme.ink)
        field.tintColor = UIColor(PartyTheme.grape)
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.returnKeyType = .go
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 18
        field.accessibilityLabel = "Your word"
        field.attributedPlaceholder = NSAttributedString(
            string: "Your word",
            attributes: [
                .foregroundColor: UIColor(PartyTheme.ink).withAlphaComponent(0.32),
                .font: Self.wordFont(size: 34),
            ]
        )
        field.inputAccessoryView = context.coordinator.makeAccessoryView()

        handle?.field = field
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // 闭包会随 SwiftUI 重建更新，必须回写，否则坐标里的旧闭包会继续被调用。
        context.coordinator.parent = self

        // 程序化赋值（Surprise me 换词 / 口令命中后清空）：直接改 text，不触发 EditingChanged。
        if uiView.text != text {
            uiView.text = text
        }
    }

    // MARK: - 字体（对齐 PartyTheme.display：系统黑体 + rounded 设计）

    static func wordFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: rounded, size: size)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate {

        var parent: WordTextField

        init(_ parent: WordTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            let value = field.text ?? ""
            parent.text = value
            parent.onEditingChanged(value)
        }

        @objc func accessoryTapped() {
            parent.onAccessoryTap?()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }

        func makeAccessoryView() -> UIToolbar {
            let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
            bar.sizeToFit()

            let title = parent.accessoryTitle
            let item = UIBarButtonItem(title: title, style: .done, target: self, action: #selector(accessoryTapped))
            item.tintColor = UIColor(PartyTheme.grape)

            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            bar.items = [spacer, item]
            return bar
        }
    }
}
