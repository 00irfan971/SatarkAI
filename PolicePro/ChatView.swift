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
        guard let url = URL(string: "https://satark-ai-f0xr.onrender.com/qa") else {
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
struct VoiceWaveform: View {
    @Binding var isRecording: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4, height: 20)
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

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        ZStack {
            Color("Theme").ignoresSafeArea()
            
            VStack {
                HStack {
                    Image("Logo").resizable().frame(width: 50, height: 50)
                    
                    Text("Satark AI")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Rectangle().frame(height: 2).foregroundColor(.gray)
                
                ScrollViewReader { scrollView in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                            }
                            
                            // Show loading indicator when waiting for response
                            if viewModel.isLoading {
                                HStack {
                                    LoadingDots()
                                        .padding()
                                        .background(Color("Theme"))
                                        .clipShape(RoundedRectangle(cornerRadius: 15))
                                    Spacer()
                                }
                                .padding(.trailing, 40)
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
                    if viewModel.isRecording {
                        VoiceWaveform(isRecording: $viewModel.isRecording)
                            .padding(.horizontal)
                    } else {
                        TextField("Type a message...", text: $viewModel.inputText)
                            .padding(12)
                            .foregroundColor(.black)
                            .background(Color(.white))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(viewModel.isRecording ? .red : .blue)
                    }
                    .padding(.horizontal, 4)
                    
                    if !viewModel.isRecording {
                        Button(action: viewModel.sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
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
                .background(message.isUser ? Color.blue.opacity(0.8) : Color("Theme"))
                .foregroundColor(message.isUser ? .white : .white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: message.isUser ? 250 : 300, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer() }
        }
        .padding(message.isUser ? .leading : .trailing, 40)
    }
}

#Preview {
    ChatView()
}
