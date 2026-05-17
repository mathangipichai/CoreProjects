import Foundation

/// REST API client with authentication, error handling, and retry logic
@MainActor
public final class APIClient: Sendable {
    public static let shared = APIClient()
    
    private let baseURL = "https://api.banking.example.com"
    private let session: URLSession
    private var requestRetryCount = 3
    
    private init() {
        self.session = URLSession.secureBankingSession
    }
    
    // MARK: - Public Methods
    
    /// Make a GET request
    public func get<T: Decodable>(
        endpoint: String,
        queryParameters: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        
        if let params = queryParameters {
            urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        
        return try await performRequest(request, responseType: responseType)
    }
    
    /// Make a POST request
    public func post<T: Decodable>(
        endpoint: String,
        body: Encodable,
        responseType: T.Type
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return try await performRequest(request, responseType: responseType)
    }
    
    /// Make a PUT request
    public func put<T: Decodable>(
        endpoint: String,
        body: Encodable,
        responseType: T.Type
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return try await performRequest(request, responseType: responseType)
    }
    
    /// Make a DELETE request
    public func delete<T: Decodable>(
        endpoint: String,
        responseType: T.Type
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return try await performRequest(request, responseType: responseType)
    }
    
    /// Make a DELETE request with no response
    public func deleteWithoutResponse(endpoint: String) async throws {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        try await performRequestWithoutResponse(request)
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        attempt: Int = 0
    ) async throws -> T {
        var modifiedRequest = request
        try await applyAuthenticationHeaders(&modifiedRequest)
        
        do {
            let (data, response) = try await session.data(for: modifiedRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(responseType, from: data)
                
            case 401:
                // Unauthorized - try to refresh token
                try await OAuthManager.shared.refreshTokens()
                
                if attempt < requestRetryCount {
                    return try await performRequest(request, responseType: responseType, attempt: attempt + 1)
                } else {
                    throw NetworkError.unauthorized
                }
                
            case 400...499:
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw NetworkError.clientError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse?.message ?? "Client error"
                )
                
            case 500...599:
                if attempt < requestRetryCount {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    return try await performRequest(request, responseType: responseType, attempt: attempt + 1)
                } else {
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                }
                
            default:
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            if attempt < requestRetryCount {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await performRequest(request, responseType: responseType, attempt: attempt + 1)
            } else {
                throw NetworkError.requestFailed(error.localizedDescription)
            }
        }
    }
    
    private func performRequestWithoutResponse(
        _ request: URLRequest,
        attempt: Int = 0
    ) async throws {
        var modifiedRequest = request
        try await applyAuthenticationHeaders(&modifiedRequest)
        
        do {
            let (_, response) = try await session.data(for: modifiedRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return
                
            case 401:
                try await OAuthManager.shared.refreshTokens()
                
                if attempt < requestRetryCount {
                    return try await performRequestWithoutResponse(request, attempt: attempt + 1)
                } else {
                    throw NetworkError.unauthorized
                }
                
            case 400...499:
                throw NetworkError.clientError(
                    statusCode: httpResponse.statusCode,
                    message: "Client error"
                )
                
            case 500...599:
                if attempt < requestRetryCount {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    return try await performRequestWithoutResponse(request, attempt: attempt + 1)
                } else {
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                }
                
            default:
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.requestFailed(error.localizedDescription)
        }
    }
    
    private func applyAuthenticationHeaders(_ request: inout URLRequest) async throws {
        let token = try await OAuthManager.shared.getAccessToken()
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("ios-banking/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
    }
}

// MARK: - API Models

struct ErrorResponse: Decodable {
    let code: String
    let message: String
    let details: [String: String]?
}

// MARK: - Network Error

public enum NetworkError: LocalizedError {
    case invalidResponse
    case unauthorized
    case clientError(statusCode: Int, message: String)
    case serverError(statusCode: Int)
    case unexpectedStatusCode(Int)
    case requestFailed(String)
    case decodingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized access"
        case .clientError(_, let message):
            return "Client error: \(message)"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        case .decodingError(let reason):
            return "Decoding error: \(reason)"
        }
    }
}
