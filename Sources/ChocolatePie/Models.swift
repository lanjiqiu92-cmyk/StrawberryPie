import Foundation

enum PieItemKind: String, CaseIterable, Identifiable, Codable {
    case idea
    case work
    case personal
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idea: return "灵感"
        case .work: return "工作待办"
        case .personal: return "个人待办"
        case .trash: return "垃圾桶"
        }
    }

    var shortTitle: String {
        switch self {
        case .idea: return "灵感"
        case .work: return "工作"
        case .personal: return "个人"
        case .trash: return "垃圾桶"
        }
    }

    var symbol: String {
        switch self {
        case .idea: return "sparkles"
        case .work: return "briefcase.fill"
        case .personal: return "heart.fill"
        case .trash: return "trash.fill"
        }
    }

    var supportsCompletion: Bool { self == .work || self == .personal }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if value == "todo" {
            self = .work
        } else if let kind = Self(rawValue: value) {
            self = kind
        } else {
            self = .idea
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PieItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var kind: PieItemKind
    let createdAt: Date
    var dueDate: Date?
    var expiresAt: Date?
    var isCompleted: Bool
    var aiSuggestion: String?

    init(
        id: UUID = UUID(),
        text: String,
        kind: PieItemKind,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        expiresAt: Date? = nil,
        isCompleted: Bool = false,
        aiSuggestion: String? = nil
    ) {
        self.id = id
        self.text = text
        self.kind = kind
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.expiresAt = expiresAt
        self.isCompleted = isCompleted
        self.aiSuggestion = aiSuggestion
    }
}

enum AIAction: String, CaseIterable {
    case clarify = "整理成一句话"
    case tasks = "拆成待办"
    case expand = "继续发散"
    case condenseWork = "巴旦木精简"
    case remindPersonal = "呱呱提醒"

    static let composerCases: [AIAction] = [.clarify, .tasks, .expand]

    var instruction: String {
        switch self {
        case .clarify:
            return "保留原意，把这段碎片想法整理成一句清楚、自然、可回看的中文。只输出结果。"
        case .tasks:
            return "把这段想法拆成 2 到 5 个明确、轻量、可执行的中文待办。每行一个，以「○ 」开头。"
        case .expand:
            return "围绕这段灵感给出 3 个有价值但不过度发散的延伸方向。保持简洁，每行一个。"
        case .condenseWork:
            return "这是一个工作待办。删除口头语、背景废话和重复信息，只保留明确的动作、对象与必要条件；不要编造日期或新任务。尽量控制在 24 个汉字以内，只输出一条精简后的待办。"
        case .remindPersonal:
            return "这是一个个人生活待办。把它改写成一句温柔、可爱但不腻的猫猫提醒，让人看完愿意行动；保留原意，不制造压力，不编造时间。尽量控制在 32 个汉字以内，只输出提醒文案。"
        }
    }
}

enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case deepSeek
    case qwen
    case kimi
    case openAI
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .qwen: return "千问 · 阿里云百炼"
        case .kimi: return "Kimi · 月之暗面"
        case .openAI: return "OpenAI"
        case .custom: return "自定义兼容接口"
        }
    }

    var shortTitle: String {
        switch self {
        case .qwen: return "千问"
        case .kimi: return "Kimi"
        case .custom: return "自定义"
        default: return title
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepSeek: return "https://api.deepseek.com"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .kimi: return "https://api.moonshot.cn/v1"
        case .openAI: return "https://api.openai.com/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .deepSeek: return "deepseek-chat"
        case .qwen: return "qwen-plus"
        case .kimi: return "kimi-k2.6"
        case .openAI: return "gpt-5.6-luna"
        case .custom: return ""
        }
    }

    var usesResponsesAPI: Bool { self == .openAI }
}
