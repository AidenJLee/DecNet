import Foundation
import DecNet

// MARK: - Models

struct UserList: Codable {
    let users: [User]
}

struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

struct Post: Codable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

// MARK: - Requests within Models

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

extension Post {
    struct GetUserPostsRequest: DecRequest {
        typealias ReturnType = [Post]
        
        let path: String
        let method: HTTPMethod = .get
        
        init(userId: Int) {
            self.path = "/users/\(userId)/posts"
        }
    }
    
    struct CreateRequest: DecRequest {
        typealias ReturnType = Post
        
        let path = "/posts"
        let method: HTTPMethod = .post
        let body: Params?
        
        init(title: String, body: String, userId: Int) {
            self.body = [
                "title": title,
                "body": body,
                "userId": userId
            ]
        }
    }
}

// MARK: - Usage Example

@available(iOS 15, macOS 10.15, *)
func fetchData() async {
    // DConnectKit 대신 DecNet 사용 (이름만 다르고 기능은 동일하다고 가정)
    let connectKit = DecNet(baseURL: "https://jsonplaceholder.typicode.com")
    
    do {
        // 사용자 정보 가져오기
        let user = try await connectKit.request(User.Request(userId: 1))
        print("User: \(user)")
        
        // 사용자의 게시글 가져오기
        let posts = try await connectKit.request(Post.GetUserPostsRequest(userId: user.id))
        print("Posts: \(posts)")
        
        // 새 게시글 생성
        let newPost = try await connectKit.request(
            Post.CreateRequest(title: "New Post", body: "This is a new post", userId: user.id)
        )
        print("Created Post: \(newPost)")
    } catch {
        print("Error: \(error)")
    }
}
