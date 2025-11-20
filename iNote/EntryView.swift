import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import AVKit
import UIKit

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
    @State private var editedVisual: String = ""
    @State private var selectedTagNames: Set<String> = []
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @Query private var allTags: [Tag]
    private let tagOptions: [String] = ["开心","生气","难过","工作","运动","睡眠"]
    enum ConfirmFocus { case title, text, transcript, summary, visual }
    @FocusState private var confirmFocus: ConfirmFocus?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                SearchBar(text: $searchText, focus: $searchFocused)
                    .padding(.horizontal, AppDimens.padding)
                // Notes List Area
                List {
                    ForEach(filteredNotes) { note in
                        NoteCardView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNoteForNavigation = note }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppDimens.padding, bottom: 0, trailing: AppDimens.padding))
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
        .onChange(of: searchFocused) { oldValue, newValue in
            print("DEBUG: searchFocused changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: vm.shouldShowEditor) { _, newValue in
            if newValue {
                if let note = vm.currentNote {
                    editedTitle = note.title.isEmpty ? String((note.transcript.isEmpty ? vm.text : note.transcript).prefix(15)) : note.title
                    editedText = vm.text
                    editedTranscript = note.transcript
                    editedSummary = note.summary
                    editedVisual = note.visualDescription
                    if let tags = note.tags { selectedTagNames = Set(tags.compactMap { $0.name }) }
                }
                showTranscriptionEditor = true
                vm.shouldShowEditor = false
            }
        }
        
        .keyboardDismissToolbar("完成") { searchFocused = false }
        .sheet(isPresented: $showTranscriptionEditor) { confirmEditorView() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(kind: cameraKind, onImageData: { data in
                Task { await vm.attachImageData([data], context: context) }
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

                if vm.mode == .audioText {
                    HStack {
                        Button(action: { showMoreMenu = true }) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.leading, 24)
                        
                        Spacer()
                        
                        // Camera Button (Left)
                        Button(action: {
                            cameraKind = .photo
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
                        
                        // Recording Button (Center)
                        Button(action: { vm.toggleRecord(context: context) }) {
                            ZStack {
                                Circle()
                                    .fill(vm.isRecording ? AppColors.error : AppColors.accent)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: (vm.isRecording ? AppColors.error : AppColors.accent).opacity(0.4), radius: 10, x: 0, y: 4)
                                    .scaleEffect(vm.isRecording ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: vm.isRecording)
                                
                                Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Video Button (Right)
                        Button(action: {
                            cameraKind = .video
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
                        
                        // Placeholder for symmetry or another action
                        Color.clear.frame(width: 28, height: 28).padding(.trailing, 24)
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
                                Button(action: { unavailableMessage = "未开放该功能"; showUnavailableAlert = true; showMoreMenu = false }) {
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

    

    @ViewBuilder
    private func confirmEditorView() -> some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标题").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                            TextField("请输入标题", text: $editedTitle)
                                .focused($confirmFocus, equals: .title)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, AppDimens.padding)

                        if (vm.currentNote?.assets?.contains(where: { $0.kind == MediaKind.audio.rawValue }) ?? false) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("逐字稿").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextEditor(text: $editedTranscript)
                                    .focused($confirmFocus, equals: .transcript)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, AppDimens.padding)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI总结").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                            TextEditor(text: $editedSummary)
                                .focused($confirmFocus, equals: .summary)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, AppDimens.padding)

                        if (vm.currentNote?.assets?.contains(where: { $0.kind == MediaKind.image.rawValue || $0.kind == MediaKind.video.rawValue }) ?? false) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("视觉描述").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                                TextEditor(text: $editedVisual)
                                    .focused($confirmFocus, equals: .visual)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, AppDimens.padding)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("文字输入").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                            TextEditor(text: $editedText)
                                .focused($confirmFocus, equals: .text)
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, AppDimens.padding)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("标签").font(AppFonts.caption()).foregroundColor(AppColors.secondaryText)
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(tagOptions, id: \.self) { name in
                                    let selected = selectedTagNames.contains(name)
                                    Button(action: {
                                        if selected { selectedTagNames.remove(name) } else { selectedTagNames.insert(name) }
                                    }) {
                                        Text(name)
                                            .font(AppFonts.subheadline())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selected ? AppColors.accent.opacity(0.15) : AppColors.cardBackground)
                                            .foregroundColor(selected ? AppColors.accent : AppColors.primaryText)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selected ? AppColors.accent : Color.clear, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppDimens.padding)

                        HStack(spacing: 16) {
                            Button(action: {
                                showTranscriptionEditor = false
                                vm.pendingTranscription = nil
                                vm.resetSession()
                                resetUI()
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
                                vm.text = editedText
                                if let note = vm.currentNote {
                                    note.title = editedTitle
                                    note.content = editedText
                                    note.transcript = editedTranscript
                                    note.summary = editedSummary
                                    note.visualDescription = editedVisual
                                    var chosen: [Tag] = []
                                    for name in selectedTagNames {
                                        if let existed = allTags.first(where: { $0.name == name }) {
                                            chosen.append(existed)
                                        } else {
                                            let t = Tag()
                                            t.name = name
                                            context.insert(t)
                                            chosen.append(t)
                                        }
                                    }
                                    vm.applyTags(chosen)
                                    vm.persistAndFinalize(context: context)
                                }
                                showTranscriptionEditor = false
                                vm.pendingTranscription = nil
                                vm.resetSession()
                                resetUI()
                            }) {
                                Text("保存")
                                    .font(AppFonts.headline())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.accent)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, AppDimens.padding)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { confirmFocus = nil }
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    private func resetUI() {
        editedTitle = ""
        editedText = ""
        editedTranscript = ""
        editedSummary = ""
        editedVisual = ""
        selectedTagNames = []
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
        guard let note = vm.currentNote else { return }
        vm.finalize()
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
        // Images and video key frames -> description via OpenRouter
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
            if !imagesData.isEmpty {
                let service = QwenService()
                let desc = try await service.describeImages(imagesData)
                note.visualDescription = desc
            }
            try await processor.summarizeAndDescribe(note: note)
            note.aiStatus = "success"
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