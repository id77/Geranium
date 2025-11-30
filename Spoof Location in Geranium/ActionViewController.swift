import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class SpoofActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 立即处理分享的位置
        processSpoofingRequest()
    }

    private func processSpoofingRequest() {
        if let sharedItems = extensionContext?.inputItems as? [NSExtensionItem],
           let firstItem = sharedItems.first,
           let attachments = firstItem.attachments {

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier as String) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier as String, options: nil) { (url, error) in
                        if let url = url as? URL {
                            self.extractCoordinatesAndSpoof(from: url)
                        } else {
                            DispatchQueue.main.async {
                                self.done()
                            }
                        }
                    }
                    return
                }
            }
        }

        // 如果没有找到有效的URL，直接关闭
        done()
    }

    private func extractCoordinatesAndSpoof(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let llParam = queryItems.first(where: { $0.name == "ll" })?.value else {
            DispatchQueue.main.async {
                self.done()
            }
            return
        }

        let coords = llParam.components(separatedBy: ",")
        guard coords.count == 2,
              let latitude = Double(coords[0]),
              let longitude = Double(coords[1]) else {
            DispatchQueue.main.async {
                self.done()
            }
            return
        }

        // 构建打开主应用并开始模拟定位的 URL
        let spoofURLString = "geranium://spoof?lat=\(latitude)&lon=\(longitude)"

        DispatchQueue.main.async {
            self.openMainApp(with: spoofURLString)

            // 稍微延迟一下再关闭，确保URL能被处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.done()
            }
        }
    }

    private func openMainApp(with urlString: String) {
        guard let url = URL(string: urlString) else { return }

        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))

        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
    }

    @objc private func openURL(_ url: URL) {
        // 此方法由系统调用
    }

    private func done() {
        self.extensionContext?.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }
}
