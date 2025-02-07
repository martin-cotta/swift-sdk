//
//  Copyright © 2018 Iterable. All rights reserved.
//

import Foundation

struct UserDefaultsLocalStorage: LocalStorageProtocol {
    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }
    
    var userId: String? {
        get {
            string(withKey: .userId)
        } set {
            save(string: newValue, withKey: .userId)
        }
    }
    
    var email: String? {
        get {
            string(withKey: .email)
        } set {
            save(string: newValue, withKey: .email)
        }
    }
    
    var authToken: String? {
        get {
            string(withKey: .authToken)
        } set {
            save(string: newValue, withKey: .authToken)
        }
    }
    
    var ddlChecked: Bool {
        get {
            bool(withKey: .ddlChecked)
        } set {
            save(bool: newValue, withKey: .ddlChecked)
        }
    }
    
    var deviceId: String? {
        get {
            string(withKey: .deviceId)
        } set {
            save(string: newValue, withKey: .deviceId)
        }
    }
    
    var sdkVersion: String? {
        get {
            string(withKey: .sdkVersion)
        } set {
            save(string: newValue, withKey: .sdkVersion)
        }
    }
    
    var offlineMode: Bool {
        get {
            return bool(withKey: .offlineMode)
        } set {
            save(bool: newValue, withKey: .offlineMode)
        }
    }
    
    var offlineModeBeta: Bool {
        get {
            return bool(withKey: .offlineModeBeta)
        }
        set {
            save(bool: newValue, withKey: .offlineModeBeta)
        }
    }
    
    func getAttributionInfo(currentDate: Date) -> IterableAttributionInfo? {
        (try? codable(withKey: .attributionInfo, currentDate: currentDate)) ?? nil
    }
    
    func save(attributionInfo: IterableAttributionInfo?, withExpiration expiration: Date?) {
        try? save(codable: attributionInfo, withKey: .attributionInfo, andExpiration: expiration)
    }
    
    func getPayload(currentDate: Date) -> [AnyHashable: Any]? {
        (try? dict(withKey: .payload, currentDate: currentDate)) ?? nil
    }
    
    func save(payload: [AnyHashable: Any]?, withExpiration expiration: Date?) {
        try? save(dict: payload, withKey: .payload, andExpiration: expiration)
    }
    
    // MARK: Private implementation
    
    private let userDefaults: UserDefaults
    
    private func dict(withKey key: LocalStorageKey, currentDate: Date) throws -> [AnyHashable: Any]? {
        guard let encodedEnvelope = userDefaults.value(forKey: key.value) as? Data else {
            return nil
        }
        
        let envelope = try JSONDecoder().decode(Envelope.self, from: encodedEnvelope)
        let decoded = try JSONSerialization.jsonObject(with: envelope.payload, options: []) as? [AnyHashable: Any]
        
        if UserDefaultsLocalStorage.isExpired(expiration: envelope.expiration, currentDate: currentDate) {
            return nil
        } else {
            return decoded
        }
    }
    
    private func codable<T: Codable>(withKey key: LocalStorageKey, currentDate: Date) throws -> T? {
        guard let encodedEnvelope = userDefaults.value(forKey: key.value) as? Data else {
            return nil
        }
        
        let envelope = try JSONDecoder().decode(Envelope.self, from: encodedEnvelope)
        
        let decoded = try JSONDecoder().decode(T.self, from: envelope.payload)
        
        if UserDefaultsLocalStorage.isExpired(expiration: envelope.expiration, currentDate: currentDate) {
            return nil
        } else {
            return decoded
        }
    }
    
    private func string(withKey key: LocalStorageKey) -> String? {
        userDefaults.string(forKey: key.value)
    }
    
    private func bool(withKey key: LocalStorageKey) -> Bool {
        userDefaults.bool(forKey: key.value)
    }
    
    private static func isExpired(expiration: Date?, currentDate: Date) -> Bool {
        if let expiration = expiration {
            if expiration.timeIntervalSinceReferenceDate > currentDate.timeIntervalSinceReferenceDate {
                // expiration is later
                return false
            } else {
                // expired
                return true
            }
        } else {
            // no expiration
            return false
        }
    }
    
    private func save<T: Codable>(codable: T?, withKey key: LocalStorageKey, andExpiration expiration: Date? = nil) throws {
        if let value = codable {
            let data = try JSONEncoder().encode(value)
            try save(data: data, withKey: key, andExpiration: expiration)
        } else {
            try save(data: nil, withKey: key, andExpiration: expiration)
        }
    }
    
    private func save(dict: [AnyHashable: Any]?, withKey key: LocalStorageKey, andExpiration expiration: Date? = nil) throws {
        if let value = dict {
            if JSONSerialization.isValidJSONObject(value) {
                let data = try JSONSerialization.data(withJSONObject: value, options: [])
                try save(data: data, withKey: key, andExpiration: expiration)
            }
        } else {
            try save(data: nil, withKey: key, andExpiration: expiration)
        }
    }
    
    private func save(string: String?, withKey key: LocalStorageKey) {
        userDefaults.set(string, forKey: key.value)
    }
    
    private func save(bool: Bool, withKey key: LocalStorageKey) {
        userDefaults.set(bool, forKey: key.value)
    }
    
    private func save(data: Data?, withKey key: LocalStorageKey, andExpiration expiration: Date?) throws {
        guard let data = data else {
            userDefaults.removeObject(forKey: key.value)
            return
        }
        
        let envelope = Envelope(payload: data, expiration: expiration)
        let encodedEnvelope = try JSONEncoder().encode(envelope)
        userDefaults.set(encodedEnvelope, forKey: key.value)
    }
    
    private struct LocalStorageKey {
        let value: String
        
        private init(value: String) {
            self.value = value
        }
        
        static let payload = LocalStorageKey(value: Const.UserDefault.payloadKey)
        static let attributionInfo = LocalStorageKey(value: Const.UserDefault.attributionInfoKey)
        static let email = LocalStorageKey(value: Const.UserDefault.emailKey)
        static let userId = LocalStorageKey(value: Const.UserDefault.userIdKey)
        static let authToken = LocalStorageKey(value: Const.UserDefault.authTokenKey)
        static let ddlChecked = LocalStorageKey(value: Const.UserDefault.ddlChecked)
        static let deviceId = LocalStorageKey(value: Const.UserDefault.deviceId)
        static let sdkVersion = LocalStorageKey(value: Const.UserDefault.sdkVersion)
        static let offlineMode = LocalStorageKey(value: Const.UserDefault.offlineMode)
        static let offlineModeBeta = LocalStorageKey(value: Const.UserDefault.offlineModeBeta)
    }
    
    private struct Envelope: Codable {
        let payload: Data
        let expiration: Date?
    }
}
