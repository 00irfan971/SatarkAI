//
//  ChatView.swift
//  PolicePro
//
//  Created by Irfan on 21/02/25.
//
import SwiftUI
import Combine

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    
    func sendMessage() {
        let userMessage = Message(text: inputText, isUser: true)
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        fetchResponse(for: userInput)
    }
    
    private func fetchResponse(for text: String) {
        guard let url = URL(string: "https://satark-ai-f0xr.onrender.com/qa") else { return }
        
        let requestBody: [String: Any] = [
            "question": text
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.messages.append(Message(text: "Error: Unable to get response", isUser: false))
                }
                return
            }
            
            do {
                if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let answer = responseJSON["answer"] as? String {
                    DispatchQueue.main.async {
                        self?.messages.append(Message(text: answer, isUser: false))
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.messages.append(Message(text: "Error: Invalid response format", isUser: false))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.messages.append(Message(text: "Error: Failed to decode response", isUser: false))
                }
            }
        }.resume()
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        
        ZStack{
            Color("Theme").ignoresSafeArea()
            
            VStack {
                Text("Satark AI").font(.system(size: 30,weight:.bold)).foregroundStyle(.white)
                
                ScrollViewReader { scrollView in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            scrollView.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                HStack {
                    TextField("Type a message...", text: $viewModel.inputText)
                        .padding(12)
                        .background(Color(.systemGray6)) // Subtle gray background
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1) // Light border
                        )
                    
                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 2) // Adds depth
                    }
                }
                .padding(.horizontal)
            }
            
            
        }
        
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            Text(message.text)
                .padding()
                .background(message.isUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                .foregroundColor(message.isUser ? .white : .black)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: 250, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer() }
        }
        .padding(message.isUser ? .leading : .trailing, 40)
    }
}

#Preview {
    ChatView()
}
