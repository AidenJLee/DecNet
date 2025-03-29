# DecNet

DecNet은 Swift에서 사용할 수 있는 강력하고 유연한 네트워크 라이브러리입니다. 모던 Swift 문법과 최신 비동기 프로그래밍 패턴을 활용하여 안전하고 효율적인 네트워크 통신을 구현할 수 있습니다.

## 주요 기능

- ✨ 모던한 async/await 기반 API
- 🔄 자동 재시도 정책
- 📝 상세한 로깅
- 🎯 타입 세이프한 요청/응답 처리
- 📦 멀티파트 요청 지원

## 설치 방법

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/DecNet.git", from: "1.0.0")
]
```

## 기본 사용법

### 네트워크 클라이언트 설정

```swift
let decNet = DecNet(
    baseURL: "https://api.example.com",
    logLevel: .debug,
    retryPolicy: .default
)
```

### 요청 정의

```swift
struct UserRequest: DecRequest {
    typealias ReturnType = User
    
    var path: String { "/users/\(userId)" }
    var method: HTTPMethod { .get }
    var headers: HTTPHeaders? {
        ["Authorization": "Bearer \(accessToken)"]
    }
    
    let userId: Int
    let accessToken: String
}

struct User: Codable {
    let id: Int
    let name: String
    let email: String
}
```

### 요청 실행

```swift
do {
    let user = try await decNet.request(UserRequest(
        userId: 1,
        accessToken: "your-access-token"
    ))
    print("User: \(user)")
} catch {
    print("Error: \(error)")
}
```

### 인증 처리

각 요청에서 필요한 인증 정보를 직접 처리할 수 있습니다. 이는 더 유연하고 명확한 인증 관리를 가능하게 합니다:

```swift
// 기본 인증 헤더를 포함하는 프로토콜 extension
extension DecRequest {
    func withBearerToken(_ token: String) -> HTTPHeaders {
        var headers = self.headers ?? [:]
        headers["Authorization"] = "Bearer \(token)"
        return headers
    }
}

// 인증이 필요한 요청 예시
struct AuthenticatedRequest: DecRequest {
    typealias ReturnType = Response
    
    var path: String { "/protected-resource" }
    var headers: HTTPHeaders? {
        withBearerToken(accessToken)
    }
    
    let accessToken: String
}

// 커스텀 인증 헤더를 사용하는 요청 예시
struct CustomAuthRequest: DecRequest {
    typealias ReturnType = Response
    
    var path: String { "/api/resource" }
    var headers: HTTPHeaders? {
        ["X-Custom-Auth": apiKey]
    }
    
    let apiKey: String
}
```

## 재시도 정책 설정

```swift
let retryPolicy = DecRetryPolicy(
    maxRetries: 3,
    baseDelay: 1.0,
    maxDelay: 10.0
) { error in
    // 재시도할 에러 조건 정의
    if case DecError.serverError = error { return true }
    return false
}
```

## 로깅 설정

```swift
let decNet = DecNet(
    baseURL: "https://api.example.com",
    logLevel: .debug  // .off, .info, .debug
)
```

## 멀티파트 요청

```swift
struct UploadRequest: DecRequest {
    typealias ReturnType = UploadResponse
    
    var path: String { "/upload" }
    var method: HTTPMethod { .post }
    var contentType: HTTPContentType { .multipart }
    var multipartData: [MultipartData]? {
        [MultipartData(
            name: "file",
            fileData: imageData,
            fileName: "image.jpg",
            mimeType: "image/jpeg"
        )]
    }
    
    let imageData: Data
}
```

## 에러 처리

DecNet은 명확한 에러 타입을 제공하여 다양한 네트워크 에러 상황을 처리할 수 있습니다:

```swift
do {
    let response = try await decNet.request(MyRequest())
} catch DecError.unauthorized {
    // 인증 에러 처리
} catch DecError.serverError {
    // 서버 에러 처리
} catch {
    // 기타 에러 처리
}
```

## 기여하기

버그 리포트, 기능 제안, 풀 리퀘스트 등 모든 기여를 환영합니다.

## 라이선스

MIT License
