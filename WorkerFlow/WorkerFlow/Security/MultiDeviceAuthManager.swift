import Foundation

/// Manages multi-device authentication, device registration, and trust management
@Observable @MainActor
public final class MultiDeviceAuthManager {
    
    public private(set) var registeredDevices: [Device] = []
    public private(set) var currentDeviceId: String?
    public private(set) var isVerifyingDevice = false
    public private(set) var verificationError: DeviceError?
    
    public static let shared = MultiDeviceAuthManager()
    
    private let apiClient = APIClient.shared
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Register current device for the first time
    public func registerDevice(_ device: Device) async throws {
        isVerifyingDevice = true
        defer { isVerifyingDevice = false }
        
        do {
            // Store device ID locally
            try keychainService.storeUserID(device.id)
            currentDeviceId = device.id
            
            // In production, call API to register device
            // let response: DeviceRegistrationResponse = try await apiClient.post(
            //     endpoint: "/devices/register",
            //     body: device,
            //     responseType: DeviceRegistrationResponse.self
            // )
            
            registeredDevices.append(device)
        } catch {
            verificationError = DeviceError.registrationFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Verify device with OTP sent to registered email
    public func verifyDeviceWithOTP(_ otp: String, deviceId: String) async throws {
        isVerifyingDevice = true
        defer { isVerifyingDevice = false }
        
        guard let index = registeredDevices.firstIndex(where: { $0.id == deviceId }) else {
            throw DeviceError.deviceNotFound
        }
        
        do {
            // Validate OTP format
            guard otp.count == 6 && otp.allSatisfy({ $0.isNumber }) else {
                throw DeviceError.invalidOTP
            }
            
            // In production, call API to verify OTP
            // let response: DeviceVerificationResponse = try await apiClient.post(
            //     endpoint: "/devices/\(deviceId)/verify-otp",
            //     body: ["otp": otp],
            //     responseType: DeviceVerificationResponse.self
            // )
            
            // Mark device as verified
            var verifiedDevice = registeredDevices[index]
            verifiedDevice.isVerified = true
            registeredDevices[index] = verifiedDevice
            
            verificationError = nil
        } catch {
            verificationError = error as? DeviceError ?? .verificationFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Verify device with biometric
    public func verifyDeviceWithBiometric(deviceId: String) async throws {
        isVerifyingDevice = true
        defer { isVerifyingDevice = false }
        
        guard let index = registeredDevices.firstIndex(where: { $0.id == deviceId }) else {
            throw DeviceError.deviceNotFound
        }
        
        do {
            let biometricService = BiometricAuthService.shared
            let success = await biometricService.authenticateWithBiometric(
                reason: "Verify this device for banking access"
            )
            
            guard success else {
                throw DeviceError.biometricVerificationFailed
            }
            
            // Mark device as verified
            var verifiedDevice = registeredDevices[index]
            verifiedDevice.isVerified = true
            verifiedDevice.trustToken = UUID().uuidString
            registeredDevices[index] = verifiedDevice
            
            verificationError = nil
        } catch {
            verificationError = error as? DeviceError ?? .verificationFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Mark device as trusted (remember this device)
    public func markDeviceAsTrusted(deviceId: String, trustToken: String? = nil) async throws {
        guard let index = registeredDevices.firstIndex(where: { $0.id == deviceId }) else {
            throw DeviceError.deviceNotFound
        }
        
        do {
            var device = registeredDevices[index]
            device.trustToken = trustToken ?? UUID().uuidString
            registeredDevices[index] = device
            
            // In production, call API to store trust token
            // try await apiClient.post(
            //     endpoint: "/devices/\(deviceId)/trust",
            //     body: ["trustToken": device.trustToken],
            //     responseType: EmptyResponse.self
            // )
        } catch {
            verificationError = DeviceError.trustManagementFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Revoke trust for a device
    public func revokeTrust(deviceId: String) async throws {
        guard let index = registeredDevices.firstIndex(where: { $0.id == deviceId }) else {
            throw DeviceError.deviceNotFound
        }
        
        do {
            var device = registeredDevices[index]
            device.trustToken = nil
            registeredDevices[index] = device
            
            // In production, call API to revoke trust
            // try await apiClient.delete(
            //     endpoint: "/devices/\(deviceId)/trust",
            //     responseType: EmptyResponse.self
            // )
        } catch {
            verificationError = DeviceError.trustManagementFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Fetch all registered devices
    public func fetchRegisteredDevices() async throws {
        do {
            // In production, call API to fetch devices
            // registeredDevices = try await apiClient.get(
            //     endpoint: "/devices",
            //     responseType: [Device].self
            // )
            
            verificationError = nil
        } catch {
            verificationError = DeviceError.fetchFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Remove a device
    public func removeDevice(deviceId: String) async throws {
        guard registeredDevices.contains(where: { $0.id == deviceId }) else {
            throw DeviceError.deviceNotFound
        }
        
        do {
            registeredDevices.removeAll { $0.id == deviceId }
            
            // In production, call API to remove device
            // try await apiClient.delete(
            //     endpoint: "/devices/\(deviceId)",
            //     responseType: EmptyResponse.self
            // )
        } catch {
            verificationError = DeviceError.removalFailed(error.localizedDescription)
            throw verificationError!
        }
    }
    
    /// Check if device is trusted
    public func isDeviceTrusted(_ deviceId: String) -> Bool {
        return registeredDevices.contains { device in
            device.id == deviceId && device.trustToken != nil && device.isVerified
        }
    }
    
    /// Get trusted devices count
    public func getTrustedDevicesCount() -> Int {
        return registeredDevices.filter { $0.trustToken != nil && $0.isVerified }.count
    }
}

// MARK: - Device Error

public enum DeviceError: LocalizedError {
    case deviceNotFound
    case registrationFailed(String)
    case verificationFailed(String)
    case invalidOTP
    case biometricVerificationFailed
    case trustManagementFailed(String)
    case fetchFailed(String)
    case removalFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Device not found"
        case .registrationFailed(let reason):
            return "Device registration failed: \(reason)"
        case .verificationFailed(let reason):
            return "Device verification failed: \(reason)"
        case .invalidOTP:
            return "Invalid OTP format"
        case .biometricVerificationFailed:
            return "Biometric verification failed"
        case .trustManagementFailed(let reason):
            return "Trust management failed: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch devices: \(reason)"
        case .removalFailed(let reason):
            return "Failed to remove device: \(reason)"
        }
    }
}
