import CloudKit
import Combine

/// HeartbeatService - Handles heartbeat sending and subscription
/// Extracted from CloudKitManager for better separation of concerns
@MainActor
class HeartbeatService: ObservableObject {
    
    // MARK: - Configuration
    private enum Config {
        static let heartbeatTimeout: TimeInterval = 10.0
        static let heartbeatCooldown: TimeInterval = 2.0
        static let maxRetryAttempts = 2
        static let subscriptionID = "Heartbeat-Sub"
    }
    
    // MARK: - Properties
    private let container = CKContainer(identifier: "iCloud.com.adilemre.selfprod")
    private lazy var database = container.publicCloudDatabase
    private var lastHeartbeatAttempt: Date?
    
    @Published var isSendingHeartbeat: Bool = false
    @Published var lastSentAt: Date?
    @Published var lastReceivedAt: Date?
    @Published var heartbeatSubscribed: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Singleton
    static let shared = HeartbeatService()
    private init() {
        // Load persisted dates
        lastSentAt = UserDefaults.standard.object(forKey: "LastHeartbeatSentAt") as? Date
        lastReceivedAt = UserDefaults.standard.object(forKey: "LastHeartbeatReceivedAt") as? Date
    }
    
    // MARK: - Send Heartbeat
    func send(from userID: String, to partnerID: String, completion: @escaping (Bool) -> Void) {
        // Prevent concurrent sending
        guard !isSendingHeartbeat else {
            completion(false)
            return
        }
        
        isSendingHeartbeat = true
        
        // Debounce: prevent rapid fire
        if let last = lastHeartbeatAttempt, Date().timeIntervalSince(last) < Config.heartbeatCooldown {
            isSendingHeartbeat = false
            completion(false)
            return
        }
        lastHeartbeatAttempt = Date()
        
        // Prevent self-loop
        guard userID != partnerID else {
            errorMessage = "Kendine kalp gönderemezsin. Eşleşmeyi yenile."
            isSendingHeartbeat = false
            completion(false)
            return
        }
        
        let timestamp = Date()
        let record = CKRecord(recordType: "Heartbeat")
        record["fromID"] = userID
        record["toID"] = partnerID
        record["timestamp"] = timestamp
        
        sendWithTimeout(record: record, timestamp: timestamp, timeout: Config.heartbeatTimeout, attempt: 1, completion: completion)
    }
    
    // MARK: - Private Send Logic
    private func sendWithTimeout(record: CKRecord, timestamp: Date, timeout: TimeInterval, attempt: Int, completion: @escaping (Bool) -> Void) {
        var completed = false
        
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !completed {
                completed = true
                DispatchQueue.main.async {
                    self.errorMessage = "Bağlantı zaman aşımına uğradı."
                    self.isSendingHeartbeat = false
                }
                completion(false)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        
        database.save(record) { [weak self] savedRecord, error in
            guard let self = self else { return }
            guard !completed else { return }
            
            completed = true
            timeoutWork.cancel()
            
            if let error = error {
                // Retry on network error
                if attempt < Config.maxRetryAttempts && self.isNetworkRelated(error) {
                    let delay = self.retryDelay(for: attempt)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.sendWithTimeout(record: record, timestamp: timestamp, timeout: Config.heartbeatTimeout, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.handleError(error)
                    self.isSendingHeartbeat = false
                }
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = nil
                    self.lastSentAt = timestamp
                    self.persistDate(timestamp, key: "LastHeartbeatSentAt")
                    self.isSendingHeartbeat = false
                }
                completion(true)
            }
        }
    }
    
    // MARK: - Subscribe to Heartbeats
    func subscribeToHeartbeats(for userID: String) {
        guard !heartbeatSubscribed else { return }
        
        let predicate = NSPredicate(format: "toID == %@", userID)
        let subscription = CKQuerySubscription(
            recordType: "Heartbeat",
            predicate: predicate,
            subscriptionID: Config.subscriptionID,
            options: [.firesOnRecordCreation]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.alertBody = "Aşkım seni çok özlemiş 💖"
        info.soundName = "default"
        info.shouldBadge = true
        info.category = "Heartbeat"
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error as? CKError {
                    let desc = error.localizedDescription.lowercased()
                    if desc.contains("exists") || desc.contains("duplicate") {
                        self?.heartbeatSubscribed = true
                    }
                } else {
                    self?.heartbeatSubscribed = true
                }
            }
        }
    }
    
    // MARK: - Receive Heartbeat
    func markHeartbeatReceived() {
        lastReceivedAt = Date()
        persistDate(lastReceivedAt, key: "LastHeartbeatReceivedAt")
        NotificationCenter.default.post(name: Notification.Name("HeartbeatReceived"), object: nil)
    }
    
    // MARK: - Helpers
    private func isNetworkRelated(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            return [.networkUnavailable, .networkFailure, .serviceUnavailable].contains(ckError.code)
        }
        return false
    }
    
    private func retryDelay(for attempt: Int) -> TimeInterval {
        min(pow(2.0, Double(attempt - 1)), 30.0)
    }
    
    private func handleError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                errorMessage = "İnternet bağlantınızı kontrol edin."
            case .serviceUnavailable:
                errorMessage = "iCloud servisi şu an ulaşılamıyor."
            case .requestRateLimited:
                errorMessage = "Çok fazla istek. Biraz bekleyin."
            default:
                errorMessage = "Gönderilemedi: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Gönderilemedi: \(error.localizedDescription)"
        }
    }
    
    private func persistDate(_ date: Date?, key: String) {
        if let date = date {
            UserDefaults.standard.set(date, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
