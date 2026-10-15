import UserNotifications

/// Attaches the article thumbnail to incoming pushes. FCM delivers the image
/// URL at userInfo["fcm_options"]["image"]; APNs invokes this extension
/// because the payload carries mutable-content: 1. Pure URLSession — no
/// Firebase dependency needed in the extension target.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttempt = request.content.mutableCopy() as? UNMutableNotificationContent
    guard let content = bestAttempt else {
      contentHandler(request.content)
      return
    }
    let fcmOptions = request.content.userInfo["fcm_options"] as? [String: Any]
    guard let urlString = fcmOptions?["image"] as? String,
          let url = URL(string: urlString) else {
      contentHandler(content)
      return
    }
    URLSession.shared.downloadTask(with: url) { tmp, _, _ in
      defer { contentHandler(content) }
      guard let tmp = tmp else { return }
      let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
      let dest = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
      do {
        try FileManager.default.moveItem(at: tmp, to: dest)
        let attachment = try UNNotificationAttachment(identifier: "image", url: dest)
        content.attachments = [attachment]
      } catch {}
    }.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler, let content = bestAttempt {
      contentHandler(content)
    }
  }
}
