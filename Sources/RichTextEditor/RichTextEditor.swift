// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

public class RichTextEditorView: UIView {

    public let textView = UITextView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.font = UIFont.systemFont(ofSize: 16)
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Text Formatting API

    public func toggleBold() {
        toggleTrait(.traitBold)
    }

    public func toggleItalic() {
        toggleTrait(.traitItalic)
    }

    public func toggleUnderline() {
        applyAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let currentFont = textView.typingAttributes[.font] as? UIFont else { return }
        var traits = currentFont.fontDescriptor.symbolicTraits

        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }

        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
            textView.typingAttributes[.font] = newFont
        }
    }

    private func applyAttribute(_ attribute: NSAttributedString.Key, value: Any) {
        let selectedRange = textView.selectedRange
        if selectedRange.length > 0 {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            attributedText.addAttribute(attribute, value: value, range: selectedRange)
            textView.attributedText = attributedText
        } else {
            textView.typingAttributes[attribute] = value
        }
    }

    public func setHTML(_ html: String) {
        if let data = html.data(using: .utf8),
           let attributedString = try? NSAttributedString(data: data,
                                                          options: [.documentType: NSAttributedString.DocumentType.html],
                                                          documentAttributes: nil) {
            textView.attributedText = attributedString
        }
    }

    public func getHTML() -> String? {
        let range = NSRange(location: 0, length: textView.attributedText.length)
        if let data = try? textView.attributedText.data(from: range,
                                                        documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // 1️⃣ A small list‑style enum
    public enum ListStyle { case unordered, ordered }

    // 2️⃣ The list formatter
    public func applyListStyle(_ style: ListStyle) {
        guard let selectedRange = textView.selectedTextRange else { return }
        // For demo purposes we’ll prepend • or 1. – production code would
        // iterate line‑by‑line and preserve numbering.
        let prefix = (style == .unordered) ? "• " : "1. "
        textView.replace(selectedRange, withText: prefix + textView.text(in: selectedRange)!)
    }

}
