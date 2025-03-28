import XCTest
@testable import DeclarativeConnectKit

final class DecNetTests: XCTestCase {
    var decNet: DecNet!
    var mockURLSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        decNet = DecNet(baseURL: "https://api.example.com")
    }
    
    override func tearDown() {
        decNet = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    func testSuccessfulRequest() async throws {
        // Given
        let expectedUser = User(id: 1, name: "John Doe")
        let mockData = try JSONEncoder().encode(expectedUser)
        let mockResponse = HTTPURLResponse(url: URL(string: "https://api.example.com/users/1")!,
                                         statusCode: 200,
                                         httpVersion: nil,
                                         headerFields: nil)!
        
        mockURLSession.mockData = mockData
        mockURLSession.mockResponse = mockResponse
        
        let request = GetUserRequest()
        
        // When
        let user = try await decNet.request(request)
        
        // Then
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.name, expectedUser.name)
    }
    
    func testFailedRequest() async {
        // Given
        let mockResponse = HTTPURLResponse(url: URL(string: "https://api.example.com/users/1")!,
                                         statusCode: 404,
                                         httpVersion: nil,
                                         headerFields: nil)!
        
        mockURLSession.mockResponse = mockResponse
        
        let request = GetUserRequest()
        
        // When/Then
        do {
            _ = try await decNet.request(request)
            XCTFail("Expected error but got success")
        } catch let error as DecError {
            XCTAssertEqual(error, .notFound(nil))
        } catch {
            XCTFail("Expected DecError but got \(error)")
        }
    }
    
    func testRetryPolicy() async {
        // Given
        let mockResponse = HTTPURLResponse(url: URL(string: "https://api.example.com/users/1")!,
                                         statusCode: 503,
                                         httpVersion: nil,
                                         headerFields: nil)!
        
        mockURLSession.mockResponse = mockResponse
        mockURLSession.shouldFail = true
        
        let request = GetUserRequest()
        
        // When/Then
        do {
            _ = try await decNet.request(request)
            XCTFail("Expected error but got success")
        } catch let error as DecError {
            XCTAssertEqual(error, .serviceUnavailable(nil))
        } catch {
            XCTFail("Expected DecError but got \(error)")
        }
    }
}

// MARK: - Mock Types

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var shouldFail = false
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldFail {
            throw NSError(domain: "com.example", code: -1)
        }
        
        guard let data = mockData, let response = mockResponse else {
            throw DecError.unknown
        }
        
        return (data, response)
    }
}

struct User: Codable, Equatable {
    let id: Int
    let name: String
}

struct GetUserRequest: DecRequest {
    typealias ReturnType = User
    let path = "/users/1"
    var requiresAuth = true
} 