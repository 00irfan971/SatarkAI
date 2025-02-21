//
//  ChatView.swift
//  PolicePro
//
//  Created by Irfan on 21/02/25.
//
import SwiftUI
import Combine
import Speech
import AVFoundation

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct LoadingDots: View {
    @State private var opacity1: Double = 0.3
    @State private var opacity2: Double = 0.3
    @State private var opacity3: Double = 0.3
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .opacity(opacity1)
                .animation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0), value: opacity1)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .opacity(opacity2)
                .animation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.2), value: opacity2)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .opacity(opacity3)
                .animation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.4), value: opacity3)
        }
        .onAppear {
            withAnimation {
                opacity1 = 1
                opacity2 = 1
                opacity3 = 1
            }
        }
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isRecording = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        requestSpeechAuthorization()
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self?.errorMessage = "Speech recognition was denied. Please enable it in Settings."
                case .restricted:
                    self?.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self?.errorMessage = "Speech recognition authorization is pending."
                @unknown default:
                    self?.errorMessage = "Unknown authorization status"
                }
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            do {
                try startRecording()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isRecording = false
            }
        }
    }
    
    private func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest,
              speechRecognizer?.isAvailable == true else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition unavailable"])
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    self.stopRecording()
                }
                return
            }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.inputText = result.bestTranscription.formattedString
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        try audioEngine.start()
        isRecording = true
    }
    
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        
        if !inputText.isEmpty {
            sendMessage()
        }
    }
    
    func sendMessage() {
        guard !inputText.trim().isEmpty else { return }
        
        let userMessage = Message(text: inputText, isUser: true)
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        
        isLoading = true
        fetchResponse(for: userInput)
    }
    
    private func fetchResponse(for text: String) {
        guard let url = URL(string: "https://satark-userside.onrender.com/user") else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        
        let requestBody: [String: Any] = ["question": text]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            self.errorMessage = "Failed to encode request"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self?.errorMessage = "Server error: Invalid response"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let answer = responseJSON["answer"] as? String {
                        self?.messages.append(Message(text: answer, isUser: false))
                    } else {
                        self?.errorMessage = "Invalid response format"
                    }
                } catch {
                    self?.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
import SwiftUI
import Combine
import Speech
import AVFoundation

// MARK: - Background Effects
struct CyberGridBackground: View {
    var body: some View {
        ZStack {
            // Animated gradient orbs
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(x: -100, y: -50)
                        .animation(Animation.easeInOut(duration: 4).repeatForever(), value: UUID())
                    
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width - 100, y: geometry.size.height/2)
                        .animation(Animation.easeInOut(duration: 4).repeatForever().delay(2), value: UUID())
                    
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width/2, y: geometry.size.height - 100)
                        .animation(Animation.easeInOut(duration: 4).repeatForever().delay(1), value: UUID())
                }
            }
            
            // Cyber grid
            GeometryReader { geometry in
                Path { path in
                    let horizontalSpacing: CGFloat = 40
                    let verticalSpacing: CGFloat = 40
                    
                    // Vertical lines
                    for x in stride(from: 0, through: geometry.size.width, by: horizontalSpacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    
                    // Horizontal lines
                    for y in stride(from: 0, through: geometry.size.height, by: verticalSpacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
    }
}



// MARK: - Voice Waveform
struct VoiceWaveform: View {
    @Binding var isRecording: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.cyan, Color.blue]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 3, height: 20)
                    .scaleEffect(y: isRecording ? 1 + Double(index) * 0.2 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: isRecording
                    )
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if message.isUser {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color("Theme")
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: message.isUser ? Color.cyan.opacity(0.3) : Color.clear, radius: 8)
                .frame(maxWidth: message.isUser ? 280 : 300, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
        .padding(message.isUser ? .leading : .trailing, 40)
    }
}

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Namespace private var bottomID
    
    var body: some View {
        ZStack {
            // Background
            Color("Theme").ignoresSafeArea()
            CyberGridBackground()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image("Logo")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            ).foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("SATARK AI")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.cyan.opacity(0.3))
                }
                .padding()
                .background(Color("Theme").opacity(0.98))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    LoadingDots()
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color("Theme"))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    Spacer()
                                }
                                .padding(.trailing, 40)
                            }
                            
                            Color.clear.frame(height: 1).id(bottomID)
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
                
                // Input Area
                VStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.cyan.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        if viewModel.isRecording {
                            VoiceWaveform(isRecording: $viewModel.isRecording)
                                .padding(.horizontal)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color("Theme"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        } else {
                            TextField("Type a message...", text: $viewModel.inputText)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color("Theme"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { viewModel.toggleRecording() }) {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(viewModel.isRecording ? .red : .cyan)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color("Theme"))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        if !viewModel.isRecording {
                            Button(action: viewModel.sendMessage) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: Color.cyan.opacity(0.3), radius: 8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color("Theme").opacity(0.98))
            }
        }
    }
}

#Preview {
    ChatView()
}
