## 目标
- 在“更多”菜单中启用“拍笔记”，进入系统相机拍照。
- 使用 Apple Vision 从拍摄图片中提取文字。
- 调用 AI 模型 `qwen3-max`，基于提取文本生成：标题、摘要、标签。
- 弹出确认页面并自动保存草稿；页面包含：标题、原图片、提取文本、AI 摘要、标签。

## 现有结构与接入点
- 入口与菜单：`iNote/iNote/EntryView.swift:303–320` 存在 “拍笔记” 按钮，目前弹出“未开放该功能”。
- 相机封装：`CameraPicker`（`UIImagePickerController`）在 `iNote/iNote/EntryView.swift:731+`，已有 `onImageData` 回调。
- 确认页面弹窗：`confirmEditorView()` 在 `iNote/iNote/EntryView.swift:487+`，已支持标题/AI总结/视觉描述/文字输入/标签；打开逻辑在 `iNote/iNote/EntryView.swift:108–121`。
- 模型与持久化：`Note/MediaAsset/Tag`（SwiftData），`EntryViewModel` 负责创建草稿、附加媒体、AI 分析与弹出编辑器。
- AI服务：`QwenService.swift` 当前模型固定为 `qwen3-omni-flash`；文本/多模态接口已就绪。
- 本地媒体处理：`MediaProcessingService.swift` 已有音频转写；未集成 Vision。

## 设计与实现方案
1. 启用“拍笔记”入口
- 修改 `iNote/iNote/EntryView.swift:303–320` 中按钮的 `action`：
  - `vm.beginNewNote(context: context); cameraKind = .photo; showCamera = true; showMoreMenu = false`，进入系统相机。

2. 图像捕获后的流程
- 在 `fullScreenCover` 相机回调处（`iNote/iNote/EntryView.swift:127–137`）：将 `onImageData` 调用改为新的 VM 方法（见下一步）。
- 行为：附加图片到当前草稿、运行 Vision OCR、把提取文本写入 `vm.text` 与 `note.content`。

3. Vision OCR 提取文本
- 在 `MediaProcessingService.swift` 增加方法：`extractTextFromImage(data:) -> String`
  - 使用 `Vision` 框架：`VNRecognizeTextRequest`（识别语言优先中文 `zh-Hans` + 英文），`VNImageRequestHandler(data:)`。
  - 返回合并后的识别文本（去重与换行规整）。

4. 基于文本的 AI 生成
- 在 `EntryViewModel` 增加方法：`createPhotoNote(withImageData:data, context:)`（名称可按项目风格调整），编排：
  - `beginNewNote(context:)` → `attachMedia(kind:.image)` → `extractTextFromImage(data:)` → 设置 `vm.text` & `note.content`。
  - 构造提示词调用 `QwenService.chat(prompt:)`，模型应为 `qwen3-max`，仅输出 JSON：
    - `{ "title": string, "summary": string, "tags": [string] }`
    - 约束：`title ≤ 15字`，`summary 80–150字`，`tags ≤ 5`，来自文本关键词；严格只输出纯 JSON。
  - 解析 JSON（复用现有 `decodeDict/pick/pickArr` 模式）：写入 `note.title/note.summary/note.tags`。
  - 设置 `vm.shouldShowEditor = true`，触发确认弹窗；同时 `note.aiStatus = "success"/"error"` 覆盖状态提示。

5. 切换 AI 模型到 `qwen3-max`
- 修改 `iNote/iNote/QwenService.swift`：将 `ChatPayload(model:)` 的模型名改为 `"qwen3-max"`（文本、图像 JSON、多模态音频接口均保持一致）。
  - 参考位置：`iNote/iNote/QwenService.swift:32, 67, 100, 184`。

6. 确认页面展示优化
- 在 `confirmEditorView()`（`iNote/iNote/EntryView.swift:487+`）中：
  - 新增“原图片”区块：从 `vm.currentNote?.assets` 过滤 `image`，以缩略或原图预览（已有缩略支持可直接从文件读出显示）。
  - 若存在 OCR 结果，则将“文字输入”区块的标题动态改为“提取文本”，初始内容来自 `editedText = vm.text`（已在 `onChange(vm.shouldShowEditor)` 赋值）。
  - 保持标签区块展示；由 AI 生成的标签映射至 `Tag` 后在确认页以 Chip 展示（已支持）。

7. 自动保存草稿与最终保存
- 草稿自动保存：保持现有逻辑，确认页弹出时调用 `vm.persistIfNeeded(context:)`（`iNote/iNote/EntryView.swift:120–121`）。
- 用户点击“保存”按钮后：`vm.persistAndFinalize(context:)` + `context.save()`（`iNote/iNote/EntryView.swift:671–699`）。

8. 错误处理与兜底
- Vision 失败或返回空文本：`vm.text` 留空，仅保存图片并弹出确认页，让用户手动补充；AI 跳过或改用本地摘要（`offlineSummary`）。
- AI 请求失败：按照现有 `QwenError` 显示状态（`unauthorized/payment_required/error`），并用 `offlineSummary(for:)` 兜底摘要（`iNote/iNote/EntryView.swift:925–927`）。

## 变更文件清单
- `iNote/iNote/EntryView.swift`
  - 启用“拍笔记”按钮（`303–320`）
  - 相机回调接入 VM 新方法（`127–137`）
  - 确认页面新增“原图片”预览与“提取文本”标题动态化（`487+`）
- `iNote/iNote/EntryViewModel.swift`
  - 新增拍照笔记编排方法：附图 → OCR → AI → 弹出确认
- `iNote/iNote/MediaProcessingService.swift`
  - 新增 `extractTextFromImage(data:)`，引入 `import Vision`
- `iNote/iNote/QwenService.swift`
  - 将模型名改为 `qwen3-max`

## 权限与兼容
- 相机/相册/麦克风权限已在 `Info.plist`；Vision 无额外权限需求。
- 兼容现有相册导入与视频关键帧分析逻辑，互不影响。

## 测试要点
- 从“更多”→“拍笔记”拍含中文/英文图片，确认 OCR 文本正确性。
- AI 返回 JSON 的健壮解析（非标准 JSON 包裹时也能截取 `{...}`）。
- 确认页是否包含：标题、原图片、提取文本、AI 摘要、标签；保存后列表卡片展示正确。
- 异常场景：无文本/AI失败/网络异常，均能正常弹窗与保存草稿。