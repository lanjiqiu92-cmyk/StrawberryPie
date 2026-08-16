import Foundation
import Security
import Combine
import LocalAuthentication

enum AIServiceError: LocalizedError {
    case missingKey
    case invalidConfiguration
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "先在设置里连接一个 AI 模型服务。"
        case .invalidConfiguration: return "接口地址或模型名称还没有填写完整。"
        case .invalidResponse: return "AI 返回的内容有点奇怪，请再试一次。"
        case .api(let message): return message
        }
    }
}

struct AIConfiguration: Sendable {
    let provider: AIProvider
    let baseURL: String
    let model: String
    let apiKey: String
}

@MainActor
final class AISettingsStore: ObservableObject {
    @Published var provider: AIProvider
    @Published var baseURL: String
    @Published var model: String
    @Published var apiKey: String = ""
    @Published var statusMessage: String = ""
    @Published var isTesting = false
    @Published private(set) var hasSavedKey: Bool
    @Published private(set) var isSaving = false

    private let defaults = UserDefaults.standard

    init() {
        let stored = UserDefaults.standard.string(forKey: "ai.provider")
        let initial: AIProvider
        initial = stored.flatMap(AIProvider.init(rawValue:)) ?? .deepSeek
        provider = initial
        baseURL = UserDefaults.standard.string(forKey: "ai.\(initial.rawValue).baseURL") ?? initial.defaultBaseURL
        model = UserDefaults.standard.string(forKey: "ai.\(initial.rawValue).model") ?? initial.defaultModel
        hasSavedKey = UserDefaults.standard.bool(forKey: Self.keyHintName(for: initial))
    }

    func select(_ newProvider: AIProvider) {
        baseURL = defaults.string(forKey: "ai.\(newProvider.rawValue).baseURL") ?? newProvider.defaultBaseURL
        model = defaults.string(forKey: "ai.\(newProvider.rawValue).model") ?? newProvider.defaultModel
        hasSavedKey = defaults.bool(forKey: Self.keyHintName(for: newProvider))
        apiKey = ""
        statusMessage = ""
    }

    @discardableResult
    func save() async -> Bool {
        let cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanURL.isEmpty, !cleanModel.isEmpty else {
            statusMessage = "请补全接口地址和模型名称。"
            return false
        }

        defaults.set(provider.rawValue, forKey: "ai.provider")
        defaults.set(cleanURL, forKey: "ai.\(provider.rawValue).baseURL")
        defaults.set(cleanModel, forKey: "ai.\(provider.rawValue).model")

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            isSaving = true
            let selectedProvider = provider
            let saved = await Task.detached(priority: .userInitiated) {
                KeychainStore.save(cleanKey, for: selectedProvider)
            }.value
            isSaving = false
            guard saved else {
                statusMessage = "Key 没有保存成功，请再试一次。"
                return false
            }
            apiKey = ""
            hasSavedKey = true
            defaults.set(true, forKey: Self.keyHintName(for: selectedProvider))
        }

        statusMessage = hasSavedKey ? "已安全保存" : "配置已保存，还需要填写 API Key。"
        if provider == .deepSeek && hasSavedKey {
            Task {
                await FortuneLibrary.refreshIfNeeded(force: true)
                await ReminderLibrary.refreshIfNeeded(force: true)
            }
        }
        return true
    }

    func configuration(useDraftKey: Bool = false) async -> AIConfiguration? {
        let draftKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedProvider = provider
        let key: String
        if useDraftKey && !draftKey.isEmpty {
            key = draftKey
        } else {
            key = await Task.detached(priority: .userInitiated) {
                KeychainStore.load(for: selectedProvider) ?? ""
            }.value
            if !key.isEmpty {
                hasSavedKey = true
                defaults.set(true, forKey: Self.keyHintName(for: selectedProvider))
            }
        }
        guard !key.isEmpty else { return nil }
        return AIConfiguration(provider: provider, baseURL: baseURL, model: model, apiKey: key)
    }

    static func hasConfiguredProvider() -> Bool {
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: "ai.provider").flatMap(AIProvider.init(rawValue:)) ?? .deepSeek
        return defaults.bool(forKey: keyHintName(for: provider))
    }

    static func activeConfiguration() async -> AIConfiguration? {
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: "ai.provider").flatMap(AIProvider.init(rawValue:)) ?? .deepSeek
        let baseURL = defaults.string(forKey: "ai.\(provider.rawValue).baseURL") ?? provider.defaultBaseURL
        let model = defaults.string(forKey: "ai.\(provider.rawValue).model") ?? provider.defaultModel
        guard let key = await Task.detached(priority: .userInitiated, operation: {
            KeychainStore.load(for: provider)
        }).value, !key.isEmpty else { return nil }
        defaults.set(true, forKey: keyHintName(for: provider))
        return AIConfiguration(provider: provider, baseURL: baseURL, model: model, apiKey: key)
    }

    private static func keyHintName(for provider: AIProvider) -> String {
        "ai.\(provider.rawValue).hasSavedKey"
    }
}

struct AIService {
    static let shared = AIService()

    func respond(to text: String, action: AIAction, configuration: AIConfiguration? = nil) async throws -> String {
        let resolvedConfiguration: AIConfiguration?
        if let configuration {
            resolvedConfiguration = configuration
        } else {
            resolvedConfiguration = await AISettingsStore.activeConfiguration()
        }

        guard let configuration = resolvedConfiguration else {
            throw AIServiceError.missingKey
        }

        let cleanBaseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBaseURL.isEmpty, !cleanModel.isEmpty else {
            throw AIServiceError.invalidConfiguration
        }

        let endpoint = try endpointURL(for: configuration.provider, baseURL: cleanBaseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let persona: String
        switch action {
        case .condenseWork:
            persona = "你是草莓派里的灰白短毛猫巴旦木，行动派，擅长删掉工作废话、找到第一步。"
        case .remindPersonal:
            persona = "你是草莓派里的乳白色长毛猫呱呱，生活派，温柔但不唠叨，擅长提醒主人照顾自己。"
        default:
            persona = "你是草莓派里的灵感整理助手，由巴旦木和呱呱一起值班。"
        }
        let systemPrompt = "\(persona)温和、直接、克制，不说套话。\(action.instruction)"
        let body: [String: Any]

        if configuration.provider.usesResponsesAPI {
            body = [
                "model": cleanModel,
                "instructions": systemPrompt,
                "input": text,
                "store": false,
                "max_output_tokens": 500,
                "text": ["verbosity": "low"],
                "safety_identifier": SafetyIdentifier.value
            ]
        } else {
            body = [
                "model": cleanModel,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": text]
                ],
                "max_tokens": 500,
                "stream": false
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if !(200...299).contains(http.statusCode) {
            let error = (json?["error"] as? [String: Any])?["message"] as? String
            throw AIServiceError.api(error ?? "AI 暂时没连上，内容仍然可以正常保存。")
        }

        if configuration.provider.usesResponsesAPI {
            return try parseResponsesAPI(json)
        }
        return try parseChatCompletions(json)
    }

    func generateWeeklyFortunes(count: Int) async throws -> [FortuneCopy] {
        guard let configuration = await AISettingsStore.activeConfiguration() else {
            throw AIServiceError.missingKey
        }
        guard configuration.provider == .deepSeek else {
            throw AIServiceError.api("每周猫猫签目前使用 DeepSeek 更新。")
        }

        let endpoint = try endpointURL(for: configuration.provider, baseURL: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        你是草莓派里的猫猫签文编辑。话风可爱、机灵、温柔，偶尔有一点轻微吐槽；不油腻、不说教、不制造焦虑。每条签文都要明显不同，覆盖夸夸、休息、喝水、走动、工作边界、灵感、吃饭、睡觉、情绪、好运和小行动等生活场景。
        """
        let userPrompt = """
        生成 \(count) 条中文猫猫签文。严格只返回 JSON：{"fortunes":[{"title":"四到八字签名","message":"主文案，不超过42字","footer":"可爱的小补充，不超过32字","emoji":"1到2个emoji"}]}。fortunes 必须正好 \(count) 条，message 不得重复，不使用 Markdown 代码块。
        """
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 8_000,
            "temperature": 0.95,
            "stream": false,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if !(200...299).contains(http.statusCode) {
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            throw AIServiceError.api(message ?? "猫猫签本周更新失败，继续使用本地签文。")
        }

        let content = try parseChatCompletions(json)
        guard let contentData = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WeeklyFortunePayload.self, from: contentData) else {
            throw AIServiceError.invalidResponse
        }
        return payload.fortunes
    }

    func generateWeeklyReminders(count: Int) async throws -> [WellnessReminderCopy] {
        guard let configuration = await AISettingsStore.activeConfiguration() else {
            throw AIServiceError.missingKey
        }
        guard configuration.provider == .deepSeek else {
            throw AIServiceError.api("每周猫猫提醒目前使用 DeepSeek 更新。")
        }

        let endpoint = try endpointURL(for: configuration.provider, baseURL: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        你是草莓派里的健康提醒猫。文案要可爱、机灵、短促、有行动感，偶尔轻微吐槽，但不油腻、不训人、不制造健康焦虑。内容只覆盖适合办公间隙的小提醒：喝水、上厕所、起身走动、腰背舒展、眼睛远眺、眨眼、放松肩颈、深呼吸、正常吃饭和短暂离屏。不要给医疗诊断或治疗建议。
        """
        let userPrompt = """
        生成 \(count) 条中文定时提醒。严格只返回 JSON：{"reminders":[{"title":"2到6字小标题","message":"可爱直接的提醒，不超过36字","footer":"小补充，不超过28字","emoji":"1到2个emoji","category":"喝水|厕所|走动|腰背|眼睛|肩颈|呼吸|吃饭|离屏之一"}]}。category 必须严格取九个允许值之一；reminders 必须正好 \(count) 条，message 不得重复，各分类尽量均衡，不使用 Markdown 代码块。
        """
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 6_000,
            "temperature": 0.95,
            "stream": false,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if !(200...299).contains(http.statusCode) {
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            throw AIServiceError.api(message ?? "猫猫提醒本周更新失败，继续使用本地文案。")
        }

        let content = try parseChatCompletions(json)
        guard let contentData = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WeeklyReminderPayload.self, from: contentData) else {
            throw AIServiceError.invalidResponse
        }
        return payload.reminders
    }

    private func endpointURL(for provider: AIProvider, baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = provider.usesResponsesAPI ? "/responses" : "/chat/completions"
        if trimmed.hasSuffix(path) {
            guard let url = URL(string: trimmed) else { throw AIServiceError.invalidConfiguration }
            return url
        }
        guard let url = URL(string: trimmed + path) else { throw AIServiceError.invalidConfiguration }
        return url
    }

    private func parseResponsesAPI(_ json: [String: Any]?) throws -> String {
        guard let output = json?["output"] as? [[String: Any]] else {
            throw AIServiceError.invalidResponse
        }
        for item in output where item["type"] as? String == "message" {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            if let text = content.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        throw AIServiceError.invalidResponse
    }

    private func parseChatCompletions(_ json: [String: Any]?) throws -> String {
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct WeeklyFortunePayload: Decodable {
    let fortunes: [FortuneCopy]
}

private struct WeeklyReminderPayload: Decodable {
    let reminders: [WellnessReminderCopy]
}

enum KeychainStore {
    private static let service = "com.qiu.chocolatepie"

    static func save(_ value: String, for provider: AIProvider) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account: account(for: provider))
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func load(for provider: AIProvider) -> String? {
        if let value = load(account: account(for: provider)) { return value }
        if provider == .openAI { return load(account: "openai-api-key") }
        return nil
    }

    private static func account(for provider: AIProvider) -> String {
        "api-key-\(provider.rawValue)"
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func load(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        // Never let a stale keychain ACL display a hidden authorization prompt.
        // The caller runs off the main actor, and a denied item should fail fast.
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum SafetyIdentifier {
    static var value: String {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: "safetyIdentifier") { return value }
        let value = "desktop-\(UUID().uuidString.lowercased())"
        defaults.set(value, forKey: "safetyIdentifier")
        return value
    }
}
