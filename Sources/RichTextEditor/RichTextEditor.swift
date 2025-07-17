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
        textView.tintColor = .systemBlue
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
        let selectedRange = textView.selectedRange

        if selectedRange.length > 0 {
            // Apply to selected text
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            attributedText.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                if let currentFont = value as? UIFont {
                    var traits = currentFont.fontDescriptor.symbolicTraits

                    if traits.contains(trait) {
                        traits.remove(trait)
                    } else {
                        traits.insert(trait)
                    }

                    if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                        attributedText.addAttribute(.font, value: newFont, range: range)
                    }
                }
            }
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
        } else {
            // No selection — apply to typingAttributes
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
    
    public func getBodyOnlyHTML() -> String? {
        guard let fullHTML = getHTML() else { return nil }
        
        let pattern = "(?s)<html.*?>(.*?)</html>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: fullHTML, options: [], range: NSRange(location: 0, length: fullHTML.utf16.count)),
           let range = Range(match.range(at: 1), in: fullHTML) {
            
            let bodyOnlyHTML = String(fullHTML[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return "<html>\n\(bodyOnlyHTML)\n</html>"
        }
        
        return nil
    }
    
    public func getXHTML() -> String? {
        guard var html = getBodyOnlyHTML() else { return nil }

        let metaPattern = "<meta[^>]*>"
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: html.utf16.count)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
        }

        html = html.replacingOccurrences(of: "<br>", with: "<br />")
        html = html.replacingOccurrences(of: "<hr>", with: "<hr />")

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func getHTMLWithInlineCSSOnly() -> String? {
        guard var html = getXHTML() else { return nil }

        // 1️⃣ Remove <style> blocks from <head>
        let stylePattern = "<style[^>]*>.*?</style>"
        if let regex = try? NSRegularExpression(pattern: stylePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(location: 0, length: html.utf16.count)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
        }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func generateFullyInlineStyledHTML() -> String {
        let attributed = textView.attributedText ?? NSAttributedString(string: "")
        var htmlBody = ""

        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attributes, range, _ in
            let substring = attributed.attributedSubstring(from: range).string.replacingOccurrences(of: "\n", with: "<br />")

            guard !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            var tagOpen = "<span"
            var styleString = ""
            var content = substring

            if let font = attributes[.font] as? UIFont {
                styleString += "font-family: \(font.familyName); font-size: \(Int(font.pointSize))px;"
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    styleString += " font-weight: bold;"
                }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    styleString += " font-style: italic;"
                }
            }

            if let color = attributes[.foregroundColor] as? UIColor {
                styleString += " color: \(color.hexString);"
            }

            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
                if paragraph.alignment != .left {
                    styleString += " text-align: \(paragraph.alignment.cssString);"
                }
            }

            if let underline = attributes[.underlineStyle] as? Int, underline > 0 {
                styleString += " text-decoration: underline;"
            }

            if let link = attributes[.link] {
                let href = (link as? URL)?.absoluteString ?? (link as? String) ?? "#"
                tagOpen = "<a href=\"\(href)\""
            }

            let finalStyle = styleString.isEmpty ? "" : " style=\"\(styleString.trimmingCharacters(in: .whitespaces))\""
            htmlBody += "\(tagOpen)\(finalStyle)>\(content)</\(tagOpen.contains("a ") ? "a" : "span")>"
        }

        return "<html><body>\(htmlBody)</body></html>"
    }
    
    public func generateFullyInlineStyledHTMLWithLists() -> String {
        let attributed = textView.attributedText ?? NSAttributedString(string: "")
        let fullString = attributed.string as NSString
        var htmlBody = ""
        
        let paragraphRanges = getParagraphRanges(from: fullString)

        var currentListType: String? = nil
        var listItems: [String] = []

        for paraRange in paragraphRanges {
            let paragraphText = fullString.substring(with: paraRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if paragraphText.hasPrefix("• ") {
                if currentListType != "ul" {
                    htmlBody += closeList(currentListType, items: listItems)
                    currentListType = "ul"
                    listItems = []
                }
                listItems.append(buildListItem(from: attributed, range: paraRange, dropPrefix: 2))
            } else if let orderedNumber = getOrderedNumber(from: paragraphText) {
                if currentListType != "ol" {
                    htmlBody += closeList(currentListType, items: listItems)
                    currentListType = "ol"
                    listItems = []
                }
                let prefixLength = "\(orderedNumber). ".count
                listItems.append(buildListItem(from: attributed, range: paraRange, dropPrefix: prefixLength))
            } else {
                htmlBody += closeList(currentListType, items: listItems)
                currentListType = nil
                listItems = []
                htmlBody += buildStyledParagraph(from: attributed, range: paraRange)
            }
        }

        htmlBody += closeList(currentListType, items: listItems)

        return "<html><body>\(htmlBody)</body></html>"
    }



    
    public func convertCSSClassesToInlineStyles(html: String, styles: [String: String]) -> String {
        var result = html

        for (className, style) in styles {
            let escapedClassName = NSRegularExpression.escapedPattern(for: className)
            let pattern = "<(\\w+)([^>]*)class=\"\(escapedClassName)\"([^>]*)>"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let replacement = "<$1$2 style=\"\(style)\"$3>"
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: replacement)
            }
        }

        return result
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

public extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // Fallback for iOS 12 and below: no dynamic color support
        if #available(iOS 13.0, *) {
            let resolvedColor = self.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        } else {
            self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSTextAlignment {
    var cssString: String {
        switch self {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justify"
        case .natural: return "left" // fallback default
        @unknown default: return "left"
        }
    }
}

extension RichTextEditorView {
    private func getParagraphRanges(from nsString: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsString.length)

        while searchRange.length > 0 {
            let range = nsString.paragraphRange(for: NSRange(location: searchRange.location, length: 0))
            ranges.append(range)
            let newLocation = NSMaxRange(range)
            searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
        }
        return ranges
    }

    private func getOrderedNumber(from text: String) -> Int? {
        let regex = try! NSRegularExpression(pattern: #"^(\d+)\.\s"#)
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }
        return nil
    }

    private func closeList(_ type: String?, items: [String]) -> String {
        guard let type = type, !items.isEmpty else { return "" }
        return "<\(type)>\(items.joined())</\(type)>"
    }

    private func buildListItem(from attributed: NSAttributedString, range: NSRange, dropPrefix: Int) -> String {
        let contentRange = NSRange(location: range.location + dropPrefix, length: range.length - dropPrefix)
        let contentHTML = buildStyledSpan(from: attributed, range: contentRange)
        return "<li>\(contentHTML)</li>"
    }

    private func buildStyledParagraph(from attributed: NSAttributedString, range: NSRange) -> String {
        let contentHTML = buildStyledSpan(from: attributed, range: range)
        return "<p>\(contentHTML)</p>"
    }

    private func buildStyledSpan(from attributed: NSAttributedString, range: NSRange) -> String {
        var result = ""

        attributed.enumerateAttributes(in: range, options: []) { attributes, subRange, _ in
            let substring = attributed.attributedSubstring(from: subRange).string
                .replacingOccurrences(of: "\n", with: "<br />")

            guard !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            var styleString = ""

            if let font = attributes[.font] as? UIFont {
                styleString += "font-family: \(font.familyName); font-size: \(Int(font.pointSize))px;"
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    styleString += " font-weight: bold;"
                }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    styleString += " font-style: italic;"
                }
            }

            if let color = attributes[.foregroundColor] as? UIColor {
                styleString += " color: \(color.hexString);"
            }

            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
                if paragraph.alignment != .left {
                    styleString += " text-align: \(paragraph.alignment.cssString);"
                }
            }

            if let underline = attributes[.underlineStyle] as? Int, underline > 0 {
                styleString += " text-decoration: underline;"
            }

            if let link = attributes[.link] {
                let href = (link as? URL)?.absoluteString ?? (link as? String) ?? "#"
                result += "<a href=\"\(href)\" style=\"\(styleString)\">\(substring)</a>"
            } else {
                result += "<span style=\"\(styleString)\">\(substring)</span>"
            }
        }

        return result
    }

}
