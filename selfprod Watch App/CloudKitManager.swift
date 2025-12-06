import CloudKit
import Combine

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.adilemre.selfprod")
    private lazy var database = container.publicCloudDatabase
    
    @Published var currentUserID: String?
    @Published var partnerID: String? {
        didSet {
            if let id = partnerID {
                UserDefaults.standard.set(id, forKey: "partnerID")
            }
        }
    }
    @Published var isPaired: Bool = false
    @Published var errorMessage: String?
    @Published var permissionStatus: CKAccountStatus = .couldNotDetermine
    
    private init() {
        self.partnerID = UserDefaults.standard.string(forKey: "partnerID")
        self.isPaired = self.partnerID != nil
        
        checkAccountStatus()
    }
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.permissionStatus = status
                switch status {
                case .available:
                    self?.getCurrentUserID()
                case .noAccount:
                    self?.errorMessage = "Lütfen iCloud hesabınıza giriş yapın."
                case .restricted:
                    self?.errorMessage = "iCloud erişimi kısıtlanmış."
                case .couldNotDetermine:
                     if let error = error {
                        self?.errorMessage = "Hata: \(error.localizedDescription)"
                     } else {
                        self?.errorMessage = "iCloud durumu belirlenemedi."
                     }
                @unknown default:
                    self?.errorMessage = "Bilinmeyen iCloud durumu."
                }
            }
        }
    }
    
    func getCurrentUserID() {
        container.fetchUserRecordID { [weak self] recordID, error in
            if let id = recordID?.recordName {
                DispatchQueue.main.async {
                    self?.currentUserID = id
                    print("User ID found: \(id)")
                    
                    if self?.isPaired == true {
                        self?.subscribeToHeartbeats()
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    print("Error getting user ID: \(error.localizedDescription)")
                    self?.errorMessage = "Kullanıcı kimliği alınamadı: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Pairing
    
    func generatePairingCode(completion: @escaping (String?) -> Void) {
        guard let myID = currentUserID else { completion(nil); return }
        
        // Prevent concurrent requests
        guard permissionStatus == .available || permissionStatus == .couldNotDetermine else {
            completion(nil)
            return
        }
        
        // 1. Invalidate (Delete) old sessions first
        invalidatePreviousSessions { [weak self] in
            guard let self = self else { return }
            
            // 2. Generate new code
            let code = String(Int.random(in: 100000...999999))
            let record = CKRecord(recordType: "PairingSession")
            record["code"] = code
            record["initiatorID"] = myID
            
            self.database.save(record) { savedRecord, error in
                if error == nil {
                    print("Pairing code generated: \(code)")
                    DispatchQueue.main.async {
                        if let rID = savedRecord?.recordID {
                            self.subscribeToPairingUpdate(recordID: rID)
                        }
                    }
                    completion(code)
                } else {
                    DispatchQueue.main.async {
                        print("Error generating code: \(error?.localizedDescription ?? "")")
                        self.errorMessage = "Kod oluşturulamadı: \(error?.localizedDescription ?? "Bilinmeyen Hata")"
                    }
                    completion(nil)
                }
            }
        }
    }
    
    private func invalidatePreviousSessions(completion: @escaping () -> Void) {
        guard let myID = currentUserID else { completion(); return }
        
        let predicate = NSPredicate(format: "initiatorID == %@", myID)
        let query = CKQuery(recordType: "PairingSession", predicate: predicate)
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 10) { [weak self] result in
            switch result {
            case .success(let (results, _)):
                let recordsToDelete = results.compactMap { try? $0.1.get().recordID }
                
                if recordsToDelete.isEmpty {
                    completion()
                    return
                }
                
                let modifyOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
                modifyOp.modifyRecordsResultBlock = { _ in
                    // We don't strictly care if delete fails or succeeds, just proceed
                    print("Invalidated \(recordsToDelete.count) old sessions.")
                    completion()
                }
                self?.database.add(modifyOp)
                
            case .failure(let error):
                print("Failed to fetch old sessions for invalidation: \(error.localizedDescription)")
                // Proceed anyway, not blocking
                completion()
            }
        }
    }
    
    func enterPairingCode(_ code: String, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "code == %@", code)
        let query = CKQuery(recordType: "PairingSession", predicate: predicate)
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
            switch result {
            case .success(let (results, _)):
                guard let self = self, 
                      let match = results.first, 
                      let record = try? match.1.get(),
                      let myID = self.currentUserID else {
                    completion(false)
                    return
                }
                
                // Found session, update with my ID
                record["receiverID"] = myID
                
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                modifyOp.savePolicy = .changedKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        // Success, I am paired to the initiator
                        if let initiatorID = record["initiatorID"] as? String {
                            DispatchQueue.main.async {
                                self.partnerID = initiatorID
                                self.isPaired = true
                                self.subscribeToHeartbeats()
                                completion(true)
                            }
                        } else {
                            completion(false)
                        }
                    case .failure(let error):
                        print("Modified failed: \(error.localizedDescription)")
                        completion(false)
                    }
                }
                self.database.add(modifyOp)
                
            case .failure(let error):
                print("Fetch failed: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    private func subscribeToPairingUpdate(recordID: CKRecord.ID) {
        let subscriptionID = "Pairing-\(recordID.recordName)"
        let subscription = CKQuerySubscription(recordType: "PairingSession", predicate: NSPredicate(format: "recordID == %@", recordID), subscriptionID: subscriptionID, options: [.firesOnRecordUpdate])
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.category = "Pairing"
        subscription.notificationInfo = info
        
        database.save(subscription) { _, error in
            if let error = error {
                print("Subscription failed: \(error.localizedDescription)")
            } else {
                print("Listening for pairing completion...")
            }
        }
    }
    
    func checkPairingStatus(recordID: CKRecord.ID) {
        database.fetch(withRecordID: recordID) { [weak self] record, error in
            if let record = record, let receiverID = record["receiverID"] as? String {
                DispatchQueue.main.async {
                    self?.partnerID = receiverID
                    self?.isPaired = true
                    self?.subscribeToHeartbeats()
                }
            }
        }
    }
    
    // MARK: - Heartbeat
    
    func sendHeartbeat() {
        guard let myID = currentUserID, let pID = partnerID else { return }
        
        let record = CKRecord(recordType: "Heartbeat")
        record["fromID"] = myID
        record["toID"] = pID
        record["timestamp"] = Date()
        
        database.save(record) { _, error in
            if let error = error {
                print("Failed to send heartbeat: \(error.localizedDescription)")
            } else {
                print("Heartbeat sent!")
            }
        }
    }
    
    func subscribeToHeartbeats() {
        guard let myID = currentUserID else { return }
        
        // Subscribe to Heartbeats where toID == myID
        let subscriptionID = "Heartbeat-Sub"
        let predicate = NSPredicate(format: "toID == %@", myID)
        let subscription = CKQuerySubscription(recordType: "Heartbeat", predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation])
        
        let info = CKSubscription.NotificationInfo()
        info.alertBody = "Seni özledimmm 🧡"
        info.soundName = "default"
        info.shouldBadge = true
        info.category = "Heartbeat"
        subscription.notificationInfo = info
        
        database.save(subscription) { _, error in
            if let error = error {
                // Subscription might already exist, which is fine
                print("Heartbeat subscription result: \(error.localizedDescription)")
            } else {
                print("Subscribed to heartbeats.")
            }
        }
    }
}
