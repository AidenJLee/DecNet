# DecNet

DecNet은 Swift의 선언형 네트워크 라이브러리입니다. 간단하고 타입 안전한 API를 제공하며, async/await를 사용하여 현대적인 비동기 프로그래밍을 지원합니다.

## 특징

- 🎯 선언형 API
- 🔒 타입 안전성
- ⚡️ async/await 지원
- 🔄 자동 재시도
- 🔑 인증 관리
- 📝 자세한 로깅
- 🧪 테스트 용이성

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

### POST 요청

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

### 인증 사용

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

### 재시도 정책 설정

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

## 예제

더 자세한 예제는 [Examples](Examples) 디렉토리를 참조하세요.

## 라이선스

DecNet은 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
