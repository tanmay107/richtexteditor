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
            makeItem(symbol: "bold", selector: #selector(boldTapped)),
            makeItem(symbol: "italic", selector: #selector(italicTapped)),
            makeItem(symbol: "underline", selector: #selector(underlineTapped)),
            flexible,

            makeItem(symbol: "list.bullet", selector: #selector(bulletTapped)),
            makeItem(symbol: "list.number", selector: #selector(numberTapped)),
            flexible,

            makeItem(symbol: "paintpalette", selector: #selector(colorTapped)),  // 🎨 color
            makeItem(symbol: "textformat", selector: #selector(fontTapped)),     // 🔤 font
            makeItem(symbol: "link", selector: #selector(linkTapped))            // 🔗 link
        ]
        setItems(items, animated: false)
        sizeToFit()               // gives intrinsic height'
        print("Toolbar items: \(items)")
    }

    private var flexible: UIBarButtonItem { .init(barButtonSystemItem: .flexibleSpace,
                                                   target: nil,
                                                   action: nil) }

    private func makeItem(symbol: String,
                          fallbackAsset: String? = nil,
                          selector: Selector) -> UIBarButtonItem {

        // 1️⃣ Try to load an SF Symbol (iOS 13+)
        let sfImage: UIImage? = {
            if #available(iOS 13, *) {
                return UIImage(systemName: symbol)
            }
            return nil
        }()

        // 2️⃣ If that failed (pre‑iOS13 **or** unknown symbol), use fallback asset if provided
        let img = sfImage ?? (fallbackAsset.flatMap { UIImage(named: $0) })

        // 3️⃣ If still nil, fall back to a 1‑character title so the button remains tappable
        if let img = img {
            return UIBarButtonItem(image: img,
                                   style: .plain,
                                   target: self,
                                   action: selector)
        } else {
            // Title will be first letter capitalized (“B”, “I”, etc.)
            return UIBarButtonItem(title: String(symbol.prefix(1)).uppercased(),
                                   style: .plain,
                                   target: self,
                                   action: selector)
        }
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
    
    @objc private func colorTapped() {
        guard let vc = editor?.findOwningViewController() else { return }

        // iOS 14+ → use native color picker
        if #available(iOS 14, *) {
            let picker = UIColorPickerViewController()
            picker.supportsAlpha = true                         // let users choose transparency
            picker.selectedColor = editor?.currentTextColor ?? .label
            picker.delegate = self                              // we’ll add conformance below
            vc.present(picker, animated: true)
            return
        }

        // iOS 13 → keep the small preset palette
        if #available(iOS 13, *) {
            presentPresetPalette(on: vc)
            return
        }

        // iOS 12 and below → very simple RGB sliders
        presentLegacyRGBSliders(on: vc)
    }


    @objc private func fontTapped() {
        guard let vc = editor?.findOwningViewController() else { return }

        let alert = UIAlertController(title: "Select Font", message: nil, preferredStyle: .actionSheet)
        let fonts = ["Helvetica", "Courier", "Georgia", "Avenir", "Chalkboard SE"]

        for name in fonts {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                self.editor?.applyFont(named: name)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(alert, animated: true)
    }

    @objc private func linkTapped() {
        guard let vc = editor?.findOwningViewController() else { return }

        let alert = UIAlertController(title: "Add Link", message: "Enter a URL", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "https://example.com" }

        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let urlString = alert.textFields?.first?.text,
               let url = URL(string: urlString) {
                self.editor?.applyLink(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Remove Link", style: .destructive) { _ in
            self.editor?.removeLink()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(alert, animated: true)
    }
    
    private func presentPresetPalette(on vc: UIViewController) {
        let alert = UIAlertController(title: "Text Color", message: nil, preferredStyle: .actionSheet)

        var colors: [(String, UIColor)] = [
            ("Red", .systemRed),
            ("Blue", .systemBlue),
            ("Green", .systemGreen),
            ("Orange", .systemOrange)
        ]

        // Add a safe default for "Black" or dynamic "Black/White"
        if #available(iOS 13, *) {
            colors.append(("Black/White", .label))  // dynamic color
        } else {
            colors.append(("Black", .black))        // fallback
        }

        colors.forEach { name, color in
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                self.editor?.applyTextColor(color)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(alert, animated: true)
    }

    private func presentLegacyRGBSliders(on vc: UIViewController) {
        let alert = UIAlertController(title: "Text Color (RGB 0‑255)", message: nil, preferredStyle: .alert)
        ["R", "G", "B"].forEach { placeholder in
            alert.addTextField {
                $0.placeholder = placeholder
                $0.keyboardType = .numberPad
            }
        }
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { _ in
            guard let rgb = alert.textFields?.compactMap { Int($0.text ?? "") }.prefix(3) else {
                return
            }
            guard rgb.count == 3 else { return }
            let color = UIColor(red: CGFloat(rgb[0])/255.0,
                                green: CGFloat(rgb[1])/255.0,
                                blue: CGFloat(rgb[2])/255.0,
                                alpha: 1)
            self.editor?.applyTextColor(color)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(alert, animated: true)
    }


}

extension UIView {
    func findOwningViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

@available(iOS 14, *)
extension RichTextEditorToolbar: UIColorPickerViewControllerDelegate {
    public func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        editor?.applyTextColor(viewController.selectedColor)
    }

    public func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        // Live preview while user drags the wheel (optional)
        editor?.applyTextColor(viewController.selectedColor)
    }
}


