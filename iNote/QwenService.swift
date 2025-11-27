import Foundation

enum QwenError: Error {
    case missingAPIKey
    case invalidAPIKey
    case unauthorized(String)
    case paymentRequired(String)
    case httpError(Int, String)
}

final class QwenService {
    private var endpoint: URL {
        let env = ProcessInfo.processInfo.environment["DASHSCOPE_BASE_URL"] ?? "https://dashscope.aliyuncs.com/compatible-mode/v1"
        return URL(string: env + "/chat/completions")!
    }
    private var apiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"], !envKey.isEmpty { return envKey }
        return Bundle.main.object(forInfoDictionaryKey: "DashScopeAPIKey") as? String
    }
    private let textModel = "qwen3-max"
    private let omniModel = "qwen3-omni-flash"

    func chat(prompt: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let content: [AnyEncodable] = [AnyEncodable(MessageContent.text(prompt))]
        let items: [ChatPayload.Item] = [.init(role: "user", content: content)]
        
        let payload = ChatPayload(model: textModel, messages: items, temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)

        print("Qwen 调用开始: chat, 模型=\(textModel), 文本长度=\(prompt.count)")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: data, encoding: .utf8) ?? ""
        print("Qwen 返回: chat, 状态=\(status), 字节数=\(data.count)")
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            print("Qwen 错误响应预览: chat=\(preview)")
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: chat=\(text)")
        return text
    }

    func describeImages(_ datas: [Data]) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var content: [AnyEncodable] = [AnyEncodable(MessageContent.text("请为这些图片生成详细描述，合并为一段。"))]
        for data in datas {
            let base64 = data.base64EncodedString()
            let url = "data:image/jpeg;base64,\(base64)"
            content.append(AnyEncodable(MessageContent.imageURL(url)))
        }
        let payload = ChatPayload(model: omniModel, messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: describeImages, 模型=\(omniModel), 图片数=\(datas.count), 大小=\(datas.map{ $0.count })")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: data, encoding: .utf8) ?? ""
        print("Qwen 返回: describeImages, 状态=\(status), 字节数=\(data.count)")
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            print("Qwen 错误响应预览: describeImages=\(preview)")
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: describeImages=\(text)")
        return text
    }

    func analyzeImagesJSON(_ datas: [Data], instruction: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var content: [AnyEncodable] = [AnyEncodable(MessageContent.text(instruction))]
        for data in datas {
            let base64 = data.base64EncodedString()
            let url = "data:image/jpeg;base64,\(base64)"
            content.append(AnyEncodable(MessageContent.imageURL(url)))
        }
        let payload = ChatPayload(model: omniModel, messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: analyzeImagesJSON, 模型=\(omniModel), 图片数=\(datas.count)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: data, encoding: .utf8) ?? ""
        print("Qwen 返回: analyzeImagesJSON, 状态=\(status), 字节数=\(data.count)")
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            print("Qwen 错误响应预览: analyzeImagesJSON=\(preview)")
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: analyzeImagesJSON=\(text)")
        return text
    }
}

private struct ChatResponse: Codable {
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let role: String; let content: String }
    let choices: [Choice]
}

private enum MessageContent: Encodable {
    case text(String)
    case imageURL(String)
    case inputAudio(data: String, format: String)
    case video([String])

    private enum CodingKeys: String, CodingKey { case type, text, image_url, input_audio, video }

    struct InputAudio: Encodable { let data: String; let format: String }
    struct ImageURLObj: Encodable { let url: String }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let urlStr):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageURLObj(url: urlStr), forKey: .image_url)
        case .inputAudio(let dataStr, let fmt):
            try container.encode("input_audio", forKey: .type)
            try container.encode(InputAudio(data: dataStr, format: fmt), forKey: .input_audio)
        case .video(let urls):
            try container.encode("video", forKey: .type)
            try container.encode(urls, forKey: .video)
        }
    }
}

private struct AnyEncodable: Encodable {
    let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

private struct ChatPayload: Encodable {
    struct Item: Encodable { let role: String; let content: [AnyEncodable] }
    let model: String
    let messages: [Item]
    let temperature: Double?
}

extension QwenService {
    func chat(text: String, audioURL: URL) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var content: [AnyEncodable] = []
        if !text.isEmpty { content.append(AnyEncodable(MessageContent.text(text))) }
        let data = try Data(contentsOf: audioURL)
        let base64 = data.base64EncodedString()
        let dataURI = "data:audio/m4a;base64,\(base64)"
        content.append(AnyEncodable(MessageContent.inputAudio(data: dataURI, format: "m4a")))
        let payload = ChatPayload(model: omniModel, messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: chat(audio), 模型=\(omniModel), 文本长度=\(text.count), 音频字节=\(data.count)")
        let (dataRes, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: dataRes, encoding: .utf8) ?? ""
        print("Qwen 返回: chat(audio), 状态=\(status), 字节数=\(dataRes.count)")
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            print("Qwen 错误响应预览: chat(audio)=\(preview)")
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        let res = try JSONDecoder().decode(ChatResponse.self, from: dataRes)
        let textOut = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: chat(audio)=\(textOut)")
        return textOut
    }
    
    func searchDiaries(query: String, diaryContext: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        你是一个智能日记助手。用户会向你提问，你需要基于用户的日记内容来回答问题。
        
        重要规则：
        1. 主要基于提供的日记内容回答问题。
        2. 如果日记中没有直接答案，可以基于日记中的事实进行合理的推测和分析，但必须在回答中说明这是推测。
        3. 如果完全无法从日记中推断出答案，请回答"不知道"。
        4. 回答要简洁、准确、有帮助。
        
        用户的日记内容：
        \(diaryContext)
        """
        
        let userMessage = "问题：\(query)"
        
        print("--- AI Search Prompt Begin ---")
        print(systemPrompt)
        print(userMessage)
        print("--- AI Search Prompt End ---")
        
        let content: [AnyEncodable] = [
            AnyEncodable(MessageContent.text(systemPrompt)),
            AnyEncodable(MessageContent.text(userMessage))
        ]
        let items: [ChatPayload.Item] = [.init(role: "user", content: content)]
        
        let payload = ChatPayload(model: textModel, messages: items, temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        
        print("Qwen 调用开始: searchDiaries, 模型=\(textModel), 查询长度=\(query.count), 日记上下文长度=\(diaryContext.count)")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: data, encoding: .utf8) ?? ""
        print("Qwen 返回: searchDiaries, 状态=\(status), 字节数=\(data.count)")
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            print("Qwen 错误响应预览: searchDiaries=\(preview)")
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: searchDiaries=\(text)")
        return text
    }
    func consult(query: String, context: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let now = Date().formatted(date: .numeric, time: .standard)
        let systemPrompt = """
        你是一个智能咨询助手。当前时间是：\(now)。
        用户会向你咨询问题，你需要结合用户的笔记内容（上下文）来回答。
        
        请输出 JSON 格式，包含以下字段：
        {
            "reply_content": "你的回答内容，可以使用 Markdown 格式",
            "source_notes": ["推测出回答的笔记标题1", "推测出回答的笔记标题2"]
        }
        
        如果回答不依赖任何笔记，source_notes 可以为空数组。
        
        用户的笔记上下文：
        \(context)
        """
        
        let userMessage = "用户咨询：\(query)"
        
        let content: [AnyEncodable] = [
            AnyEncodable(MessageContent.text(systemPrompt)),
            AnyEncodable(MessageContent.text(userMessage))
        ]
        let items: [ChatPayload.Item] = [.init(role: "user", content: content)]
        
        let payload = ChatPayload(model: textModel, messages: items, temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        
        print("Qwen 调用开始: consult, 模型=\(textModel)")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyPreview = String(data: data, encoding: .utf8) ?? ""
        
        if status != 200 {
            let preview = String(bodyPreview.prefix(300))
            if status == 401 { throw QwenError.unauthorized(preview) }
            if status == 402 { throw QwenError.paymentRequired(preview) }
            throw QwenError.httpError(status, preview)
        }
        
        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = res.choices.first?.message.content ?? ""
        print("Qwen 结果预览: consult=\(text)")
        return text
    }
}