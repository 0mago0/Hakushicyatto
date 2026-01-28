//
//  PairingSheet.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import SwiftUI

struct PairingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var chatService: ChatService
    
    @State private var roomId = ""
    @State private var userName = ""
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                Text("加入房間")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("你的房間 ID:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text(chatService.room)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button(action: {
                            UIPasteboard.general.string = chatService.room
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            chatService.createNewRoom()
                            roomId = chatService.room
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用者名稱:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("輸入你的名稱", text: $userName)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    
                    Text("對方的房間 ID:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("輸入對方的房間 ID", text: $roomId)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    Button(action: { isPresented = false }) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { Task { await joinRoom() } }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("加入")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(roomId.isEmpty || userName.isEmpty || isLoading)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding()
            .onAppear {
                // 預填目前使用者與房間
                roomId = chatService.room
                userName = chatService.userName
            }
        }
    }
    
    private func joinRoom() async {
        isLoading = true
        error = nil
        
        chatService.setUserName(userName)
        chatService.setRoom(roomId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            if chatService.isConnected {
                isPresented = false
            } else {
                error = "加入失敗，請檢查房間 ID"
            }
        }
    }
}

#Preview {
    PairingSheet(isPresented: .constant(true), chatService: ChatService())
}
