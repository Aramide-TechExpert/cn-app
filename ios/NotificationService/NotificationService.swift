import UserNotifications
import Intents

/// Enriches incoming pushes:
///  1. Attaches the article thumbnail (userInfo["fcm_options"]["image"]).
///  2. When the payload carries a publisher logo (data key "logo"), promotes
///     the push to a COMMUNICATION notification so the logo renders as the
///     big left avatar and the Cluster News app icon becomes the tiny corner
///     badge — the SmartNews/Flipboard look (owner request 2026-10-17; the
///     text-subtitle attribution was rejected as too loud).
/// Pure URLSession — no Firebase dependency in the extension target.
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

    let userInfo = request.content.userInfo
    let fcmOptions = userInfo["fcm_options"] as? [String: Any]
    let imageUrl = (fcmOptions?["image"] as? String).flatMap(URL.init(string:))
    let logoUrl = (userInfo["logo"] as? String).flatMap(URL.init(string:))

    let group = DispatchGroup()
    var logoData: Data?

    if let url = imageUrl {
      group.enter()
      URLSession.shared.downloadTask(with: url) { tmp, _, _ in
        defer { group.leave() }
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

    if let url = logoUrl {
      group.enter()
      URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { group.leave() }
        if let data = data, !data.isEmpty { logoData = data }
      }.resume()
    }

    group.notify(queue: .main) { [weak self] in
      guard let self = self else { return }
      if #available(iOS 15.0, *), let data = logoData {
        self.deliverAsCommunication(content: content, logo: data, handler: contentHandler)
      } else {
        contentHandler(content)
      }
    }
  }

  /// Wrap the push in an INSendMessageIntent so iOS shows the publisher
  /// avatar. The sender display name mirrors the push title, so the visible
  /// text is unchanged — only the icon treatment differs. Falls back to the
  /// plain content on any failure.
  @available(iOS 15.0, *)
  private func deliverAsCommunication(
    content: UNMutableNotificationContent,
    logo: Data,
    handler: @escaping (UNNotificationContent) -> Void
  ) {
    let tag = (content.userInfo["gcm.notification.tag"] as? String) ?? "cluster-news"
    let sender = INPerson(
      personHandle: INPersonHandle(value: tag, type: .unknown),
      nameComponents: nil,
      displayName: content.title,
      image: INImage(imageData: logo),
      contactIdentifier: nil,
      customIdentifier: nil
    )
    let intent = INSendMessageIntent(
      recipients: nil,
      outgoingMessageType: .outgoingMessageText,
      content: content.body,
      speakableGroupName: nil,
      conversationIdentifier: tag,
      serviceName: nil,
      sender: sender,
      attachments: nil
    )
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .incoming
    interaction.donate { _ in }
    do {
      let updated = try content.updating(from: intent)
      handler(updated)
    } catch {
      handler(content)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler, let content = bestAttempt {
      contentHandler(content)
    }
  }
}
