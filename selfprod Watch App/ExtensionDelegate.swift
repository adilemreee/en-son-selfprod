import WatchKit
import UserNotifications
import CloudKit
import ClockKit
import CoreLocation

class ExtensionDelegate: NSObject, WKExtensionDelegate, UNUserNotificationCenterDelegate {
    
    func applicationDidFinishLaunching() {
        print("App Launched")
        registerForPushNotifications()
        setupEncounterObserver()
    }
    
    // MARK: - Encounter Observer
    private func setupEncounterObserver() {
        NotificationCenter.default.addObserver(
            forName: .encounterDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleEncounterDetected()
        }
    }
    
    private func handleEncounterDetected() {
        // Play haptic
        WKInterfaceDevice.current().play(.notification)
        
        // Show local notification
        let content = UNMutableNotificationContent()
        content.title = "Aşkımla buluştukkk 💕"
        content.body = "Partneriniz yakınınızda!"
        content.sound = .default
        content.categoryIdentifier = "Encounter"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func applicationDidBecomeActive() {
        CloudKitManager.shared.checkAccountStatus()
        
        // Auto-activate location tracking when app opens
        PresenceManager.shared.activateOnAppLaunch()
    }
    
    func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        setupNotificationCategories(center: center)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Permission granted")
                DispatchQueue.main.async {
                    WKExtension.shared().registerForRemoteNotifications()
                }
            } else {
                print("Permission denied: \(error?.localizedDescription ?? "")")
                CloudKitManager.shared.pushRegistrationFailed("Bildirim izni verilmedi. Ayarlar > Bildirimler'den açın.")
                CloudKitManager.shared.pushRegistered = false
            }
        }
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
        CloudKitManager.shared.pushRegistered = true
    }
    
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("Failed to register: \(error.localizedDescription)")
        CloudKitManager.shared.pushRegistrationFailed("Push kaydı yapılamadı: \(error.localizedDescription)")
        CloudKitManager.shared.pushRegistered = false
    }
    
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        print("Received remote notification")
        
        // Check if it's a CloudKit notification
        if let dict = userInfo as? [String: NSObject] {
            let notification = CKNotification(fromRemoteNotificationDictionary: dict)
            
            if let queryNotification = notification as? CKQueryNotification {
                // CloudKit uses "cok" (Collapse Key) or "aps.category" for categories in userInfo for some pushes,
                // but CKNotification object properties are best.
                // Note: 'category' property on CKNotification is deprecated in favor of UserNotifications framework,
                // but inside WatchKit background execution, checking the raw payload is sometimes necessary if UNUserNotificationCenter isn't triggering.
                // However, we will try to be safe.
                
                // Inspecting the 'aps' dictionary directly is a reliable fallback for category
                let category = (userInfo["aps"] as? [String: Any])?["category"] as? String
                
                if category == "Heartbeat" {
                    // It's a Heartbeat
                    WKInterfaceDevice.current().play(.notification)
                    CloudKitManager.shared.markHeartbeatReceived()
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("HeartbeatReceived"), object: nil)
                    }
                } else if category == "PartnerLocation" {
                    // Partner location updated
                    PresenceManager.shared.fetchPartnerLocation()
                } else if category == "VoiceMessage" {
                    // Voice message received
                    WKInterfaceDevice.current().play(.notification)
                    VoiceManager.shared.checkForIncomingMessages()
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("VoiceMessageReceived"), object: nil)
                    }
                } else if category == "Pairing" || queryNotification.recordID != nil {
                    // It's a Pairing Session update
                    if let recordID = queryNotification.recordID {
                        print("Received update for record: \(recordID.recordName)")
                        CloudKitManager.shared.checkPairingStatus(recordID: recordID)
                    }
                }
                
                completionHandler(.newData)
                return
            }
        }
        
        completionHandler(.noData)
    }
    
    // MARK: - Notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case "HEART_REPLY":
            CloudKitManager.shared.sendHeartbeat()
            WKInterfaceDevice.current().play(.success)
            
        case "KISS_EMOJI", "HUG_EMOJI", "LOVE_EMOJI":
            // For now, all emoji actions send a heartbeat
            // Future: Could send different reaction types
            CloudKitManager.shared.sendHeartbeat()
            WKInterfaceDevice.current().play(.success)
            
        case "PLAY_VOICE":
            // Open app and play voice message
            VoiceManager.shared.playIncomingMessage()
            WKInterfaceDevice.current().play(.notification)
            
        default:
            break
        }
    }
    
    private func setupNotificationCategories(center: UNUserNotificationCenter) {
        // MARK: - Heartbeat category with emoji actions
        let heartReply = UNNotificationAction(
            identifier: "HEART_REPLY",
            title: "💖 Kalp Gönder",
            options: [.authenticationRequired]
        )
        let kissEmoji = UNNotificationAction(
            identifier: "KISS_EMOJI",
            title: "😘",
            options: []
        )
        let hugEmoji = UNNotificationAction(
            identifier: "HUG_EMOJI",
            title: "🤗",
            options: []
        )
        let loveEmoji = UNNotificationAction(
            identifier: "LOVE_EMOJI",
            title: "🥰",
            options: []
        )
        let heartbeatCategory = UNNotificationCategory(
            identifier: "Heartbeat",
            actions: [heartReply, kissEmoji, hugEmoji, loveEmoji],
            intentIdentifiers: [],
            options: []
        )
        
        // MARK: - Voice message category
        let playVoice = UNNotificationAction(
            identifier: "PLAY_VOICE",
            title: "▶️ Dinle",
            options: [.foreground]
        )
        let voiceCategory = UNNotificationCategory(
            identifier: "VoiceMessage",
            actions: [playVoice, heartReply],
            intentIdentifiers: [],
            options: []
        )
        
        // MARK: - Encounter category
        let sendHeart = UNNotificationAction(
            identifier: "HEART_REPLY",
            title: "💜 Kalp Gönder",
            options: []
        )
        let encounterCategory = UNNotificationCategory(
            identifier: "Encounter",
            actions: [sendHeart],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([heartbeatCategory, voiceCategory, encounterCategory])
    }
    
    // MARK: - Complication quick action
    func handle(_ userActivity: NSUserActivity) {
        // CLKLaunchedFromComplication is just a String; use literal to avoid missing symbol issues
        if userActivity.activityType == "com.apple.clockkit.launchfromcomplication" {
            CloudKitManager.shared.sendHeartbeat()
            WKInterfaceDevice.current().play(.success)
        }
    }
}
