import Foundation

/// URLSessionDelegate that implements certificate pinning for secure API communication
@MainActor
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    
    public static let shared = CertificatePinningDelegate()
    
    // Pinned certificates (in production, load these from bundle resources)
    private var pinnedCertificates: Set<Data> = []
    
    private override init() {
        super.init()
        loadPinnedCertificates()
    }
    
    // MARK: - URLSessionDelegate Methods
    
    /// Evaluate server trust and certificate pinning
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // First, validate the certificate chain
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)
        
        guard status == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Then, perform certificate pinning
        if validateCertificatePinning(serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // MARK: - Private Methods
    
    /// Load pinned certificates from bundle
    private func loadPinnedCertificates() {
        // In production, load certificates from Bundle
        // Example:
        // if let path = Bundle.main.path(forResource: "api-banking", ofType: "cer") {
        //     if let certData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        //         pinnedCertificates.insert(certData)
        //     }
        // }
        
        // For now, we'll configure pinning via backend cert chain
        // This is a placeholder - in production, use public key pinning
    }
    
    /// Validate server certificate against pinned certificates
    private func validateCertificatePinning(_ serverTrust: SecTrust) -> Bool {
        // If no certificates are pinned, allow connection
        // (In production, always have pinned certificates)
        if pinnedCertificates.isEmpty {
            return performBasicCertificateValidation(serverTrust)
        }
        
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<certificateCount {
            guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
            
            if pinnedCertificates.contains(serverCertificateData) {
                return true
            }
        }
        
        return false
    }
    
    /// Perform basic certificate validation if no pinning is set
    private func performBasicCertificateValidation(_ serverTrust: SecTrust) -> Bool {
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)
        
        switch secResult {
        case .unspecified, .proceed:
            return status == errSecSuccess
        default:
            return false
        }
    }
    
    /// Add a certificate for pinning (for testing or dynamic cert loading)
    public func pinCertificate(_ certificate: SecCertificate) {
        let certificateData = SecCertificateCopyData(certificate) as Data
        pinnedCertificates.insert(certificateData)
    }
    
    /// Add certificate data for pinning
    public func pinCertificateData(_ data: Data) {
        pinnedCertificates.insert(data)
    }
    
    /// Clear all pinned certificates
    public func clearPinnedCertificates() {
        pinnedCertificates.removeAll()
    }
}

// MARK: - URLSession Extension

extension URLSession {
    /// Create a secure URLSession with certificate pinning enabled
    static var secureBankingSession: URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        
        return URLSession(
            configuration: config,
            delegate: CertificatePinningDelegate.shared,
            delegateQueue: .main
        )
    }
}
