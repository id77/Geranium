//
//  ShareViewController.swift
//  Locate to the current location and collect
//
//  Created by id77 on 2025/12/1.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("### [ShareExtension] viewDidLoad called")
        view.backgroundColor = .clear
        handleShare()
    }

    private func handleShare() {
        NSLog("### [ShareExtension] handleShare started")

        guard let extensionContext = extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem],
              let firstItem = items.first,
              let attachments = firstItem.attachments else {
            NSLog("### [ShareExtension] No items found, closing")
            closeExtension()
            return
        }

        NSLog("### [ShareExtension] Found %d attachments", attachments.count)

        // 查找URL
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                NSLog("### [ShareExtension] Found URL provider")
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        NSLog("### [ShareExtension] Error loading URL: %@", error.localizedDescription)
                    }

                    guard let mapURL = url as? URL else {
                        NSLog("### [ShareExtension] Invalid URL, closing")
                        self.closeExtension()
                        return
                    }

                    NSLog("### [ShareExtension] Got URL: %@", mapURL.absoluteString)
                    // 传递给主app处理
                    self.sendToMainApp(mapURL: mapURL)
                }
                return
            }
        }

        NSLog("### [ShareExtension] No URL found in attachments")
        closeExtension()
    }

    private func sendToMainApp(mapURL: URL) {
        NSLog("### [ShareExtension] sendToMainApp called with: %@", mapURL.absoluteString)

        // ...existing code...

        // 显示提示并完成
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "已添加到收藏",
                message: "位置已保存并开始模拟定位",
                preferredStyle: .alert
            )

            self.present(alert, animated: true)

            // 延迟后关闭扩展并打开主 App
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                alert.dismiss(animated: true) {
                    // 关闭扩展前打开主 App，使用 URLComponents 构造参数，避免编码问题
                    var components = URLComponents()
                    components.scheme = "geranium"
                    components.host = "process-map-url"
                    components.queryItems = [
                        URLQueryItem(name: "url", value: mapURL.absoluteString)
                    ]
                    guard let geraniumURL = components.url else {
                        NSLog("### [ShareExtension] 构造 geraniumURL 失败")
                        self.closeExtension()
                        return
                    }

                    var responder: UIResponder? = self as UIResponder
                    let selector = #selector(self.openURL(_:))
                    while responder != nil {
                        if responder!.responds(to: selector) && responder != self {
                            responder!.perform(selector, with: geraniumURL)
                            NSLog("### [ShareExtension] 打开主App")
                            break
                        }
                        responder = responder?.next
                    }

                    // 稍微延迟后关闭扩展
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.closeExtension()
                    }
                }
            }
        }
    }

    @objc private func openURL(_ url: URL) {
        // 这个方法会被 UIApplication 响应链处理
    }

    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
