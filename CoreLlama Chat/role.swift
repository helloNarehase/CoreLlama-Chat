//
//  role.swift
//  Don-Quixote
//
//  Created by 하늘 on 10/18/24.
//

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

////@Model
//final class Message {
//    @Attribute(.unique) var id = UUID()
//    var timestamp: Date
//    var mess: String
//    var role: Role
////    var markdown: Bool
//
//    init(timestamp: Date, mess: String, role: Role = .user) {
//        self.timestamp = timestamp
//        self.mess = mess
//        self.role = role
////        self.markdown = markdown
//    }
//}
