//  Created by AidenJLee on 2023/03/25.
//

import Foundation

public enum DecLogLevel {
	case off
	case info
	case debug
}

@available(iOS 15, macOS 10.15, *)
public struct DecNet {
	public var baseURL: String
	public var dispatcher: DecDispatcher
	public var retryPolicy: DecRetryPolicy
	
	private let logger: DecLogger
	
	public init(
		baseURL: String,
		logLevel: DecLogLevel = .debug,
		retryPolicy: DecRetryPolicy = .default
	) {
		self.baseURL = baseURL
		self.logger = DecLogger(logLevel: logLevel)
		self.dispatcher = DecDispatcher(logger: logger)
		self.retryPolicy = retryPolicy
	}
	
	public func request<Request: DecRequest>(_ request: Request) async throws -> Request.ReturnType {
		guard var urlRequest: URLRequest = request.asURLRequest(baseURL: baseURL) else {
			throw DecError.invalidRequest
		}
		
		logger.log(request: urlRequest)
		
		return try await withRetry(policy: retryPolicy) {
			try await dispatcher.request(urlRequest: urlRequest, decoder: request.decoder)
		}
	}
	
	private func withRetry<T>(policy: DecRetryPolicy, operation: @escaping () async throws -> T) async throws -> T {
		var lastError: Error?
		
		for attempt in 0...policy.maxRetries {
			do {
				return try await operation()
			} catch {
				lastError = error
				
				// 재시도 가능한 에러인지 확인
				guard policy.shouldRetry(error) else { throw error }
				
				// 마지막 시도가 아니면 대기 후 재시도
				if attempt < policy.maxRetries {
					let delay = policy.delay(for: attempt)
					try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
					continue
				}
			}
		}
		
		throw lastError ?? DecError.unknown
	}
}

public struct DecRetryPolicy {
	public let maxRetries: Int
	public let baseDelay: TimeInterval
	public let maxDelay: TimeInterval
	public let shouldRetry: (Error) -> Bool
	
	public static let `default` = DecRetryPolicy(
		maxRetries: 3,
		baseDelay: 1.0,
		maxDelay: 10.0
	)
	
	public init(
		maxRetries: Int,
		baseDelay: TimeInterval,
		maxDelay: TimeInterval,
		shouldRetry: ((Error) -> Bool)? = nil
	) {
		self.maxRetries = maxRetries
		self.baseDelay = baseDelay
		self.maxDelay = maxDelay
		self.shouldRetry = shouldRetry ?? { error in
			if let decError = error as? DecError {
				switch decError {
				case .serverError, .serviceUnavailable, .networkError:
					return true
				default:
					return false
				}
			}
			return false
		}
	}
	
	func delay(for attempt: Int) -> TimeInterval {
		let delay = baseDelay * pow(2.0, Double(attempt))
		return min(delay, maxDelay)
	}
}

public enum DecError: LocalizedError, Equatable {
	case invalidRequest
	case badRequest(Data?)
	case unauthorized(Data?)
	case forbidden(Data?)
	case notFound(Data?)
	case clientError(Int, Data?)
	case serverError(Data?)
	case serviceUnavailable(Data?)
	case decodingFailed(String)
	case networkError(Error)
	case unknown
	
	public var errorDescription: String? {
		switch self {
		case .invalidRequest: return "Invalid request"
		case .badRequest: return "Bad request"
		case .unauthorized: return "Unauthorized"
		case .forbidden: return "Forbidden"
		case .notFound: return "Not found"
		case .clientError(let code, _): return "Client error: \(code)"
		case .serverError: return "Server error"
		case .serviceUnavailable: return "Service unavailable"
		case .decodingFailed(let message): return "Decoding failed: \(message)"
		case .networkError(let error): return "Network error: \(error.localizedDescription)"
		case .unknown: return "Unknown error"
		}
	}
	
	public static func == (lhs: DecError, rhs: DecError) -> Bool {
		switch (lhs, rhs) {
		case (.invalidRequest, .invalidRequest),
			 (.unknown, .unknown):
			return true
		case (.badRequest, .badRequest),
			 (.unauthorized, .unauthorized),
			 (.forbidden, .forbidden),
			 (.notFound, .notFound),
			 (.serverError, .serverError),
			 (.serviceUnavailable, .serviceUnavailable):
			return true
		case (.clientError(let code1, _), .clientError(let code2, _)):
			return code1 == code2
		case (.decodingFailed(let msg1), .decodingFailed(let msg2)):
			return msg1 == msg2
		case (.networkError(let err1), .networkError(let err2)):
			return err1.localizedDescription == err2.localizedDescription
		default:
			return false
		}
	}
}

public protocol DecRequest {
	associatedtype ReturnType: Codable
	var path: String { get }
	var method: HTTPMethod { get }
	var contentType: HTTPContentType { get }
	var queryParams: HTTPParams? { get }
	var body: Params? { get }
	var headers: HTTPHeaders? { get }
	var multipartData: [MultipartData]? { get }
	var decoder: JSONDecoder? { get }
	var requiresAuth: Bool { get }
}

public extension DecRequest {
	var method: HTTPMethod { .get }
	var contentType: HTTPContentType { .json }
	var queryParams: HTTPParams? { nil }
	var body: Params? { nil }
	var headers: HTTPHeaders? { nil }
	var multipartData: [MultipartData]? { nil }
	var decoder: JSONDecoder? { JSONDecoder() }
	var requiresAuth: Bool { true }
}

// Encodable 프로토콜을 확장하여 asDictionary라는 변수를 추가합니다.
public extension Encodable {
	var asDictionary: [String: Any] {
		// JSONEncoder를 사용하여 인코딩합니다.
		guard let data: Data = try? JSONEncoder().encode(self) else { return [:] }
		// JSONSerialization을 사용하여 JSON 객체로 변환합니다.
		guard let dictionary: [String : Any] = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else { return [:] }
		return dictionary
	}
	
	func asParams() -> Params {
		guard let data = try? JSONEncoder().encode(self),
			  let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
			return [:]
		}
		
		return dictionary.mapValues { value -> CustomStringConvertible in
			if let convertible = value as? CustomStringConvertible {
				return convertible
			} else {
				return "\(value)" // Convert to string if not already convertible
			}
		}
	}
}

// Decodable 프로토콜을 확장하여 fromDictionary라는 함수를 추가합니다.
public extension Decodable {
	static func fromDictionary(from json: Any) -> Self?  {
		// JSONSerialization을 사용하여 JSON 데이터로 변환합니다.
		guard let jsonData: Data = try? JSONSerialization.data(withJSONObject: json, options: []) else {
			return nil
		}
		// JSONDecoder를 사용하여 디코딩합니다.
		return try? JSONDecoder().decode(Self.self, from: jsonData)
	}
}

@available(iOS 15, macOS 10.15, *)
public struct DecDispatcher {
	private let urlSession: URLSession
	private let logger: DecLogger
	
	init(logger: DecLogger) {
		self.logger = logger
		self.urlSession = .shared
	}
	
	func request<ReturnType: Codable>(urlRequest: URLRequest, decoder: JSONDecoder?) async throws -> ReturnType {
		let decoder = decoder ?? JSONDecoder()
		
		let (data, urlResponse) = try await urlSession.data(for: urlRequest)
		
		guard let httpResponse = urlResponse as? HTTPURLResponse else {
			throw NetworkError.unknown
		}
		
		if !(200...299).contains(httpResponse.statusCode) {
			throw httpError(httpResponse.statusCode, data: data)
		}
		
		logger.log(response: urlResponse, data: data)
		
		do {
			return try decoder.decode(ReturnType.self, from: data)
		} catch {
			throw NetworkError.decodingFailed(error.localizedDescription)
		}
	}
	
	private func httpError(_ statusCode: Int, data: Data?) -> NetworkError {
		switch statusCode {
		case 400: return .badRequest(data)
		case 401: return .unauthorized(data)
		case 403: return .forbidden(data)
		case 404: return .notFound(data)
		case 402, 405...499: return .clientError(statusCode, data)
		case 500: return .serverError(data)
		case 503: return .serviceUnavailable(data)
		case 501, 502, 504...599: return .serverError(data)
		default: return .unknown
		}
	}
}

public enum NetworkError: LocalizedError, Equatable {
	case invalidRequest
	case badRequest(Data?)
	case unauthorized(Data?)
	case forbidden(Data?)
	case notFound(Data?)
	case clientError(Int, Data?)
	case serverError(Data?)
	case serviceUnavailable(Data?)
	case decodingFailed(String)
	case unknown
	
	public var errorDescription: String? {
		switch self {
		case .invalidRequest: return "Invalid request"
		case .badRequest: return "Bad request"
		case .unauthorized: return "Unauthorized"
		case .forbidden: return "Forbidden"
		case .notFound: return "Not found"
		case .clientError(let code, _): return "Client error: \(code)"
		case .serverError: return "Server error"
		case .serviceUnavailable: return "Service unavailable"
		case .decodingFailed(let message): return "Decoding failed: \(message)"
		case .unknown: return "Unknown error"
		}
	}
}

// Utility Methods
extension DecRequest {
	func asURLRequest(baseURL: String) -> URLRequest? {
		guard var urlComponents = URLComponents(string: baseURL) else { return nil } // baseURL을 기반으로 URLComponents 생성
		urlComponents.path = "\(urlComponents.path)\(path)" // API 경로 추가
		urlComponents.queryItems = queryItemsFrom(params: queryParams) // Query Parameter 추가
		guard let finalURL = urlComponents.url else { return nil } // URLComponents를 기반으로 URL 생성
		
		let boundary = UUID().uuidString // Multipart Data를 위한 boundary 생성
		
		var request = URLRequest(url: finalURL) // URLRequest 생성
		let defaultHeaders: HTTPHeaders = [
			HTTPHeaderField.contentType.rawValue: "\(contentType.rawValue); boundary=\(boundary)" // Content-Type과 boundary 추가
		]
		request.allHTTPHeaderFields = defaultHeaders.merging(headers ?? [:], uniquingKeysWith: { (current, _) in current }) // HTTP Header 추가
		request.httpMethod = method.rawValue // HTTP 메소드 설정
		request.httpBody = requestBodyFrom(params: body, boundary: boundary) // Request Body 설정
		return request
	}
	
	private func queryItemsFrom(params: HTTPParams?) -> [URLQueryItem]? {
		guard let params = params else { return nil } // Query Parameter가 없는 경우 nil
		return params.map {
			URLQueryItem(name: $0.key, value: $0.value as? String) // Query Parameter 추가
		}
	}
	
	private func requestBodyFrom(params: Params?, boundary: String) -> Data? {
		guard let params = params else { return nil } // Request Body가 없는 경우 nil
		switch contentType {
		case .urlEncoded:
			return params.asPercentEncodedString().data(using: .utf8) // URL Encoded 형식으로 Request Body 생성
		case .json:
			return try? JSONSerialization.data(withJSONObject: params, options: []) // JSON 형식으로 Request Body 생성
		case .multipart:
			return buildMultipartHttpBody(params: body ?? Params(), multiparts: multipartData ?? [], boundary: boundary) // Multipart Data를 포함한 Request Body 생성
		}
	}
	
	private func buildMultipartHttpBody(params: Params, multiparts: [MultipartData], boundary: String) -> Data {
		
		let boundaryPrefix = "--\(boundary)\r\n".data(using: .utf8)! // Multipart Data의 시작 boundary
		let boundarySuffix = "\r\n--\(boundary)--\r\n".data(using: .utf8)! // Multipart Data의 끝 boundary
		
		var body = Data()
		body.append(boundaryPrefix)
		body.append(params.buildHttpBodyPart(boundary: boundary)) // Request Body 추가
		body.append(multiparts
			.map { (multipart: MultipartData) -> Data in
				return multipart.buildHttpBodyPart(boundary: boundary) // Multipart Data 추가
			}
			.reduce(Data.init(), +))
		body.append(boundarySuffix)
		return body as Data // Multipart Data를 포함한 Request Body 반환
	}
	
}

// Params 타입은 [String: CustomStringConvertible] 타입의 typealias로 정의됩니다.
public typealias Params = [String: CustomStringConvertible]

// HTTPParams 타입은 [String: Any] 타입의 typealias로 정의됩니다.
public typealias HTTPParams = [String: Any]

// HTTPHeaders 타입은 [String: String] 타입의 typealias로 정의됩니다.
public typealias HTTPHeaders = [String: String]

// HTTPContentType 열거형은 String rawValue를 가지며, 각 케이스는 HTTP 요청의 Content-Type을 나타냅니다.
public enum HTTPContentType: String {
	case json = "application/json"
	case urlEncoded = "application/x-www-form-urlencoded"
	case multipart = "multipart/form-data"
}

// HTTPHeaderField 열거형은 String rawValue를 가지며, 각 케이스는 HTTP 요청의 헤더 필드를 나타냅니다.
public enum HTTPHeaderField: String {
	case authentication = "Authorization"
	case contentType = "Content-Type"
	case acceptType = "Accept"
	case authToken = "X-AUTH-TOKEN"
	case acceptEncoding = "Accept-Encoding"
}

// HTTPMethod 구조체는 String rawValue를 가지며, HTTP 요청의 메소드를 나타냅니다.
public struct HTTPMethod: RawRepresentable, Equatable, Hashable {
	
	public static let get = HTTPMethod(rawValue: "GET")         // `GET` 메소드.
	public static let post = HTTPMethod(rawValue: "POST")       // `POST` 메소드.
	public static let put = HTTPMethod(rawValue: "PUT")         // `PUT` 메소드.
	public static let delete = HTTPMethod(rawValue: "DELETE")   // `DELETE` 메소드.
	
	public let rawValue: String
	
	public init(rawValue: String) {
		self.rawValue = rawValue
	}
}

// HttpBodyConvertible 프로토콜은 HTTP 요청의 Body를 생성하는 메소드를 가지고 있습니다.
public protocol HttpBodyConvertible {
	func buildHttpBodyPart(boundary: String) -> Data
}

// MultipartData 구조체는 HTTP 요청의 Body에 포함될 멀티파트 데이터를 나타냅니다.
public struct MultipartData {
	let name: String
	let fileData: Data
	let fileName: String
	let mimeType: String
	
	public init(name: String, fileData: Data, fileName: String, mimeType: String) {
		self.name = name
		self.fileData = fileData
		self.fileName = fileName
		self.mimeType = mimeType
	}
}

// HttpBodyConvertible 프로토콜을 채택한 MultipartData 구조체는 buildHttpBodyPart 메소드를 구현합니다.
extension MultipartData: HttpBodyConvertible {
	public func buildHttpBodyPart(boundary: String) -> Data {
		let httpBody = NSMutableData()
		httpBody.appendString("--\(boundary)\r\n")
		httpBody.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
		httpBody.appendString("Content-Type: \(mimeType)\r\n\r\n")
		httpBody.append(fileData)
		httpBody.appendString("\r\n")
		return httpBody as Data
	}
}

// Params 타입에 asPercentEncodedString 메소드를 추가합니다.
extension Params {
	public func asPercentEncodedString(parentKey: String? = nil) -> String {
		return self.map { key, value in
			var escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
			if let `parentKey` = parentKey {
				escapedKey = "\(parentKey)[\(escapedKey)]"
			}
			
			if let dict = value as? Params {
				return dict.asPercentEncodedString(parentKey: escapedKey)
			} else if let array = value as? [CustomStringConvertible] {
				return array.map { entry in
					let escapedValue = "\(entry)"
						.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
					return "\(escapedKey)[]=\(escapedValue)"
				}.joined(separator: "&")
			} else {
				let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
				return "\(escapedKey)=\(escapedValue)"
			}
		}
		.joined(separator: "&")
	}
}

// HttpBodyConvertible 프로토콜을 채택한 Params 타입은 buildHttpBodyPart 메소드를 구현합니다.
extension Params: HttpBodyConvertible {
	public func buildHttpBodyPart(boundary: String) -> Data {
		let httpBody = NSMutableData()
		forEach { (name, value) in
			httpBody.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
			httpBody.appendString("\(value)")
			httpBody.appendString("\r\n")
		}
		return httpBody as Data
	}
}

// URL 쿼리 문자열에 포함될 수 없는 문자를 인코딩하기 위한 CharacterSet을 정의합니다.
extension CharacterSet {
	static let urlQueryValueAllowed: CharacterSet = {
		let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
		let subDelimitersToEncode = "!$&'()*+,;="
		var allowed = CharacterSet.urlQueryAllowed
		allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
		return allowed
	}()
}

// NSMutableData에 appendString 메소드를 추가합니다.
internal extension NSMutableData {
	func appendString(_ string: String) {
		if let data = string.data(using: .utf8) {
			self.append(data)
		}
	}
}

public struct DecLogger {
	private let logLevel: DecLogLevel
	
	init(logLevel: DecLogLevel) {
		self.logLevel = logLevel
	}
	
	func log(request: URLRequest) {
		guard logLevel != .off else { return }
		
		if let method = request.httpMethod, let url = request.url {
			print("🌐 [Request] \(method) '\(url.absoluteString)'")
			logHeaders(request)
			logBody(request)
		}
		
		if logLevel == .debug {
			print(request.toCurlCommand())
		}
	}
	
	func log(response: URLResponse, data: Data) {
		guard logLevel != .off else { return }
		
		if let httpResponse = response as? HTTPURLResponse {
			logStatusCodeAndURL(httpResponse)
		}
		
		if logLevel == .debug {
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
				print("📥 [Response] Body: \(json)")
			} catch {
				print("📥 [Response] Error: \(error.localizedDescription)")
			}
		}
	}
	
	private func logHeaders(_ urlRequest: URLRequest) {
		if let allHTTPHeaderFields = urlRequest.allHTTPHeaderFields {
			print("Headers:")
			allHTTPHeaderFields.forEach { key, value in
				print("  \(key): \(value)")
			}
		}
	}
	
	private func logBody(_ urlRequest: URLRequest) {
		if let body = urlRequest.httpBody, let str = String(data: body, encoding: .utf8) {
			print("Body: \(str)")
		}
	}
	
	private func logStatusCodeAndURL(_ urlResponse: HTTPURLResponse) {
		if let url = urlResponse.url {
			print("📥 [Response] \(urlResponse.statusCode) '\(url.absoluteString)'")
		}
	}
}

extension URLRequest {
	public func toCurlCommand() -> String {
		guard let url: URL = url else { return "" }
		var command: [String] = [#"curl "\#(url.absoluteString)""#]
		
		if let httpMethod, httpMethod != "GET", httpMethod != "HEAD" {
			command.append("-X \(httpMethod)")
		}
		
		allHTTPHeaderFields?
			.filter { $0.key != "Cookie" }
			.forEach { key, value in
				command.append("-H '\(key): \(value)'")
			}
		
		if let data = httpBody, let body = String(data: data, encoding: .utf8) {
			command.append("-d '\(body)'")
		}
		
		return command.joined(separator: " \\\n  ")
	}
}
