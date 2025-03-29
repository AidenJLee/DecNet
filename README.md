아래는 DecNet에 대한 내용을 마크다운 형식으로 정리한 것입니다.

```markdown
# DecNet

DecNet은 Swift의 선언형 네트워크 라이브러리입니다. 간단하고 타입 안전한 API를 제공하며, async/await를 사용하여 현대적인 비동기 프로그래밍을 지원합니다.

## 특징
- 선언형 API
- 타입 안전성
- async/await 지원
- 자동 재시도
- 인증 관리
- 자세한 로깅
- 테스트 용이성

## 요구사항
- iOS 15.0+
- macOS 12.0+
- Swift 5.7+

## 설치

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/AidenJLee/DecNet.git", from: "1.0.0")
]
```

## 사용법

### 기본 사용
DecNet 인스턴스를 생성하고, `DecRequest` 프로토콜을 준수하는 요청을 정의하여 사용합니다.

```swift
import DecNet

// 1. DecNet 인스턴스 생성
let decNet = DecNet(baseURL: "https://api.example.com")

// 2. 요청 정의
struct GetUserRequest: DecRequest {
    typealias ReturnType = User
    let path = "/users/1"
}

// 3. 요청 실행
do {
    let user = try await decNet.request(GetUserRequest())
    print(user)
} catch {
    print(error)
}
```

### 모델의 extension으로 요청 정의
모델과 관련된 요청을 모델의 extension으로 정의하면 코드의 연관성이 높아지고 사용이 편리해집니다.

```swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

extension User {
    struct Request: DecRequest {
        typealias ReturnType = User
        let path: String
        let method: HTTPMethod = .get
        
        init(userId: Int) {
            self.path = "/users/\(userId)"
        }
    }
}

// 사용 예시
do {
    let user = try await decNet.request(User.Request(userId: 1))
    print(user)
} catch {
    print(error)
}
```

### POST 요청
POST 요청을 통해 데이터를 서버에 전송할 수 있습니다.

```swift
struct CreatePostRequest: DecRequest {
    typealias ReturnType = Post
    let path = "/posts"
    let method: HTTPMethod = .post
    let body: Params?
    
    init(title: String, body: String) {
        self.body = [
            "title": title,
            "body": body
        ]
    }
}
```

### 쿼리 파라미터 사용
GET 요청에 쿼리 파라미터를 추가하여 서버에 데이터를 전달할 수 있습니다.

```swift
struct SearchPostsRequest: DecRequest {
    typealias ReturnType = [Post]
    let path = "/posts"
    let method: HTTPMethod = .get
    let queryParams: HTTPParams?
    
    init(userId: Int) {
        self.queryParams = ["userId": userId]
    }
}
```

### 멀티파트 데이터 사용
파일 업로드와 같은 멀티파트 요청을 지원합니다.

```swift
struct UploadImageRequest: DecRequest {
    typealias ReturnType = UploadResponse
    let path = "/upload"
    let method: HTTPMethod = .post
    let multipartData: [MultipartData]?
    
    init(imageData: Data, fileName: String) {
        self.multipartData = [
            MultipartData(name: "image", fileData: imageData, fileName: fileName, mimeType: "image/jpeg")
        ]
    }
}
```

### 인증 사용
인증이 필요한 요청에 토큰을 자동으로 추가할 수 있습니다.

```swift
// 인증 토큰 설정
decNet.authManager.setToken("your-token")

// 인증이 필요한 요청
struct ProtectedRequest: DecRequest {
    typealias ReturnType = ProtectedData
    let path = "/protected"
    var requiresAuth = true
}
```

### 인증이 필요 없는 요청
`requiresAuth`를 false로 설정하여 인증을 사용하지 않는 요청을 정의할 수 있습니다.

```swift
struct PublicDataRequest: DecRequest {
    typealias ReturnType = PublicData
    let path = "/public"
    var requiresAuth = false
}
```

### 재시도 정책 설정
요청 실패 시 자동으로 재시도할 수 있는 정책을 커스터마이징할 수 있습니다.

```swift
let retryPolicy = DecRetryPolicy(
    maxRetries: 3,
    baseDelay: 1.0,
    maxDelay: 10.0
)

let decNet = DecNet(
    baseURL: "https://api.example.com",
    retryPolicy: retryPolicy
)
```

### 로깅 레벨 설정
로깅 레벨을 설정하여 디버깅 정보를 조절할 수 있습니다.

```swift
let decNet = DecNet(
    baseURL: "https://api.example.com",
    logLevel: .debug
)

// .off: 로깅 비활성화
// .info: 기본 로깅
// .debug: 상세 로깅 (cURL 명령어 포함)
```

## 예제

더 자세한 예제는 [Examples](Examples) 디렉토리를 참조하세요.

## 라이선스

DecNet은 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
