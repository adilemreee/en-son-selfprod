import CloudKit
import Combine

/// PairingService - Handles pairing code generation and validation
/// Extracted from CloudKitManager for better separation of concerns
@MainActor
class PairingService: ObservableObject {
    
    // MARK: - Configuration
    private enum Config {
        static let pairingTTL: TimeInterval = 10 * 60 // 10 minutes
        static let pairingCodeLength = 6
    }
    
    // MARK: - Properties
    private let container = CKContainer(identifier: "iCloud.com.adilemre.selfprod")
    private lazy var database = container.publicCloudDatabase
    
    @Published var lastPairingRecordID: CKRecord.ID?
    @Published var pairingSubscribed: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Singleton
    static let shared = PairingService()
    private init() {}
    
    // MARK: - Generate Pairing Code
    func generateCode(for userID: String, completion: @escaping (String?) -> Void) {
        // Invalidate old sessions first
        invalidatePreviousSessions(for: userID) { [weak self] in
            guard let self = self else { return }
            
            let code = String(Int.random(in: 100000...999999))
            let record = CKRecord(recordType: "PairingSession")
            record["code"] = code
            record["initiatorID"] = userID
            record["expiresAt"] = Date().addingTimeInterval(Config.pairingTTL)
            record["used"] = false
            
            self.database.save(record) { [weak self] savedRecord, error in
                guard let self = self else { return }
                
                if error == nil {
                    #if DEBUG
                    print("Pairing code generated: \(code)")
                    #endif
                    DispatchQueue.main.async {
                        if let rID = savedRecord?.recordID {
                            self.lastPairingRecordID = rID
                            self.subscribeToPairingUpdate(recordID: rID)
                        }
                        self.errorMessage = nil
                    }
                    completion(code)
                } else {
                    #if DEBUG
                    print("Error generating code: \(error?.localizedDescription ?? "")")
                    #endif
                    DispatchQueue.main.async {
                        self.errorMessage = "Gönderilemedi: \(error?.localizedDescription ?? "Bilinmeyen Hata")"
                    }
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Enter Pairing Code
    func enterCode(_ code: String, userID: String, completion: @escaping (Result<String, CloudKitError>) -> Void) {
        let sanitizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitizedCode.count == Config.pairingCodeLength,
              sanitizedCode.allSatisfy({ $0.isNumber }) else {
            completion(.failure(.invalidCodeFormat))
            return
        }
        
        let predicate = NSPredicate(format: "code == %@", sanitizedCode)
        let query = CKQuery(recordType: "PairingSession", predicate: predicate)
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
            switch result {
            case .success(let (results, _)):
                guard let match = results.first,
                      let record = try? match.1.get() else {
                    completion(.failure(.codeNotFound))
                    return
                }
                
                // Check expiration
                if let expiresAt = record["expiresAt"] as? Date, expiresAt < Date() {
                    completion(.failure(.pairingExpired))
                    return
                }
                
                // Check if already used
                if (record["used"] as? Bool) == true || record["receiverID"] != nil {
                    completion(.failure(.codeAlreadyUsed))
                    return
                }
                
                // Update session with receiver ID
                record["receiverID"] = userID
                record["used"] = true
                
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                modifyOp.savePolicy = .changedKeys
                modifyOp.modifyRecordsResultBlock = { modifyResult in
                    switch modifyResult {
                    case .success:
                        if let initiatorID = record["initiatorID"] as? String {
                            completion(.success(initiatorID))
                        } else {
                            completion(.failure(.pairingFailed("Initiator ID bulunamadı")))
                        }
                    case .failure(let error):
                        completion(.failure(.pairingFailed(error.localizedDescription)))
                    }
                }
                self?.database.add(modifyOp)
                
            case .failure(let error):
                completion(.failure(.fetchFailed(error.localizedDescription)))
            }
        }
    }
    
    // MARK: - Private Helpers
    private func invalidatePreviousSessions(for userID: String, completion: @escaping () -> Void) {
        let predicate = NSPredicate(format: "initiatorID == %@", userID)
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
                    #if DEBUG
                    print("Invalidated \(recordsToDelete.count) old sessions.")
                    #endif
                    completion()
                }
                self?.database.add(modifyOp)
                
            case .failure:
                completion()
            }
        }
    }
    
    private func subscribeToPairingUpdate(recordID: CKRecord.ID) {
        let subscriptionID = "Pairing-\(recordID.recordName)"
        let subscription = CKQuerySubscription(
            recordType: "PairingSession",
            predicate: NSPredicate(format: "recordID == %@", recordID),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.category = "Pairing"
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error as? CKError {
                    let desc = error.localizedDescription.lowercased()
                    if desc.contains("exists") || desc.contains("duplicate") {
                        self?.pairingSubscribed = true
                    }
                } else {
                    self?.pairingSubscribed = true
                }
            }
        }
    }
}
