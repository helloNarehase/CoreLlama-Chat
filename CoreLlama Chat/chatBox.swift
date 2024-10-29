//
//  chatBox.swift
//  Don_Quixote
//
//  Created by 하늘 on 10/21/24.
//

import SwiftUI

struct CoreChatBox: View {
    var msg: Message
    var delete: () -> Void
    
    var body: some View {
        HStack {
            if msg.role == .user {
                Spacer()
            } else {
                Text("🤖")
            }
            
            Text(msg.mess)
                .font(.system(size: 18, weight: msg.role == .user ? .medium : .bold))
                .padding(10)
                .background(
                    msg.role == .user ? Color.purple.opacity(0.05) : Color.gray.opacity(0.15)
                )
                .foregroundStyle(foregroundStyle(for: msg.role))
//                .padding(10)
//                .background(
//                    msg.role == .user ? Color.purple.opacity(0.05) : Color.gray.opacity(0.15)
//                )
                .cornerRadius(10)
                .contextMenu { // Context menu for copying text
                    Button(action: {
                        UIPasteboard.general.string = msg.mess
                    }) {
                        Text("Copy")
                    }
                    Button(action: {
                        delete()
                    }) {
                        Text("Delete")
                    }
                }
            
            if !(msg.role == .user) {
                Spacer()
            }
        }
        .padding(10)
    }
    
    
    private func foregroundStyle(for role: Role) -> AnyShapeStyle {
        // Use AnyShapeStyle to accommodate different types
        return role != .user ? AnyShapeStyle(LinearGradient(
            colors: [.purple, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )) : AnyShapeStyle(Color.gray)
    }
}
