// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

public class RichTextEditorView: UIView {

    public let textView = UITextView()
    public var currentTextColor: UIColor {
        // 1. If the user has already set a typing color, return it.
        if let color = textView.typingAttributes[.foregroundColor] as? UIColor {
            return color
        }

        // 2. Otherwise, fall back to a sensible default that exists on every OS.
        if #available(iOS 13, *) {
            return .label        // dynamic black/white on iOS 13+
        } else {
            return .black        // static black on iOS 12 or earlier
        }
    }


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
        textView.delegate = self
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
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
    
    public func getFormattedString() -> String {
        guard let attributed = textView.attributedText else {
            return ""
        }
        var result = ""
        var listIndex = 1

        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, range, _ in
            var line = attributed.attributedSubstring(from: range).string

            if let para = attrs[.paragraphStyle] as? NSParagraphStyle,
               let textList = para.textLists.first {
                
                // Generate the bullet or number prefix
                let marker = textList.marker(forItemNumber: listIndex)
                line = "\(marker) \(line)"
                listIndex += 1
            } else {
                listIndex = 1  // reset when not in a list
            }

            result += line
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    
    // 1️⃣ A small list‑style enum
    public enum ListStyle { case unordered, ordered }

    // 2️⃣ The list formatter
    public func applyListStyle(_ style: ListStyle) {

        // 1⃣ Grab the range that should be affected — full paragraphs of the selection
        let fullText     = textView.textStorage            // NSAttributedString
        let selectedNS   = textView.selectedRange          // NSRange
        let paraRange    = (fullText.string as NSString)
                            .paragraphRange(for: selectedNS)

        // 2⃣ Split the affected substring into individual lines
        let original     = (fullText.string as NSString)
                            .substring(with: paraRange)
        var lines        = original.components(separatedBy: "\n")

        // 3⃣ Build the new lines
        var newLines: [String] = []
        var number = 1
        for line in lines {

            // Trim leading spaces so we can reliably detect existing bullets
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            switch style {

            case .unordered:
                if trimmed.hasPrefix("• ") {
                    newLines.append(line)                // already bulleted
                } else {
                    newLines.append("• " + line)
                }

            case .ordered:
                let regex  = try! NSRegularExpression(pattern: #"^\d+\.\s"#)
                if regex.firstMatch(in: trimmed,
                                    range: NSRange(location: 0,
                                                   length: trimmed.utf16.count)) != nil {
                    newLines.append(line)                // already numbered
                } else {
                    newLines.append("\(number). " + line)
                }
                number += 1
            }
        }

        let replacement = newLines.joined(separator: "\n")

        // 4⃣ Apply replacement—preserve attributes by going through textStorage
        textView.textStorage.beginEditing()
        let attrReplacement = NSMutableAttributedString(string: replacement)

        // Copy base typing attributes into the replacement so new text blends in
        attrReplacement.addAttributes(textView.typingAttributes,
                                      range: NSRange(location: 0,
                                                     length: attrReplacement.length))

        textView.textStorage.replaceCharacters(in: paraRange, with: attrReplacement)
        textView.textStorage.endEditing()

        // 5⃣ Restore selection relative to new text
        let newSelectedLocation = paraRange.location
        let newSelectedLength   = attrReplacement.length
        textView.selectedRange  = NSRange(location: newSelectedLocation,
                                          length: newSelectedLength)
    }
    
    public func applyTextColor(_ color: UIColor) {
        guard let range = textView.selectedTextRange else { return }
        let nsRange = textView.selectedRange

        textView.textStorage.addAttribute(.foregroundColor, value: color, range: nsRange)
        textView.typingAttributes[.foregroundColor] = color
    }

    public func applyFont(named name: String) {
        guard let range = textView.selectedTextRange else { return }
        guard let font = UIFont(name: name, size: textView.font?.pointSize ?? 16) else { return }

        let nsRange = textView.selectedRange
        textView.textStorage.addAttribute(.font, value: font, range: nsRange)
        textView.typingAttributes[.font] = font
    }

    public func applyLink(_ url: URL) {
        let nsRange = textView.selectedRange
        textView.textStorage.addAttribute(.link, value: url, range: nsRange)
        textView.typingAttributes[.link] = url
    }

    public func removeLink() {
        let nsRange = textView.selectedRange
        textView.textStorage.removeAttribute(.link, range: nsRange)
        textView.typingAttributes.removeValue(forKey: .link)
    }
    
    public func applyTextAlignment(_ alignment: NSTextAlignment) {
        let selectedRange = textView.selectedRange

        // Apply alignment to entire paragraph range
        let fullText = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (fullText.string as NSString).paragraphRange(for: selectedRange)

        fullText.enumerateAttribute(.paragraphStyle, in: paragraphRange, options: []) { value, range, _ in
            let mutableStyle = (value as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            mutableStyle.alignment = alignment
            fullText.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
        }

        textView.attributedText = fullText
        textView.selectedRange = selectedRange  // Preserve cursor position

        // Also update typingAttributes so new text stays aligned
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        textView.typingAttributes[.paragraphStyle] = style
    }
}

extension RichTextEditorView: UITextViewDelegate {
    // MARK: - UITextViewDelegate
    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {

        // We only care about Return presses
        guard text == "\n" else { return true }

        // 1️⃣ Identify the current paragraph
        let nsString    = textView.text as NSString
        let paraRange   = nsString.paragraphRange(for: range)
        let line        = nsString.substring(with: paraRange)

        // 2️⃣ Detect prefix
        let bulletPref  = "• "
        let orderedRE   = try! NSRegularExpression(pattern: #"^(\d+)\.\s"#)
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the line has no content besides its prefix → exit list
        let isLineEmpty = { (prefix: String) -> Bool in
            trimmedLine == prefix.trimmingCharacters(in: .whitespaces)
        }

        // 3️⃣ Unordered bullet
        if trimmedLine.hasPrefix(bulletPref) {

            if isLineEmpty(bulletPref) {
                // Remove the bullet and just insert a newline
                textView.replace(textView.range(from: paraRange)!, withText: "\n")
                return false
            }

            // Insert newline + bullet
            let insert = "\n" + bulletPref
            textView.replace(textView.range(from: range)!, withText: insert)
            return false
        }

        // 4️⃣ Ordered list
        if let match = orderedRE.firstMatch(in: trimmedLine,
                                            range: NSRange(location: 0,
                                                           length: trimmedLine.utf16.count)),
           let numberRange = Range(match.range(at: 1), in: trimmedLine),
           let currentNum  = Int(trimmedLine[numberRange]) {

            let prefix = "\(currentNum + 1). "

            if isLineEmpty("\(currentNum). ") {
                // Exit list
                textView.replace(textView.range(from: paraRange)!, withText: "\n")
                return false
            }

            // Insert newline + next number
            let insert = "\n" + prefix
            textView.replace(textView.range(from: range)!, withText: insert)
            return false
        }

        // 5️⃣ Not a list line → default behavior
        return true
    }

}

private extension UITextView {
    func range(from nsRange: NSRange) -> UITextRange? {
        guard
            let start = position(from: beginningOfDocument, offset: nsRange.location),
            let end   = position(from: start, offset: nsRange.length)
        else { return nil }
        return textRange(from: start, to: end)
    }
}

