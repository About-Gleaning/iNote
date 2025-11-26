import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import AVKit
import UIKit

extension Notification.Name {
    static let noteSaved = Notification.Name("NoteSaved")
}

struct EntryView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = EntryViewModel()
    @StateObject private var notesVM = NotesViewModel()
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @FocusState private var textFocused: Bool
    @State private var showCamera: Bool = false
    enum CameraKind { case photo, video }
    @State private var cameraKind: CameraKind = .photo
    @State private var showMoreMenu: Bool = false
    @State private var showAlbumTypeMenu: Bool = false
    @State private var showLibrary: Bool = false
    @State private var showUnavailableAlert: Bool = false
    @State private var unavailableMessage: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteNote: Note?
    @State private var selectedNoteForNavigation: Note?
    @State private var showTranscriptionEditor: Bool = false
    @State private var editedText: String = ""
    @State private var editedTitle: String = ""
    @State private var editedTranscript: String = ""
    @State private var editedSummary: String = ""
    @State private var editedIntegratedSummary: String = ""
    @State private var editedVisual: String = ""
    @State private var editedVisualTranscript: String = ""
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @Query private var allTags: [Tag]
    enum ConfirmFocus { case title, text, transcript, summary, integratedSummary, visual }
    @FocusState private var confirmFocus: ConfirmFocus?
    
    // AI Search State
    @State private var isSearching: Bool = false
    @State private var aiSearchResponse: String = ""
    @State private var isLoadingSearch: Bool = false
    @State private var searchError: String? = nil
    private let qwenService = QwenService()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                SearchBar(text: $searchText, focus: $searchFocused, onSubmit: {
                    performAISearch()
                }, onCancel: {
                    isSearching = false
                    aiSearchResponse = ""
                    searchError = nil
                })
                .padding(.horizontal, AppDimens.padding)
                
                // AI Search Response Display
                if isSearching && !aiSearchResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(AppColors.accent)
                            Text("AI 回答")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                            Button(action: {
                                isSearching = false
                                aiSearchResponse = ""
                                searchError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        
                        Text(aiSearchResponse)
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.primaryText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, AppDimens.padding)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, AppDimens.padding)
                }
                
                // Loading Indicator
                if isLoadingSearch {
                    HStack {
                        ProgressView()
                        Text("AI 正在分析日记...")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, AppDimens.padding)
                }
                
                // Error Display
                if let error = searchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(AppColors.error)
                        Text(error)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.error)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, AppDimens.padding)
                }
                // Notes List Area
                List {
                    ForEach(filteredNotes) { note in
                        NoteCardView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if searchFocused {
                                    searchFocused = false
                                } else {
                                    selectedNoteForNavigation = note
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppDimens.padding, bottom: 0, trailing: AppDimens.padding))
                            .listRowBackground(AppColors.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteNote = note
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                .tint(AppColors.error)
                            }
                    }

                    if notesVM.hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .onAppear { Task { await notesVM.loadMore(context: context) } }
                            Spacer()
                        }
                        .padding(.vertical)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .preferredColorScheme(.light)
                .refreshable { await notesVM.refresh(context: context) }
                
                modeArea()
                statusArea()
                Spacer()
            }
        }
        
        .onAppear {
            vm.start(context: context)
            Task { await notesVM.refresh(context: context) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteSaved)) { _ in
            Task { await notesVM.refresh(context: context) }
        }
        .onChange(of: searchFocused) { oldValue, newValue in
            print("DEBUG: searchFocused changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: vm.shouldShowEditor) { _, newValue in
            if newValue {
                if let note = vm.currentNote {
                    let baseText = note.transcript.isEmpty ? note.content : note.transcript
                    editedTitle = note.title.isEmpty ? String(baseText.prefix(15)) : note.title
                    editedText = note.content
                    editedTranscript = note.transcript
                    editedSummary = note.summary
                    editedIntegratedSummary = note.integratedSummary
                    editedVisual = note.visualDescription
                    editedVisualTranscript = note.visualTranscript
                }
                showTranscriptionEditor = true
                vm.shouldShowEditor = false
                vm.persistIfNeeded(context: context)
            }
        }
        
        .keyboardDismissToolbar("完成") { searchFocused = false }
        .sheet(isPresented: $showTranscriptionEditor) { confirmEditorView() }
        .sheet(isPresented: $vm.shouldShowLinkInput) {
            LinkInputView(vm: vm) {
                Task {
                    showCamera = false
                    showMoreMenu = false
                    await submit()
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(kind: cameraKind, onImageData: { data in
                Task { await vm.createPhotoNote(with: data, context: context) }
            }, onVideoURL: { url in
                Task { await vm.attachVideoURLs([url], context: context) }
            }, onCancel: {
                vm.mode = .audioText
                showCamera = false
                vm.resetSession()
                resetUI()
            })
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {

                if vm.mode == .audioText && !searchFocused {
                    HStack {
                        if vm.recordState == .idle {
                            Button(action: { showMoreMenu = true }) {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.leading, 24)
                            
                            Spacer()
                            
                            Button(action: {
                                cameraKind = .photo
                                vm.linkMode = false
                                showCamera = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.cardBackground)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColors.primaryText)
                                }
                            }
                            .padding(.trailing, 20)
                        }
                        
                        if vm.recordState == .idle {
                            Button(action: { vm.toggleRecord(context: context) }) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent)
                                        .frame(width: 72, height: 72)
                                        .shadow(color: AppColors.accent.opacity(0.4), radius: 10, x: 0, y: 4)
                                        .scaleEffect(1.0)
                                        .animation(.easeInOut(duration: 0.2), value: vm.recordState == .idle)
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        if vm.recordState == .idle {
                            Button(action: {
                                cameraKind = .video
                                vm.linkMode = false
                                showCamera = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.cardBackground)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColors.primaryText)
                                }
                            }
                            .padding(.leading, 20)
                            
                            Spacer()
                            
                            Color.clear.frame(width: 28, height: 28).padding(.trailing, 24)
                        } else {
                            Spacer()
                            VStack(spacing: 6) {
                                Text(String(format: "%02d:%02d / 00:20", Int(vm.elapsedSeconds) / 60, Int(vm.elapsedSeconds) % 60))
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.secondaryText)
                                HStack(spacing: 16) {
                                    Button(action: { vm.cancelRecord(context: context); resetUI() }) {
                                        Text("取消")
                                            .font(AppFonts.headline())
                                            .foregroundColor(AppColors.secondaryText)
                                            .frame(width: 72, height: 44)
                                            .background(AppColors.cardBackground)
                                            .cornerRadius(12)
                                    }
                                    Button(action: { vm.toggleRecord(context: context) }) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.error)
                                                .frame(width: 72, height: 72)
                                                .shadow(color: AppColors.error.opacity(0.4), radius: 10, x: 0, y: 4)
                                                .scaleEffect(1.1)
                                                .animation(.easeInOut(duration: 0.2), value: vm.recordState == .idle)
                                            Image(systemName: vm.recordState == .recording ? "pause.fill" : "play.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Button(action: { vm.finishRecord(context: context) }) {
                                        Text("完成")
                                            .font(AppFonts.headline())
                                            .foregroundColor(.white)
                                            .frame(width: 72, height: 44)
                                            .background(AppColors.accent)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                    .background(AppColors.background.opacity(0.9))
                }
            }
        }
        .navigationDestination(item: $selectedNoteForNavigation) { note in
            NoteDetailView(note: note)
        }
        .overlay(
            Group {
                if showMoreMenu {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { showMoreMenu = false }
                        VStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Button(action: { unavailableMessage = "未开放该功能"; showUnavailableAlert = true; showMoreMenu = false }) {
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(AppColors.secondaryText)
                                        Text("链接")
                                            .font(AppFonts.headline())
                                            .foregroundColor(AppColors.primaryText)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.divider, lineWidth: 1)
                                    )
                                }
                                Button(action: { showAlbumTypeMenu = true; showMoreMenu = false }) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                            .foregroundColor(AppColors.secondaryText)
                                        Text("相册")
                                            .font(AppFonts.headline())
                                            .foregroundColor(AppColors.primaryText)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.divider, lineWidth: 1)
                                    )
                                }
                                Button(action: { vm.beginNewNote(context: context); vm.linkMode = true; cameraKind = .photo; showCamera = true; showMoreMenu = false }) {
                                    HStack {
                                        Image(systemName: "pencil")
                                            .foregroundColor(AppColors.primaryText)
                                        Text("拍笔记")
                                            .font(AppFonts.headline())
                                            .foregroundColor(AppColors.primaryText)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.divider, lineWidth: 1)
                                    )
                                }
                                Button(action: { showMoreMenu = false }) {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(AppColors.secondaryText)
                                        Text("取消")
                                            .font(AppFonts.headline())
                                            .foregroundColor(AppColors.secondaryText)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.divider, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                            .background(AppColors.cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: -2)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showMoreMenu)
                }
            }
        )
        .confirmationDialog("选择从相册导入类型", isPresented: $showAlbumTypeMenu) {
            Button("图片") { vm.beginNewNote(context: context); cameraKind = .photo; showLibrary = true }
            Button("视频") { vm.beginNewNote(context: context); cameraKind = .video; showLibrary = true }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("确认删除该日记？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let n = pendingDeleteNote {
                    context.delete(n)
                    do { try context.save() } catch { }
                    pendingDeleteNote = nil
                    Task { await notesVM.refresh(context: context) }
                }
            }
            Button("取消", role: .cancel) { pendingDeleteNote = nil }
        }
        .alert(unavailableMessage, isPresented: $showUnavailableAlert) {
            Button("确定", role: .cancel) {}
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker(kind: cameraKind, maxSelection: cameraKind == .photo ? 9 : 1, onImages: { datas in
                Task { await vm.attachImageData(datas, context: context) }
            }, onVideos: { urls in
                Task { await vm.attachVideoURLs(urls, context: context) }
            }, onCancel: {
                vm.resetSession()
                resetUI()
            })
        }
    }


    private var filteredNotes: [Note] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return notesVM.notes }
        return notesVM.notes.filter { note in
            note.title.lowercased().contains(q)
            || note.content.lowercased().contains(q)
            || note.summary.lowercased().contains(q)
        }
    }

    



    @ViewBuilder
    private func modeArea() -> some View {
        switch vm.mode {
        case .imageText:
            imageMode()
        case .audioText:
            audioMode()
        case .videoText:
            videoMode()
        }
    }

    @ViewBuilder
    private func imageMode() -> some View { EmptyView() }

    @ViewBuilder
    private func audioMode() -> some View {
        EmptyView()
    }



    @ViewBuilder
    private func videoMode() -> some View { EmptyView() }

    @ViewBuilder
    private func actionBar() -> some View {
        HStack {
            Button("标签") {
                let sample = Tag()
                sample.name = "默认"
                context.insert(sample)
                vm.applyTags([sample])
            }
            Spacer()
            Button("提交") { Task { await submit() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func statusArea() -> some View {
        if let status = vm.currentNote?.aiStatus, !status.isEmpty {
            HStack {
                Text("AI状态：\(localizedAIStatus(status))")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.secondaryText)
                
                if status == "unauthorized" {
                    Text("提示：OpenRouter密钥无效或未配置")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.error)
                }
                if status == "payment_required" {
                    Text("提示：OpenRouter额度不足，请充值或更换有额度的密钥")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(.horizontal, AppDimens.padding)
            .padding(.vertical, 4)
            .background(AppColors.cardBackground.opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, AppDimens.padding)
        }
    }

    private func localizedAIStatus(_ code: String) -> String {
        switch code {
        case "requesting": return "请求中"
        case "success": return "成功"
        case "unauthorized": return "未授权"
        case "payment_required": return "需付费"
        case "error": return "错误"
        default: return code
        }
    }
    
    // MARK: - AI Search Functions
    
    private func performAISearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchFocused = false
            return
        }
        
        Task {
            isLoadingSearch = true
            isSearching = true
            searchError = nil
            aiSearchResponse = ""
            searchFocused = false
            
            do {
                let diaryContext = buildDiaryContext()
                let response = try await qwenService.searchDiaries(query: query, diaryContext: diaryContext)
                aiSearchResponse = response
            } catch QwenError.missingAPIKey {
                searchError = "未配置API密钥"
            } catch QwenError.invalidAPIKey {
                searchError = "API密钥无效"
            } catch QwenError.unauthorized(let msg) {
                searchError = "未授权: \(msg)"
            } catch QwenError.paymentRequired(let msg) {
                searchError = "需付费: \(msg)"
            } catch {
                searchError = "搜索失败: \(error.localizedDescription)"
            }
            
            isLoadingSearch = false
        }
    }
    
    private func buildDiaryContext() -> String {
        var context = ""
        
        for (index, note) in notesVM.notes.enumerated() {
            context += "--- 日记 \(index + 1) ---\n"
            
            if !note.title.isEmpty {
                context += "标题: \(note.title)\n"
            }
            
            if !note.content.isEmpty {
                context += "内容: \(note.content)\n"
            }
            
            if !note.summary.isEmpty {
                context += "总结: \(note.summary)\n"
            }
            
            if !note.integratedSummary.isEmpty {
                context += "综合总结: \(note.integratedSummary)\n"
            }
            
            if !note.transcript.isEmpty {
                context += "语音逐字稿: \(note.transcript)\n"
            }
            
            if !note.visualDescription.isEmpty {
                context += "视觉描述: \(note.visualDescription)\n"
            }
            
            if !note.visualTranscript.isEmpty {
                context += "视觉逐字稿: \(note.visualTranscript)\n"
            }
            
            if let tags = note.tags, !tags.isEmpty {
                let tagNames = tags.map { $0.name }.joined(separator: ", ")
                context += "标签: \(tagNames)\n"
            }
            
            context += "\n"
        }
        
        return context
    }

    

    @ViewBuilder
    private func confirmEditorView() -> some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 0) {
                        // 1. 标题 (Always Show)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标题").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                            TextField("请输入标题", text: $editedTitle)
                                .focused($confirmFocus, equals: .title)
                                .textFieldStyle(.plain)
                                .foregroundColor(AppColors.primaryText)
                                .tint(AppColors.primaryText)
                                .padding(12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .id(ConfirmFocus.title)
                        }
                        .padding(.horizontal, AppDimens.padding)
                        .padding(.bottom, 12)

                        // 2. 图片展示 (Show if assets exist)
                        if let assets = vm.currentNote?.assets?.filter({ $0.kind == MediaKind.image.rawValue }), !assets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("原图片").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(Array(assets.enumerated()), id: \.offset) { _, a in
                                        if let s = a.localURLString, let url = URL(string: s), let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 140)
                                                .clipped()
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }

                        // 3. AI 分析结果 (Summary / Integrated Summary)
                        // Show Integrated Summary if available
                        if !editedIntegratedSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("综合总结").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入综合总结", text: $editedIntegratedSummary, axis: .vertical)
                                    .focused($confirmFocus, equals: .integratedSummary)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.integratedSummary)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }
                        
                        // Show Summary if available
                        if !editedSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI总结").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入AI总结", text: $editedSummary, axis: .vertical)
                                    .focused($confirmFocus, equals: .summary)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.summary)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }

                        // 4. 视觉内容 (Visual Description / Visual Transcript)
                        if !editedVisual.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("视觉描述").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入视觉描述", text: $editedVisual, axis: .vertical)
                                    .focused($confirmFocus, equals: .visual)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.visual)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }

                        if !editedVisualTranscript.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("视觉逐字稿").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入视觉逐字稿", text: $editedVisualTranscript, axis: .vertical)
                                    .focused($confirmFocus, equals: .transcript)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.transcript)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }

                        // 5. 语音/文本内容 (Transcript / Content)
                        if !editedTranscript.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("语音逐字稿").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入语音逐字稿", text: $editedTranscript, axis: .vertical)
                                    .focused($confirmFocus, equals: .transcript)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.transcript)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }

                        // Always show content field if it's not empty, OR if it's the only field available (fallback)
                        // But usually 'content' is for user notes or link content.
                        // Always show content field if it's not empty, OR if it's the only field available (fallback)
                        // But usually 'content' is for user notes or link content.
                        if !editedText.isEmpty || (editedTranscript.isEmpty && editedVisual.isEmpty && editedVisualTranscript.isEmpty && editedSummary.isEmpty && editedIntegratedSummary.isEmpty) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("正文/备注").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextField("请输入正文或备注", text: $editedText, axis: .vertical)
                                    .focused($confirmFocus, equals: .text)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppColors.primaryText)
                                    .tint(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .id(ConfirmFocus.text)
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 12)
                        }
                        
                        
                        // Tags (AI Generated)
                        if let tags = vm.currentNote?.tags, !tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("标签（AI识别）").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(tags, id: \.name) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag.name)
                                                    .font(AppFonts.caption())
                                                    .foregroundColor(.white)
                                                Button(action: {
                                                    // Remove tag
                                                    vm.currentNote?.tags?.removeAll { $0.name == tag.name }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.accent)
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppDimens.padding)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 20)
                    .onChange(of: confirmFocus) { _, newValue in
                        if let newValue {
                            withAnimation {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                }
                .scrollDismissesKeyboard(.interactively)
                
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            // For photo note flow, note is already saved, just close editor
                            if vm.confirmSource == .photoNote {
                                showTranscriptionEditor = false
                                resetUI()
                            } else {
                                // For other flows, cancel and reset
                                vm.cancelRecord(context: context)
                                showTranscriptionEditor = false
                                resetUI()
                            }
                        }) {
                            Text("取消")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                vm.currentNote?.title = editedTitle
                                vm.currentNote?.content = editedText
                                vm.currentNote?.transcript = editedTranscript
                                vm.currentNote?.summary = editedSummary
                                vm.currentNote?.integratedSummary = editedIntegratedSummary
                                vm.currentNote?.visualDescription = editedVisual
                                vm.currentNote?.visualTranscript = editedVisualTranscript
                                
                                // Tags are already set by AI, no need to update
                                
                                vm.persistAndFinalize(context: context)
                                showTranscriptionEditor = false
                                resetUI()
                            }
                        }) {
                            Text("保存笔记")
                                .font(AppFonts.headline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.accent)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(AppColors.background)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let note = vm.currentNote {
                    if editedTitle.isEmpty { let base = note.transcript.isEmpty ? note.content : note.transcript; editedTitle = note.title.isEmpty ? String(base.prefix(15)) : note.title }
                    if editedTranscript.isEmpty { editedTranscript = note.transcript }
                    if editedSummary.isEmpty { editedSummary = note.summary }
                    if editedIntegratedSummary.isEmpty { editedIntegratedSummary = note.integratedSummary }
                    if editedVisual.isEmpty { editedVisual = note.visualDescription }
                    if editedVisualTranscript.isEmpty { editedVisualTranscript = note.visualTranscript }
                    if editedText.isEmpty { editedText = note.content }
                }
            }
        }
    }



    private func resetUI() {
        print("DEBUG resetUI: Resetting UI state")
        editedTitle = ""
        editedText = ""
        editedTranscript = ""
        editedSummary = ""
        editedIntegratedSummary = ""
        editedVisual = ""
        editedVisualTranscript = ""
        editedVisual = ""
        editedVisualTranscript = ""
        showLibrary = false
        showAlbumTypeMenu = false
        showMoreMenu = false
        showCamera = false
        confirmFocus = nil
        vm.mode = .audioText
    }

struct CameraPicker: UIViewControllerRepresentable {
        let kind: CameraKind
        var onImageData: ((Data) -> Void)?
        var onVideoURL: ((URL) -> Void)?
        var onCancel: () -> Void
        func makeCoordinator() -> Coordinator { Coordinator(kind: kind, onImageData: onImageData, onVideoURL: onVideoURL, onCancel: onCancel) }
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            if kind == .photo {
                picker.mediaTypes = ["public.image"]
                picker.cameraCaptureMode = .photo
            } else {
                picker.mediaTypes = ["public.movie"]
                picker.cameraCaptureMode = .video
                picker.videoQuality = .typeHigh
            }
            picker.modalPresentationStyle = .fullScreen
            picker.navigationBar.topItem?.title = "相机"
            picker.navigationBar.tintColor = UIColor(AppColors.accent)
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let kind: CameraKind
            let onImageData: ((Data) -> Void)?
            let onVideoURL: ((URL) -> Void)?
            let onCancel: () -> Void
            init(kind: CameraKind, onImageData: ((Data) -> Void)?, onVideoURL: ((URL) -> Void)?, onCancel: @escaping () -> Void) {
                self.kind = kind
                self.onImageData = onImageData
                self.onVideoURL = onVideoURL
                self.onCancel = onCancel
            }
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                switch kind {
                case .photo:
                    if let img = info[.originalImage] as? UIImage, let data = img.jpegData(compressionQuality: 0.85) { onImageData?(data) }
                case .video:
                    if let url = info[.mediaURL] as? URL { onVideoURL?(url) }
                }
                picker.dismiss(animated: true)
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true); onCancel() }
        }
    }

struct LibraryPicker: UIViewControllerRepresentable {
        let kind: CameraKind
        let maxSelection: Int
        var onImages: (([Data]) -> Void)?
        var onVideos: (([URL]) -> Void)?
        var onCancel: (() -> Void)?
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration()
            config.selectionLimit = maxSelection
            config.filter = (kind == .photo) ? .images : .videos
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(kind: kind, onImages: onImages, onVideos: onVideos, onCancel: onCancel) }
        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let kind: CameraKind
            let onImages: (([Data]) -> Void)?
            let onVideos: (([URL]) -> Void)?
            let onCancel: (() -> Void)?
            init(kind: CameraKind, onImages: (([Data]) -> Void)?, onVideos: (([URL]) -> Void)?, onCancel: (() -> Void)?) { self.kind = kind; self.onImages = onImages; self.onVideos = onVideos; self.onCancel = onCancel }
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)
                if results.isEmpty { onCancel?(); return }
                switch kind {
                case .photo:
                    var datas: [Data] = []
                    let group = DispatchGroup()
                    for r in results {
                        group.enter()
                        r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                            if let error = error {
                                print("DEBUG: Error loading image data: \(error)")
                            }
                            if let data { 
                                print("DEBUG: Loaded image data, size: \(data.count)")
                                datas.append(data) 
                            }
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) { 
                        print("DEBUG: Finished loading images, count: \(datas.count)")
                        self.onImages?(datas) 
                    }
                case .video:
                    var urls: [URL] = []
                    let group = DispatchGroup()
                    for r in results {
                        group.enter()
                        r.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                            if let url { urls.append(url) }
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) { self.onVideos?(urls) }
                }
            }
        }
    }

    private func submit() async {
        print("DEBUG submit: Function called, vm.currentNote is \(vm.currentNote == nil ? "NIL" : "NOT NIL (title='\(vm.currentNote!.title)')")")
        guard let note = vm.currentNote else { 
            print("DEBUG submit: currentNote is nil, cannot submit")
            return 
        }
        print("DEBUG submit: Starting submit for note with title='\(note.title)'")
        print("DEBUG submit: Before finalize, vm.currentNote is \(vm.currentNote == nil ? "NIL" : "NOT NIL")")
        vm.finalize()
        print("DEBUG submit: After finalize, vm.currentNote is \(vm.currentNote == nil ? "NIL" : "NOT NIL")")
        let processor = MediaProcessingService()
        note.aiStatus = "requesting"
        note.content = vm.text
        // Audio -> transcript
        if let assets = note.assets {
            for a in assets where a.kind == MediaKind.audio.rawValue {
                if let url = a.validURL {
                    let service = QwenService()
                    let prompt = #"只输出 JSON：{"transcript": string}，内容为该音频逐字稿，不要额外文本。"#
                    if let reply = try? await service.chat(text: prompt, audioURL: url) {
                        let s = reply
                        func decodeDict(_ s: String) -> [String: Any]? {
                            if let d = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
                            if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                                let sub = String(s[first...last])
                                if let d2 = sub.data(using: .utf8), let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
                            }
                            return nil
                        }
                        func pick(_ dict: [String: Any], keys: [String]) -> String? {
                            var lowered: [String: Any] = [:]
                            for (k, v) in dict { lowered[k.lowercased()] = v }
                            for k in keys {
                                if let v = dict[k] as? String, !v.isEmpty { return v }
                                if let v = lowered[k.lowercased()] as? String, !v.isEmpty { return v }
                            }
                            return nil
                        }
                        if let dict = decodeDict(s) {
                            if let t = pick(dict, keys: ["title", "标题"]) { note.title = t }
                            if let tr = pick(dict, keys: ["transcript", "逐字稿", "转写", "text"]) { note.transcript += tr + "\n" }
                            if let sum = pick(dict, keys: ["summary", "总结"]) { note.summary = sum }
                        } else if let text = try? await processor.transcribeAudio(at: url) {
                            note.transcript += text + "\n"
                        }
                    } else if let text = try? await processor.transcribeAudio(at: url) {
                        note.transcript += text + "\n"
                    }
                }
            }
        }
        // 图文合并分析（拍笔记：链接正文 + 手写图片）或仅视觉描述
        var imagesData: [Data] = []
        if let assets = note.assets {
            for a in assets {
                guard let url = a.validURL else { continue }
                if a.kind == MediaKind.image.rawValue {
                    if let data = try? Data(contentsOf: url) { imagesData.append(data) }
                } else if a.kind == MediaKind.video.rawValue {
                    let asset = AVURLAsset(url: url)
                    let gen = AVAssetImageGenerator(asset: asset)
                    gen.appliesPreferredTrackTransform = true
                    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                    if let cg = try? await generateCGImage(gen: gen, time: time) {
                        let ui = UIImage(cgImage: cg)
                        if let data = ui.jpegData(compressionQuality: 0.7) { imagesData.append(data) }
                    }
                }
            }
        }
        do {
            let service = QwenService()
            // 如果存在链接正文且有图片，则一次性多模态请求，返回综合字段
            if !imagesData.isEmpty && !vm.webContent.isEmpty {
                // 拍笔记的prompt之一
                let instruction = """
                你是专业的图文学习笔记整合助手，需严格按照以下要求整合学习资料与手写笔记，输出唯一的JSON结果（无任何前置、后置或额外文本）。
                
                首先，请阅读学习资料正文：
                \(note.content)
                
                然后，请参考手写笔记图片。
                请基于上述内容生成JSON，各字段需满足：
                1. "title"：不超过15个汉字，精准概括学习主题
                2. "integratedSummary"：仅对学习资料正文进行客观摘要，不得添加任何手写笔记内容或个人解读，500字以内
                3. "summary"：结合学习资料正文与手写笔记，提炼共同核心重点、笔记补充的关键信息或学习收获，500字以内
                4. "visualTranscript"：准确还原图片中手写笔记的逐字稿
                5. "tags"：至多5个中文简短标签，覆盖主题领域、核心概念等

                注意：
                - 所有内容用中文，不得添加外部信息
                - 严格遵守各字段的字数限制
                - 仅输出JSON，无其他任何文本

                请直接输出符合要求的JSON。
                """
                let out = try await service.analyzeImagesJSON(imagesData, instruction: instruction)
                func decodeDict(_ s: String) -> [String: Any]? {
                    if let d = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
                    if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                        let sub = String(s[first...last])
                        if let d2 = sub.data(using: .utf8), let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
                    }
                    return nil
                }
                func pickStr(_ dict: [String: Any], keys: [String]) -> String? {
                    var lowered: [String: Any] = [:]
                    for (k, v) in dict { lowered[k.lowercased()] = v }
                    for k in keys {
                        if let v = dict[k] as? String, !v.isEmpty { return v }
                        if let v = lowered[k.lowercased()] as? String, !v.isEmpty { return v }
                    }
                    return nil
                }
                func pickArr(_ dict: [String: Any], keys: [String]) -> [String]? {
                    var lowered: [String: Any] = [:]
                    for (k, v) in dict { lowered[k.lowercased()] = v }
                    for k in keys {
                        if let v = dict[k] as? [String], !v.isEmpty { return v }
                        if let v = lowered[k.lowercased()] as? [String], !v.isEmpty { return v }
                    }
                    return nil
                }
                if let dict = decodeDict(out) {
                    if let t = pickStr(dict, keys: ["title", "标题"]) { note.title = t }
                    if let sum = pickStr(dict, keys: ["summary", "摘要", "总结"]) { note.summary = sum }
                    if let isum = pickStr(dict, keys: ["integratedSummary", "综合总结", "整合总结"]) { note.integratedSummary = isum }
                    if let vtr = pickStr(dict, keys: ["visualTranscript", "图片逐字稿", "手写逐字稿", "逐字稿"]) { note.visualTranscript = vtr }
                    if let tagNames = pickArr(dict, keys: ["tags", "标签"]) {
                        var tags: [Tag] = []
                        for name in tagNames.prefix(5) {
                            if let existed = note.tags?.first(where: { $0.name == name }) { tags.append(existed) }
                            else { let t = Tag(); t.name = name; tags.append(t) }
                        }
                        note.tags = tags
                    }
                    if (note.integratedSummary.isEmpty && note.summary.isEmpty) {
                        let fallback = offlineSummary(for: note)
                        if !fallback.isEmpty { note.summary = fallback }
                    }
                }
            } else {
                if !imagesData.isEmpty {
                    // 拍笔记的prompt之二
                    let instruction = """
                    你是专业的图文学习笔记整合助手，需严格按照以下要求整合手写笔记，输出唯一的JSON结果（无任何前置、后置或额外文本）。

                    请根据手写笔记图片生成JSON，各字段需满足：
                    1. "title"：不超过15个汉字，精准概括学习主题
                    2. "summary"：基于手写笔记提炼核心重点、关键信息或学习收获，500字以内
                    3. "visualTranscript"：准确还原图片中手写笔记的逐字稿
                    4. "tags"：至多5个中文简短标签，覆盖主题领域、核心概念等

                    注意：
                    - 所有内容用中文，不得添加外部信息
                    - 严格遵守各字段的字数限制
                    - 仅输出JSON，无其他任何文本
                    """
                    let out = try await service.analyzeImagesJSON(imagesData, instruction: instruction)
                    func decodeDict(_ s: String) -> [String: Any]? {
                        if let d = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
                        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                            let sub = String(s[first...last])
                            if let d2 = sub.data(using: .utf8), let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
                        }
                        return nil
                    }
                    func pickStr(_ dict: [String: Any], keys: [String]) -> String? {
                        var lowered: [String: Any] = [:]
                        for (k, v) in dict { lowered[k.lowercased()] = v }
                        for k in keys {
                            if let v = dict[k] as? String, !v.isEmpty { return v }
                            if let v = lowered[k.lowercased()] as? String, !v.isEmpty { return v }
                        }
                        return nil
                    }
                    func pickArr(_ dict: [String: Any], keys: [String]) -> [String]? {
                        var lowered: [String: Any] = [:]
                        for (k, v) in dict { lowered[k.lowercased()] = v }
                        for k in keys {
                            if let v = dict[k] as? [String], !v.isEmpty { return v }
                            if let v = lowered[k.lowercased()] as? [String], !v.isEmpty { return v }
                        }
                        return nil
                    }
                    if let dict = decodeDict(out) {
                        if let t = pickStr(dict, keys: ["title", "标题"]) { note.title = t }
                        if let sum = pickStr(dict, keys: ["summary", "总结"]) { note.summary = sum }
                        if let vtr = pickStr(dict, keys: ["visualTranscript", "图片逐字稿", "手写逐字稿", "逐字稿"]) { note.visualTranscript = vtr }
                        if let tagNames = pickArr(dict, keys: ["tags", "标签"]) {
                            var tags: [Tag] = []
                            for name in tagNames.prefix(5) {
                                if let existed = note.tags?.first(where: { $0.name == name }) { tags.append(existed) }
                                else { let t = Tag(); t.name = name; tags.append(t) }
                            }
                            note.tags = tags
                        }
                    }
                } else {
                    try await processor.summarizeAndDescribe(note: note)
                }
            }
            note.aiStatus = "success"
            print("DEBUG submit: AI processing succeeded, note title='\(note.title)'")
            editedTitle = note.title.isEmpty ? String((note.transcript.isEmpty ? note.content : note.transcript).prefix(15)) : note.title
            editedTranscript = note.transcript
            editedSummary = note.integratedSummary.isEmpty ? note.summary : note.integratedSummary
            editedVisual = note.visualDescription
            editedVisualTranscript = note.visualTranscript
            print("DEBUG submit: About to call persistIfNeeded with local note variable")
            vm.persistIfNeeded(context: context, note: note)
            print("DEBUG submit: Called persistIfNeeded, setting confirmSource and shouldShowEditor")
            vm.confirmSource = .photoNote
            vm.shouldShowEditor = true
        } catch {
            if let e = error as? QwenError {
                switch e {
                case .missingAPIKey, .invalidAPIKey, .unauthorized:
                    note.aiStatus = "unauthorized"
                case .paymentRequired:
                    note.aiStatus = "payment_required"
                default:
                    note.aiStatus = "error"
                }
            } else {
                note.aiStatus = "error"
            }
            let offline = offlineSummary(for: note)
            if !offline.isEmpty { note.summary = offline }
            print("DEBUG submit: AI processing failed, calling persistIfNeeded with local note variable")
            vm.persistIfNeeded(context: context, note: note)
            print("DEBUG submit: Called persistIfNeeded after error, setting confirmSource and shouldShowEditor")
            vm.confirmSource = .photoNote
            vm.shouldShowEditor = true
        }
    }

    private func offlineSummary(for note: Note) -> String {
        var s = ""
        if !note.content.isEmpty { s += note.content + "\n" }
        if !note.transcript.isEmpty { s += note.transcript + "\n" }
        if !note.visualDescription.isEmpty { s += note.visualDescription + "\n" }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(400))
    }

    private func generateCGImage(gen: AVAssetImageGenerator, time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            gen.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let cgImage = cgImage {
                    cont.resume(returning: cgImage)
                } else {
                    cont.resume(throwing: error ?? NSError(domain: "AVAssetImageGenerator", code: -1))
                }
            }
        }
    }
}

struct LinkInputView: View {
    @ObservedObject var vm: EntryViewModel
    var onNext: () -> Void
    @State private var urlText: String = ""
    @State private var isFetching: Bool = false
    @State private var fetchError: String = ""
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("可选链接")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.secondaryText)
                        TextField("请输入URL（可选）", text: $urlText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled(true)
                            .foregroundColor(AppColors.primaryText)
                            .tint(AppColors.primaryText)
                            .padding(12)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, AppDimens.padding)

                    if !fetchError.isEmpty {
                        Text(fetchError)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, AppDimens.padding)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                isFetching = true
                                fetchError = ""
                                let u = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !u.isEmpty {
                                    let content = await vm.fetchWebContent(from: u)
                                    if content.isEmpty {
                                        fetchError = "正文提取失败或服务不可用"
                                    }
                                    vm.webContent = content
                                    vm.pendingLinkURL = u
                                    // Save link URL to note
                                    if let note = vm.currentNote {
                                        note.linkURL = u
                                    }
                                }
                                let combined = [vm.webContent, vm.text].filter { !$0.isEmpty }.joined(separator: "\n")
                                vm.text = combined
                                if let note = vm.currentNote { 
                                    note.content = combined 
                                }
                                isFetching = false
                                vm.shouldShowLinkInput = false
                                vm.linkMode = false
                                onNext()
                            }
                        }) {
                            if isFetching {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.accent)
                                    .cornerRadius(12)
                            } else {
                                Text("下一步")
                                    .font(AppFonts.headline())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.accent)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, AppDimens.padding)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("链接提取")
        }
    }
}
