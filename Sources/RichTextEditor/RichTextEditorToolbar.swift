//
//  File.swift
//  RichTextEditor
//
//  Created by Tanmay Tripathi on 30/06/25.
//

import Foundation
import UIKit

/// Simple input‑accessory / standalone toolbar that wires buttons to a `RichTextEditorView`.
public final class RichTextEditorToolbar: UIToolbar {

    // MARK: Init

    /// Designated initializer
    /// - Parameters:
    ///   - editor: The editor instance whose formatting methods you want to trigger.
    ///   - showsTextLabels: Optional text below SF‑Symbol icons (default = false).
    public init(attachedTo editor: RichTextEditorView,
                showsTextLabels: Bool = false) {
        self.editor = editor
        self.showsTextLabels = showsTextLabels
        super.init(frame: .zero)
        configureItems()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Private

    private weak var editor: RichTextEditorView?
    private let showsTextLabels: Bool

    private func configureItems() {
        // You can swap SF Symbols or use custom images here
        let items: [UIBarButtonItem] = [
            makeItem(symbol: "bold",       selector: #selector(boldTapped)),
            makeItem(symbol: "italic",     selector: #selector(italicTapped)),
            makeItem(symbol: "underline",  selector: #selector(underlineTapped)),
            flexible,
            makeItem(symbol: "list.bullet", selector: #selector(bulletTapped)),
            makeItem(symbol: "list.number", selector: #selector(numberTapped))
        ]
        setItems(items, animated: false)
        sizeToFit()               // gives intrinsic height'
        print("Toolbar items: \(items)")
    }

    private var flexible: UIBarButtonItem { .init(barButtonSystemItem: .flexibleSpace,
                                                   target: nil,
                                                   action: nil) }

    private func makeItem(symbol: String, selector: Selector) -> UIBarButtonItem {
        let image = UIImage(named: symbol)
        let item  = UIBarButtonItem(image: image,
                                    style: .plain,
                                    target: self,
                                    action: selector)
        if showsTextLabels {
            item.title = symbol.capitalized
        }
        return item
    }

    // MARK: Actions

    @objc private func boldTapped()      { editor?.toggleBold() }
    @objc private func italicTapped()    { editor?.toggleItalic() }
    @objc private func underlineTapped() { editor?.toggleUnderline() }

    @objc private func bulletTapped() {
        editor?.applyListStyle(.unordered)
    }

    @objc private func numberTapped() {
        editor?.applyListStyle(.ordered)
    }
}
