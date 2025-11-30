import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers
import CoreLocation

class ActionViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textField: UITextField!
    var latitudeDouble: Double = 0.0
    var longitudeDouble: Double = 0.0
    let geocoder = CLGeocoder()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // Helper method to extract query parameters from URL
    private func getParameter(from url: URL, key: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first { $0.name == key }?.value
    }

    @IBAction func saveButtonPressed(_ sender: UIButton) {
        if let sharedItems = extensionContext?.inputItems as? [NSExtensionItem],
           let firstItem = sharedItems.first,
           let attachments = firstItem.attachments {

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier as String) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier as String, options: nil, completionHandler: { (url, error) in
                        if let url = url as? URL {
                            if let latitude = self.getParameter(from: url, key: "ll")?.components(separatedBy: ",").first,
                               let longitude = self.getParameter(from: url, key: "ll")?.components(separatedBy: ",").last,
                               let latitudeDouble = Double(latitude),
                               let longitudeDouble = Double(longitude) {

                                // 获取地点名称（如果URL中包含）
                                let urlPlaceName = self.getParameter(from: url, key: "q")

                                // 进行反向地理编码以获取详细地址
                                let location = CLLocation(latitude: latitudeDouble, longitude: longitudeDouble)
                                self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                    DispatchQueue.main.async {
                                        var placeName = urlPlaceName

                                        // 如果URL中没有地点名称，尝试从地理编码结果获取
                                        if placeName == nil || placeName?.isEmpty == true {
                                            if let placemark = placemarks?.first {
                                                // 优先使用 name，其次是 thoroughfare（街道）
                                                placeName = placemark.name ?? placemark.thoroughfare
                                            }
                                        }

                                        // 如果有地点名称且输入框为空，则自动填充
                                        if let name = placeName, !name.isEmpty,
                                           self.textField.text?.isEmpty ?? true {
                                            self.textField.text = name
                                        }

                                        // 保存书签
                                        let bookmarkName = self.textField.text
                                        print(self.BookMarkSave(lat: latitudeDouble, long: longitudeDouble, name: bookmarkName ?? ""))

                                        // 打开主应用的收藏界面
                                        self.openMainApp()

                                        self.done()
                                    }
                                }
                            }
                        }
                    })
                }
            }
        }
        dismiss(animated: true) {
        }
    }

    @IBAction func done() {
        self.extensionContext?.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }

    private func openMainApp() {
        // 使用 URL Scheme 打开主应用的收藏界面
        if let url = URL(string: "geranium://bookmarks") {
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
    }

    @objc private func openURL(_ url: URL) {
        // 此方法由系统调用
    }
    
    let sharedUserDefaultsSuiteName = "group.live.cclerc.geraniumBookmarks"

    func BookMarkSave(lat: Double, long: Double, name: String) -> Bool {
        let bookmark: [String: Any] = ["name": name, "lat": lat, "long": long]
        var bookmarks = BookMarkRetrieve()
        bookmarks.append(bookmark)
        let sharedUserDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)
        sharedUserDefaults?.set(bookmarks, forKey: "bookmarks")
        successVibrate()
        return true
    }

    func BookMarkRetrieve() -> [[String: Any]] {
        let sharedUserDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)
        if let bookmarks = sharedUserDefaults?.array(forKey: "bookmarks") as? [[String: Any]] {
            return bookmarks
        } else {
            return []
        }
    }
}

// shortened vibrate object
func successVibrate() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}
