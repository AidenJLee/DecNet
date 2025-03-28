import Foundation
import DeclarativeConnectKit

// MARK: - Models

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

// MARK: - Requests

struct GetUserRequest: DecRequest {
    typealias ReturnType = User
    let path: String
    
    init(userId: Int) {
        self.path = "/users/\(userId)"
    }
}

struct GetUserPostsRequest: DecRequest {
    typealias ReturnType = [Post]
    let path: String
    
    init(userId: Int) {
        self.path = "/users/\(userId)/posts"
    }
}

struct CreatePostRequest: DecRequest {
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

// MARK: - Usage Example

@available(iOS 15, macOS 10.15, *)
class UserService {
    private let decNet: DecNet
    
    init(baseURL: String) {
        self.decNet = DecNet(
            baseURL: baseURL,
            logLevel: .debug,
            retryPolicy: .default,
            authManager: .default
        )
    }
    
    func getUser(id: Int) async throws -> User {
        return try await decNet.request(GetUserRequest(userId: id))
    }
    
    func getUserPosts(userId: Int) async throws -> [Post] {
        return try await decNet.request(GetUserPostsRequest(userId: userId))
    }
    
    func createPost(title: String, body: String, userId: Int) async throws -> Post {
        return try await decNet.request(CreatePostRequest(title: title, body: body, userId: userId))
    }
}

// MARK: - Example Usage

@available(iOS 15, macOS 10.15, *)
func example() async {
    let userService = UserService(baseURL: "https://jsonplaceholder.typicode.com")
    
    do {
        // Get user
        let user = try await userService.getUser(id: 1)
        print("User: \(user)")
        
        // Get user's posts
        let posts = try await userService.getUserPosts(userId: user.id)
        print("Posts: \(posts)")
        
        // Create new post
        let newPost = try await userService.createPost(
            title: "New Post",
            body: "This is a new post",
            userId: user.id
        )
        print("Created post: \(newPost)")
    } catch {
        print("Error: \(error)")
    }
} 