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

    func chat(prompt: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw QwenError.missingAPIKey }
        if key.uppercased().contains("YOUR_OPENROUTER_API_KEY") { throw QwenError.invalidAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let content: [AnyEncodable] = [AnyEncodable(MessageContent.text(prompt))]
        let items: [ChatPayload.Item] = [.init(role: "user", content: content)]
        
        let payload = ChatPayload(model: "qwen3-omni-flash", messages: items, temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)

        print("Qwen 调用开始: chat, 模型=qwen3-omni-flash, 文本长度=\(prompt.count)")

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
        let payload = ChatPayload(model: "qwen3-omni-flash", messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: describeImages, 模型=qwen3-omni-flash, 图片数=\(datas.count), 大小=\(datas.map{ $0.count })")
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
        let payload = ChatPayload(model: "qwen3-omni-flash", messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: analyzeImagesJSON, 模型=qwen3-omni-flash, 图片数=\(datas.count)")
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
        let payload = ChatPayload(model: "qwen3-omni-flash", messages: [ChatPayload.Item(role: "user", content: content)], temperature: 0.2)
        req.httpBody = try JSONEncoder().encode(payload)
        print("Qwen 调用开始: chat(audio), 模型=qwen3-omni-flash, 文本长度=\(text.count), 音频字节=\(data.count)")
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
}