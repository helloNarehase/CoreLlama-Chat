import Foundation
import SwiftData
/// Message Model!
struct Message: Identifiable, Equatable {
    let id = UUID()
    var timestamp: Date
    var mess: String
    var role: Role
}
enum Role: String, Codable {
    case user
    case model
    case target
}
