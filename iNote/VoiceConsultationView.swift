import SwiftUI
import SwiftData

struct VoiceConsultationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var vm = VoiceConsultationViewModel()
    @State private var selectedNote: Note?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.primaryText)
                    }
                    Spacer()
                    Text("语音咨询")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.primaryText)
                    Spacer()
                    Color.clear.frame(width: 20) // Balance
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(AppColors.background)
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if vm.messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "mic.circle")
                                        .font(.system(size: 60))
                                        .foregroundColor(AppColors.secondaryText.opacity(0.5))
                                    Text("有什么可以帮你的吗？")
                                        .font(AppFonts.title2())
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .frame(maxWidth: .infinity, minHeight: 400)
                            } else {
                                ForEach(vm.messages) { msg in
                                    ChatBubble(message: msg, vm: vm, context: context, selectedNote: $selectedNote)
                                        .id(msg.id)
                                }
                            }
                            
                            if vm.isLoading {
                                HStack {
                                    ProgressView()
                                    Text("AI 正在思考...")
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("loading")
                            }
                            
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: vm.isLoading) { _, newValue in
                        if newValue { withAnimation { proxy.scrollTo("loading", anchor: .bottom) } }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
                
                // Bottom Control Area
                VStack(spacing: 0) {
                    Divider()
                    
                    VStack(spacing: 16) {
                        // Editable Transcript Window
                        ZStack(alignment: .topLeading) {
                            if vm.liveTranscript.isEmpty && !isInputFocused {
                                Text("点击开始说话或输入...")
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $vm.liveTranscript)
                                .focused($isInputFocused)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.primaryText)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.divider, lineWidth: 1)
                                )
                                .frame(minHeight: 60, maxHeight: 120)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // Error Message
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.error)
                        }
                        
                        // Buttons
                        HStack(spacing: 40) {
                            // Cancel
                            Button(action: {
                                if vm.isRecording {
                                    vm.cancelRecording()
                                } else {
                                    vm.liveTranscript = ""
                                }
                            }) {
                                Text("取消")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .opacity(!vm.liveTranscript.isEmpty || vm.isRecording ? 1 : 0)
                            
                            // Mic Button
                            Button(action: { vm.toggleRecording() }) {
                                ZStack {
                                    Circle()
                                        .fill(vm.isRecording ? AppColors.error : AppColors.accent)
                                        .frame(width: 72, height: 72)
                                        .shadow(color: (vm.isRecording ? AppColors.error : AppColors.accent).opacity(0.4), radius: 10, x: 0, y: 4)
                                        .scaleEffect(vm.isRecording ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: vm.isRecording)
                                    
                                    Image(systemName: vm.isRecording ? "pause.fill" : "mic.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Done
                            Button(action: {
                                isInputFocused = false
                                Task { await vm.submit(context: context) }
                            }) {
                                Text("完成")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.accent)
                            }
                            .opacity(!vm.liveTranscript.isEmpty || vm.isRecording ? 1 : 0)
                            .disabled(vm.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.bottom, 30)
                    }
                    .background(AppColors.background)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(item: $selectedNote) { note in
            NoteDetailView(note: note)
        }
        .onDisappear {
            vm.cancelRecording()
        }
    }
}

struct ChatBubble: View {
    let message: VoiceConsultationViewModel.ChatMessage
    let vm: VoiceConsultationViewModel
    let context: ModelContext
    @Binding var selectedNote: Note?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
                Text(message.content)
                    .font(AppFonts.body())
                    .foregroundColor(.white)
                    .padding(12)
                    .background(AppColors.accent)
                    .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
            } else {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.accent)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !message.source_notes.isEmpty {
                        Divider()
                        Text("参考笔记：")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.secondaryText)
                        ForEach(message.source_notes, id: \.self) { source in
                            Button(action: {
                                if let note = vm.findNote(by: source, context: context) {
                                    selectedNote = note
                                }
                            }) {
                                HStack {
                                    Text("• \(source)")
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.accent)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .padding(12)
                .background(AppColors.cardBackground)
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                Spacer()
            }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
