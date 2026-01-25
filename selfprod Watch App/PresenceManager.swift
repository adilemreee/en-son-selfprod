import CoreLocation
import CloudKit
import Combine
import WatchKit

/// Robust Presence Manager - Enhanced for reliable location tracking
/// Features: Retry logic, location validation, periodic refresh, error recovery
@MainActor
class PresenceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PresenceManager()
    
    // MARK: - Configuration
    private enum Config {
        /// Distance threshold in meters to consider "nearby"
        static let proximityThreshold: CLLocationDistance = 100.0
        
        /// Minimum time between location updates to CloudKit (seconds)
        static let locationUpdateInterval: TimeInterval = 3 * 60 // 3 minutes (reduced for faster updates)
        
        /// Partner location refresh interval (seconds)
        static let partnerRefreshInterval: TimeInterval = 60 // 1 minute
        
        /// Minimum distance change to trigger update (meters)
        static let distanceFilter: CLLocationDistance = 30.0 // More sensitive
        
        /// Cooldown between encounter notifications (seconds)
        static let encounterCooldown: TimeInterval = 30 * 60 // 30 minutes
        
        /// Location record TTL (seconds)
        static let locationTTL: TimeInterval = 10 * 60 // 10 minutes
        
        /// Distance threshold for high accuracy mode (meters)
        static let highAccuracyThreshold: CLLocationDistance = 1000.0
        
        /// Maximum location age to consider valid (seconds)
        static let maxLocationAge: TimeInterval = 120 // 2 minutes
        
        /// Minimum horizontal accuracy for valid location (meters)
        static let minAccuracy: CLLocationAccuracy = 200.0
        
        /// Retry count for CloudKit operations
        static let maxRetryCount = 3
        
        /// Base retry delay (seconds)
        static let retryDelay: TimeInterval = 2.0
    }
    
    private enum StorageKeys {
        static let presenceEnabled = "PresenceTrackingEnabled"
        static let continuousTracking = "ContinuousTrackingEnabled"
        static let lastEncounterTime = "LastEncounterTime"
        static let lastKnownLat = "LastKnownLatitude"
        static let lastKnownLon = "LastKnownLongitude"
    }
    
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private let container = CKContainer(identifier: "iCloud.com.adilemre.selfprod")
    private lazy var database = container.publicCloudDatabase
    
    private var lastLocationUpdate: Date?
    private var lastEncounterTime: Date?
    private var locationSubscribed = false
    private var partnerRefreshTimer: Timer?
    private var retryCount = 0
    
    // MARK: - Published Properties
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: StorageKeys.presenceEnabled)
            if isEnabled {
                startTracking()
            } else {
                stopTracking()
            }
        }
    }
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var partnerLocation: CLLocation?
    @Published var partnerLocationTimestamp: Date?
    @Published var isNearPartner: Bool = false
    @Published var distanceToPartner: CLLocationDistance?
    @Published var lastEncounter: Date?
    @Published var errorMessage: String?
    @Published var locationStatus: LocationStatus = .unknown
    @Published var lastSyncTime: Date?
    
    /// Continuous tracking mode - faster updates and more frequent sync
    @Published var continuousTrackingEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(continuousTrackingEnabled, forKey: StorageKeys.continuousTracking)
            if isEnabled {
                restartPartnerRefreshTimer()
            }
        }
    }
    
    // MARK: - Location Status Enum
    enum LocationStatus: String {
        case unknown = "Bilinmiyor"
        case acquiring = "Konum alınıyor..."
        case active = "Aktif"
        case stale = "Eski konum"
        case error = "Hata"
        case noPermission = "İzin yok"
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = Config.distanceFilter
        
        // Load saved state
        isEnabled = UserDefaults.standard.bool(forKey: StorageKeys.presenceEnabled)
        continuousTrackingEnabled = UserDefaults.standard.bool(forKey: StorageKeys.continuousTracking)
        lastEncounterTime = UserDefaults.standard.object(forKey: StorageKeys.lastEncounterTime) as? Date
        lastEncounter = lastEncounterTime
        
        // Load last known location
        loadLastKnownLocation()
        
        // Check current authorization
        authorizationStatus = locationManager.authorizationStatus
        updateLocationStatus()
        
        // Auto-enable if paired and has authorization
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if CloudKitManager.shared.isPaired && !isEnabled {
                isEnabled = true
            }
        }
        
        #if DEBUG
        print("🗺️ PresenceManager initialized, enabled: \(isEnabled), continuous: \(continuousTrackingEnabled)")
        #endif
    }
    
    deinit {
        partnerRefreshTimer?.invalidate()
        partnerRefreshTimer = nil
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        #if DEBUG
        print("📍 Requesting location authorization...")
        #endif
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Auto-Activate on App Launch
    /// Called when app becomes active - auto-starts location if paired
    func activateOnAppLaunch() {
        guard CloudKitManager.shared.isPaired else {
            #if DEBUG
            print("📍 Not paired, skipping location activation")
            #endif
            return
        }
        
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            requestAuthorization()
            return
        }
        
        // Auto-enable and start tracking
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if !isEnabled {
                #if DEBUG
                print("📍 Auto-enabling location tracking on app launch")
                #endif
                isEnabled = true
            } else {
                #if DEBUG
                print("📍 Force refreshing location on app launch")
                #endif
                forceRefresh()
            }
        }
    }
    
    // MARK: - Tracking Control
    func startTracking() {
        #if DEBUG
        print("🟢 Starting presence tracking...")
        #endif
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationStatus = .noPermission
            requestAuthorization()
            return
        }
        
        locationStatus = .acquiring
        locationManager.startUpdatingLocation()
        subscribeToPartnerLocation()
        startPartnerRefreshTimer()
        
        // Immediately fetch partner location
        fetchPartnerLocation()
        
        #if DEBUG
        print("✅ Presence tracking started")
        #endif
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        stopPartnerRefreshTimer()
        locationStatus = .unknown
        
        #if DEBUG
        print("🔴 Presence tracking stopped")
        #endif
    }
    
    // MARK: - Periodic Partner Refresh
    private func startPartnerRefreshTimer() {
        stopPartnerRefreshTimer()
        let interval = continuousTrackingEnabled ? 30.0 : Config.partnerRefreshInterval
        partnerRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchPartnerLocation()
        }
        #if DEBUG
        print("⏱️ Partner refresh timer started with interval: \(interval)s")
        #endif
    }
    
    private func stopPartnerRefreshTimer() {
        partnerRefreshTimer?.invalidate()
        partnerRefreshTimer = nil
    }
    
    private func restartPartnerRefreshTimer() {
        if isEnabled {
            startPartnerRefreshTimer()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validate location quality
        guard isValidLocation(location) else {
            #if DEBUG
            print("⚠️ Invalid location received: accuracy=\(location.horizontalAccuracy)m, age=\(abs(location.timestamp.timeIntervalSinceNow))s")
            #endif
            return
        }
        
        #if DEBUG
        print("📍 Valid location: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
        #endif
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.locationStatus = .active
            self.errorMessage = nil
        }
        
        // Save last known location
        saveLastKnownLocation(location)
        
        // Check if we should update CloudKit
        if shouldUpdateCloudKit() {
            updateLocationInCloudKit(location)
        }
        
        // Check proximity to partner
        checkProximity()
        
        // Adaptive accuracy
        updateLocationAccuracy()
    }
    
    private func isValidLocation(_ location: CLLocation) -> Bool {
        // Check accuracy
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= Config.minAccuracy else {
            return false
        }
        
        // Check age
        let age = abs(location.timestamp.timeIntervalSinceNow)
        guard age <= Config.maxLocationAge else {
            return false
        }
        
        // Check valid coordinates
        guard location.coordinate.latitude != 0 || location.coordinate.longitude != 0 else {
            return false
        }
        
        return true
    }
    
    private func saveLastKnownLocation(_ location: CLLocation) {
        UserDefaults.standard.set(location.coordinate.latitude, forKey: StorageKeys.lastKnownLat)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: StorageKeys.lastKnownLon)
    }
    
    private func loadLastKnownLocation() {
        let lat = UserDefaults.standard.double(forKey: StorageKeys.lastKnownLat)
        let lon = UserDefaults.standard.double(forKey: StorageKeys.lastKnownLon)
        
        if lat != 0 || lon != 0 {
            currentLocation = CLLocation(latitude: lat, longitude: lon)
            #if DEBUG
            print("📍 Loaded last known location: \(lat), \(lon)")
            #endif
        }
    }
    
    // MARK: - Adaptive Accuracy
    private func updateLocationAccuracy() {
        if let distance = distanceToPartner {
            if distance <= Config.highAccuracyThreshold {
                if locationManager.desiredAccuracy != kCLLocationAccuracyBest {
                    locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager.distanceFilter = 10.0
                    #if DEBUG
                    print("🎯 High accuracy mode - partner is \(Int(distance))m away")
                    #endif
                }
            } else {
                if locationManager.desiredAccuracy != kCLLocationAccuracyHundredMeters {
                    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                    locationManager.distanceFilter = Config.distanceFilter
                    #if DEBUG
                    print("🔋 Battery saving mode - partner is \(Int(distance))m away")
                    #endif
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("❌ Location error: \(error.localizedDescription)")
        #endif
        
        DispatchQueue.main.async {
            self.locationStatus = .error
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.errorMessage = "Konum izni verilmedi"
                    self.locationStatus = .noPermission
                case .locationUnknown:
                    self.errorMessage = "Konum şu an belirlenemiyor"
                default:
                    self.errorMessage = "Konum hatası: \(clError.code.rawValue)"
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.updateLocationStatus()
            
            #if DEBUG
            print("🔐 Authorization changed: \(manager.authorizationStatus.rawValue)")
            #endif
            
            if self.isEnabled && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
                self.startTracking()
            }
        }
    }
    
    private func updateLocationStatus() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if currentLocation != nil {
                locationStatus = .active
            } else {
                locationStatus = .acquiring
            }
        case .denied, .restricted:
            locationStatus = .noPermission
        default:
            locationStatus = .unknown
        }
    }
    
    // MARK: - CloudKit Location Sync
    private func shouldUpdateCloudKit() -> Bool {
        guard let lastUpdate = lastLocationUpdate else {
            #if DEBUG
            print("📍 First location update - sending immediately to CloudKit")
            #endif
            return true
        }
        // Continuous mode: update every 1 minute, normal mode: every 3 minutes
        let interval = continuousTrackingEnabled ? 60.0 : Config.locationUpdateInterval
        return Date().timeIntervalSince(lastUpdate) >= interval
    }
    
    private func updateLocationInCloudKit(_ location: CLLocation, retryAttempt: Int = 0) {
        guard let myID = CloudKitManager.shared.currentUserID else {
            #if DEBUG
            print("⚠️ No user ID, skipping CloudKit update")
            #endif
            return
        }
        
        #if DEBUG
        print("☁️ Updating location in CloudKit (attempt \(retryAttempt + 1))...")
        #endif
        
        lastLocationUpdate = Date()
        
        // Delete old records first
        deleteOldLocationRecords(for: myID) { [weak self] in
            guard let self = self else { return }
            
            // Create new location record
            let record = CKRecord(recordType: "UserLocation")
            record["userID"] = myID
            record["latitude"] = location.coordinate.latitude
            record["longitude"] = location.coordinate.longitude
            record["timestamp"] = Date()
            record["expiresAt"] = Date().addingTimeInterval(Config.locationTTL)
            record["accuracy"] = location.horizontalAccuracy
            
            self.database.save(record) { [weak self] savedRecord, error in
                if let error = error {
                    #if DEBUG
                    print("❌ Failed to save location: \(error.localizedDescription)")
                    #endif
                    
                    // Retry with exponential backoff
                    if retryAttempt < Config.maxRetryCount {
                        let delay = Config.retryDelay * pow(2.0, Double(retryAttempt))
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self?.updateLocationInCloudKit(location, retryAttempt: retryAttempt + 1)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.lastSyncTime = Date()
                    }
                    #if DEBUG
                    print("✅ Location saved to CloudKit")
                    #endif
                }
            }
        }
    }
    
    private func deleteOldLocationRecords(for userID: String, completion: @escaping () -> Void) {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserLocation", predicate: predicate)
        
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
                    completion()
                }
                self?.database.add(modifyOp)
                
            case .failure:
                completion()
            }
        }
    }
    
    // MARK: - Partner Location Subscription
    private func subscribeToPartnerLocation() {
        guard !locationSubscribed else { return }
        guard let partnerID = CloudKitManager.shared.partnerID else {
            #if DEBUG
            print("⚠️ No partner ID, skipping subscription")
            #endif
            return
        }
        
        let subscriptionID = "PartnerLocation-Sub"
        let predicate = NSPredicate(format: "userID == %@", partnerID)
        let subscription = CKQuerySubscription(
            recordType: "UserLocation",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.category = "PartnerLocation"
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            if let error = error as? CKError {
                let description = error.localizedDescription.lowercased()
                if description.contains("already exists") || description.contains("duplicate") {
                    self?.locationSubscribed = true
                    #if DEBUG
                    print("📱 Partner subscription already exists")
                    #endif
                }
            } else {
                self?.locationSubscribed = true
                #if DEBUG
                print("✅ Subscribed to partner location updates")
                #endif
            }
        }
    }
    
    // MARK: - Fetch Partner Location
    func fetchPartnerLocation() {
        guard let partnerID = CloudKitManager.shared.partnerID else { return }
        
        #if DEBUG
        print("🔄 Fetching partner location...")
        #endif
        
        let predicate = NSPredicate(format: "userID == %@", partnerID)
        let query = CKQuery(recordType: "UserLocation", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
            switch result {
            case .success(let (results, _)):
                guard let match = results.first,
                      let record = try? match.1.get(),
                      let lat = record["latitude"] as? Double,
                      let lon = record["longitude"] as? Double else {
                    DispatchQueue.main.async {
                        self?.partnerLocation = nil
                        self?.partnerLocationTimestamp = nil
                        self?.distanceToPartner = nil
                        self?.isNearPartner = false
                    }
                    #if DEBUG
                    print("⚠️ No partner location found")
                    #endif
                    return
                }
                
                // Check if expired
                if let expiresAt = record["expiresAt"] as? Date, expiresAt < Date() {
                    DispatchQueue.main.async {
                        self?.partnerLocation = nil
                        self?.partnerLocationTimestamp = nil
                        self?.distanceToPartner = nil
                        self?.isNearPartner = false
                    }
                    #if DEBUG
                    print("⏰ Partner location expired")
                    #endif
                    return
                }
                
                let location = CLLocation(latitude: lat, longitude: lon)
                let timestamp = record["timestamp"] as? Date ?? Date()
                
                DispatchQueue.main.async {
                    self?.partnerLocation = location
                    self?.partnerLocationTimestamp = timestamp
                    self?.checkProximity()
                    
                    // Post notification
                    NotificationCenter.default.post(name: .partnerLocationUpdated, object: nil)
                }
                
                #if DEBUG
                print("✅ Partner location: \(lat), \(lon)")
                #endif
                
            case .failure(let error):
                #if DEBUG
                print("❌ Failed to fetch partner location: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    // MARK: - Force Refresh
    func forceRefresh() {
        #if DEBUG
        print("🔄 Force refreshing locations...")
        #endif
        
        // Update own location immediately
        if let location = currentLocation {
            lastLocationUpdate = nil // Force update
            updateLocationInCloudKit(location)
        }
        
        // Fetch partner location
        fetchPartnerLocation()
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }
    
    // MARK: - Proximity Detection
    private func checkProximity() {
        guard let myLocation = currentLocation,
              let partnerLoc = partnerLocation else {
            DispatchQueue.main.async {
                self.isNearPartner = false
                self.distanceToPartner = nil
            }
            return
        }
        
        let distance = myLocation.distance(from: partnerLoc)
        
        DispatchQueue.main.async {
            self.distanceToPartner = distance
            
            let wasNear = self.isNearPartner
            self.isNearPartner = distance <= Config.proximityThreshold
            
            // Trigger encounter notification if just became near
            if self.isNearPartner && !wasNear {
                self.handleEncounter()
            }
            
            #if DEBUG
            print("📏 Distance to partner: \(Int(distance))m, isNear: \(self.isNearPartner)")
            #endif
        }
    }
    
    // MARK: - Encounter Handling
    private func handleEncounter() {
        // Check cooldown
        if let lastEncounter = lastEncounterTime,
           Date().timeIntervalSince(lastEncounter) < Config.encounterCooldown {
            #if DEBUG
            print("⏳ Encounter cooldown active, skipping")
            #endif
            return
        }
        
        lastEncounterTime = Date()
        UserDefaults.standard.set(lastEncounterTime, forKey: StorageKeys.lastEncounterTime)
        
        DispatchQueue.main.async {
            self.lastEncounter = self.lastEncounterTime
        }
        
        // Create encounter record
        createEncounterRecord()
        
        // Post notification
        NotificationCenter.default.post(name: .encounterDetected, object: nil)
        
        // Haptic
        WKInterfaceDevice.current().play(.notification)
        
        #if DEBUG
        print("🎉 Encounter detected! Distance: \(distanceToPartner ?? 0)m")
        #endif
    }
    
    private func createEncounterRecord() {
        guard let myID = CloudKitManager.shared.currentUserID,
              let partnerID = CloudKitManager.shared.partnerID else { return }
        
        let record = CKRecord(recordType: "Encounter")
        record["user1ID"] = myID
        record["user2ID"] = partnerID
        record["timestamp"] = Date()
        record["latitude"] = currentLocation?.coordinate.latitude ?? 0
        record["longitude"] = currentLocation?.coordinate.longitude ?? 0
        
        database.save(record) { _, error in
            #if DEBUG
            if let error = error {
                print("❌ Failed to save encounter: \(error.localizedDescription)")
            } else {
                print("✅ Encounter saved")
            }
            #endif
        }
    }
    
    // MARK: - Cleanup
    func clearLocationData() {
        guard let myID = CloudKitManager.shared.currentUserID else { return }
        deleteOldLocationRecords(for: myID) {}
        
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastKnownLat)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastKnownLon)
        
        DispatchQueue.main.async {
            self.currentLocation = nil
            self.partnerLocation = nil
            self.isNearPartner = false
            self.distanceToPartner = nil
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let encounterDetected = Notification.Name("EncounterDetected")
    static let partnerLocationUpdated = Notification.Name("PartnerLocationUpdated")
}

// MARK: - Distance Formatting Extension
extension CLLocationDistance {
    var formattedDistance: String {
        if self < 1000 {
            return String(format: "%.0f m", self)
        } else {
            return String(format: "%.1f km", self / 1000)
        }
    }
}
