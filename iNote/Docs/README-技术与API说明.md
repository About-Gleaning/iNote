# iNote 技术与 API 集成说明

## 架构概览
- 单页结构：应用直接进入 `录入 EntryView`，顶部包含随笔列表。
- 数据存储：SwiftData 模型 `Note`、`MediaAsset`、`Tag`，已按 CloudKit 要求设置默认值与可选关系。
- 同步：启用 iCloud/CloudKit 自动同步；Info.plist 已包含 Remote Notifications 背景模式。

## 数据模型
- `Note`：标题、正文、摘要、创建时间、草稿标记、AI状态、语音逐字稿、视觉描述、媒体集合、标签集合。
- `MediaAsset`：媒体类型（audio/image/video）、本地URL、缩略图、所属笔记。
- `Tag`：名称、颜色、关联笔记集合。

## 页面与功能
- 录入页（含随笔列表）：
  - 随笔列表：顶部展示笔记列表，支持 SwiftData 分页查询与下拉刷新；点击进入详情查看与编辑。
  - 语音录入：`AVAudioRecorder`，自动保存草稿（3秒节流）。
  - 图片/视频：`PhotosPicker` 选择；视频抽帧为 JPEG，用于图像描述。
  - 提交：调用媒体处理与 OpenRouter，总结写入 `Note.summary`。标签示例已接入。

## iCloud/CloudKit 配置
1. Xcode Target → Signing & Capabilities：添加 iCloud 能力，勾选 CloudKit。
2. 在 iCloud Containers 中添加容器，建议：`iCloud.com.<yourTeamId>.iNote`。
3. 将该容器 ID 写入 `iNote/iNote.entitlements` 的 `com.apple.developer.icloud-container-identifiers`。
4. 添加 Background Modes 能力，勾选 Remote Notifications（Info.plist 已包含）。
5. 真机测试更可靠；模型字段需具备默认值或可选关系。

## 权限与 Info.plist
- `NSMicrophoneUsageDescription`、`NSCameraUsageDescription`、`NSPhotoLibraryUsageDescription`、`NSPhotoLibraryAddUsageDescription`、`NSSpeechRecognitionUsageDescription` 已声明。

## OpenRouter 集成
- 终端点：`https://openrouter.ai/api/v1/chat/completions`
- 鉴权：请求头 `Authorization: Bearer <YOUR_OPENROUTER_API_KEY>`。
- 项目中读取 `Info.plist` 的 `OpenRouterAPIKey` 字段；请替换为真实密钥。
- 文本聊天：`OpenRouterService.chat(messages:)`，模型示例：`openai/gpt-4o-mini`。
- 图像描述：`OpenRouterService.describeImages(_:)` 使用 OpenAI兼容的多模态内容格式，图片以 `data:image/jpeg;base64,<...>` 发送。
- 总结：`MediaProcessingService.summarizeAndDescribe(note:)` 根据正文/逐字稿/视觉描述生成 ≤400字总结。

### 请求示例（文本聊天）
```
POST /api/v1/chat/completions
{"model":"openai/gpt-4o-mini","messages":[{"role":"user","content":"你好"}],"temperature":0.2}
```

### 请求示例（图像描述，多模态）
```
{"model":"openai/gpt-4o-mini","messages":[{"role":"user","content":[{"type":"input_text","text":"请为这些图片生成详细描述，合并为一段。"},{"type":"input_image","image_url":"data:image/jpeg;base64,<base64>"}]}],"temperature":0.2}
```

## 构建与运行
- 将 `Info.plist` 的 `OpenRouterAPIKey` 替换为实际密钥。
- 完成 iCloud 容器配置后，使用真机运行体验自动同步与通知。

## 后续改进建议
- 标签选择器与分类管理 UI。
- 更细致的错误状态与重试策略。
- 视频多帧抽取与更精准的视觉描述。
- 单元测试覆盖网络与存储层。