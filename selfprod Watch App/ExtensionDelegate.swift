import WatchKit
import UserNotifications
import CloudKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        print("App Launched")
        registerForPushNotifications()
    }
    
    func applicationDidBecomeActive() {
        CloudKitManager.shared.checkAccountStatus()
    }
    
    func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Permission granted")
                DispatchQueue.main.async {
                    WKExtension.shared().registerForRemoteNotifications()
                }
            } else {
                print("Permission denied: \(error?.localizedDescription ?? "")")
                CloudKitManager.shared.pushRegistrationFailed("Bildirim izni verilmedi. Ayarlar > Bildirimler'den açın.")
            }
        }
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
    }
    
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("Failed to register: \(error.localizedDescription)")
        CloudKitManager.shared.pushRegistrationFailed("Push kaydı yapılamadı: \(error.localizedDescription)")
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
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("HeartbeatReceived"), object: nil)
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
}
