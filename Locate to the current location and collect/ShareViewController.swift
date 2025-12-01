//
//  ShareViewController.swift
//  Locate to the current location and collect
//
//  Created by id77 on 2025/12/1.
//

import UIKit
import UniformTypeIdentifiers
import os.log

class ShareViewController: UIViewController {
    private let log = OSLog(subsystem: "live.cclerc.geranium", category: "ShareExtension")

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad called", log: log, type: .info)
        view.backgroundColor = .clear
        handleShare()
    }

    private func handleShare() {
        os_log("[ShareExtension] handleShare started", log: log, type: .info)

        guard let extensionContext = extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem],
              let firstItem = items.first,
              let attachments = firstItem.attachments else {
            os_log("[ShareExtension] No items found, closing", log: log, type: .error)
            closeExtension()
            return
        }

        os_log("[ShareExtension] Found %d attachments", log: log, type: .info, attachments.count)

        // 查找URL
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                os_log("[ShareExtension] Found URL provider", log: log, type: .info)
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        os_log("[ShareExtension] Error loading URL: %@", log: self.log, type: .error, error.localizedDescription)
                    }

                    guard let mapURL = url as? URL else {
                        os_log("[ShareExtension] Invalid URL, closing", log: self.log, type: .error)
                        self.closeExtension()
                        return
                    }

                    os_log("[ShareExtension] Got URL: %@", log: self.log, type: .info, mapURL.absoluteString)
                    // 传递给主app处理
                    self.sendToMainApp(mapURL: mapURL)
                }
                return
            }
        }

        os_log("[ShareExtension] No URL found in attachments", log: log, type: .error)
        closeExtension()
    }

    private func sendToMainApp(mapURL: URL) {
        os_log("[ShareExtension] sendToMainApp called with: %@", log: log, type: .info, mapURL.absoluteString)

        // 保存到 App Group
        if let sharedDefaults = UserDefaults(suiteName: "group.live.cclerc.geraniumBookmarks") {
            sharedDefaults.set(mapURL.absoluteString, forKey: "SharedMapURL")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "SharedMapURLTimestamp")
            let saveSuccess = sharedDefaults.synchronize()
            os_log("[ShareExtension] 保存URL到App Group: %@", log: log, type: .info, saveSuccess ? "成功" : "失败")
        }

        // 发送 Darwin 通知，让主 App 在后台处理
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.geranium.mapURLShared" as CFString),
            nil,
            nil,
            true
        )
        os_log("[ShareExtension] Darwin通知已发送", log: log, type: .info)

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
                    // 关闭扩展前打开主 App
                    let encodedMapURL = mapURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let geraniumURLString = "geranium://process-map-url?url=\(encodedMapURL)"
                    
                    if let geraniumURL = URL(string: geraniumURLString) {
                        var responder: UIResponder? = self as UIResponder
                        let selector = #selector(self.openURL(_:))
                        
                        while responder != nil {
                            if responder!.responds(to: selector) && responder != self {
                                responder!.perform(selector, with: geraniumURL)
                                os_log("[ShareExtension] 打开主App", log: self.log, type: .info)
                                break
                            }
                            responder = responder?.next
                        }
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
