import Foundation

struct WellnessReminderCopy: Codable, Hashable, Sendable {
    let title: String
    let message: String
    let footer: String
    let emoji: String
    let category: String?

    init(title: String, message: String, footer: String, emoji: String, category: String? = nil) {
        self.title = title
        self.message = message
        self.footer = footer
        self.emoji = emoji
        self.category = category
    }
}

enum ReminderLibrary {
    private static let cacheKey = "reminder.weekly.deck.v2"
    private static let lastSuccessKey = "reminder.weekly.lastSuccess.v2"
    private static let lastAttemptKey = "reminder.weekly.lastAttempt.v2"
    private static let week: TimeInterval = 7 * 24 * 60 * 60
    private static let retryDelay: TimeInterval = 24 * 60 * 60

    static var current: [WellnessReminderCopy] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([WellnessReminderCopy].self, from: data),
              cached.count >= 60 else {
            return ReminderSeedDeck.all
        }
        return cached
    }

    static var sourceLabel: String {
        if UserDefaults.standard.object(forKey: lastSuccessKey) != nil {
            return "DeepSeek 本周提醒 · \(current.count) 条"
        }
        return "离线猫猫提醒 · \(current.count) 条"
    }

    static func random() -> WellnessReminderCopy {
        let defaults = UserDefaults.standard
        let deck = current
        let previous = defaults.integer(forKey: "reminder.lastIndex")
        let candidates = deck.indices.filter { $0 != previous }
        let index = candidates.randomElement() ?? 0
        defaults.set(index, forKey: "reminder.lastIndex")
        return deck[index]
    }

    static func refreshIfNeeded(force: Bool = false) async {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "ai.provider") == AIProvider.deepSeek.rawValue else { return }

        let now = Date()
        if !force,
           let lastSuccess = defaults.object(forKey: lastSuccessKey) as? Date,
           now.timeIntervalSince(lastSuccess) < week { return }
        if !force,
           let lastAttempt = defaults.object(forKey: lastAttemptKey) as? Date,
           now.timeIntervalSince(lastAttempt) < retryDelay { return }

        defaults.set(now, forKey: lastAttemptKey)
        do {
            let generated = try await AIService.shared.generateWeeklyReminders(count: 60)
            let cleaned = validated(generated)
            guard cleaned.count >= 60,
                  let data = try? JSONEncoder().encode(Array(cleaned.prefix(60))) else { return }
            defaults.set(data, forKey: cacheKey)
            defaults.set(now, forKey: lastSuccessKey)
        } catch {
            // The bundled reminders remain available when the model or network is unavailable.
        }
    }

    private static func validated(_ copies: [WellnessReminderCopy]) -> [WellnessReminderCopy] {
        var seen = Set<String>()
        let allowedCategories: Set<String> = ["喝水", "厕所", "走动", "腰背", "眼睛", "肩颈", "呼吸", "吃饭", "离屏"]
        return copies.compactMap { copy in
            let title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = copy.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let footer = copy.footer.trimmingCharacters(in: .whitespacesAndNewlines)
            let emoji = copy.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = copy.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !message.isEmpty, !footer.isEmpty,
                  title.count <= 12, message.count <= 36, footer.count <= 28,
                  allowedCategories.contains(category),
                  seen.insert(message).inserted else { return nil }
            return WellnessReminderCopy(title: title, message: message, footer: footer, emoji: emoji.isEmpty ? "🐱🔔" : emoji, category: category)
        }
    }
}

private enum ReminderSeedDeck {
    private static let entries: [(String, String, String, String)] = [
        ("水杯点名", "快去喝水！杯子都快以为自己失业了。", "喝完再回来，猫猫替你守着。", "💧🐱"),
        ("厕所通行证", "快去上厕所，不许让膀胱继续参加加班。", "这不是摸鱼，是基本维护。", "🚽🐾"),
        ("屁股保卫战", "快起来走走，要不然屁股真的要扁啦！", "巡视两分钟就算完成。", "🍑🐈"),
        ("老腰报警", "起身伸伸腰，保护一下陪你奋斗的老腰。", "慢慢伸，不许猛拧。", "🧘🐱"),
        ("眼睛放风", "看向远处二十秒，让眼睛出去遛一圈。", "窗外没有 KPI。", "👀☁️"),
        ("肩膀下班", "把肩膀放下来，它们今天没领加班费。", "耸肩三次，再慢慢呼气。", "😌🐾"),
        ("眨眼任务", "你是不是又忘记眨眼了？现在连眨十下。", "眼睛需要自己的小雨天。", "🌧️😺"),
        ("补水突袭", "猫猫突击检查：水杯里还有水吗？", "没有就去续杯，立刻。", "🥤🐈"),
        ("站立加载", "请站起来重新加载一下你的下半身。", "加载时间：两分钟。", "🔄🐱"),
        ("脖子松绑", "轻轻左右看看，别让脖子焊死在屏幕前。", "动作小一点，舒服最重要。", "🦒🐾"),
        ("呼吸补丁", "吸气四拍、呼气六拍，给脑袋打个补丁。", "重复三次就可以。", "🌬️😺"),
        ("午饭侦察", "认真想想下一顿吃什么，咖啡不算正餐。", "身体不是永动机。", "🍚🐱"),
        ("窗边巡逻", "去窗边站一会儿，检查今天的天空。", "猫猫批准你发两分钟呆。", "☁️🐈"),
        ("手腕休息", "松开鼠标，甩甩手腕，手指也要下班。", "轻轻转两圈就好。", "🖐️🐾"),
        ("坐姿纠察", "屁股坐稳、背靠好，别把自己叠成问号。", "老腰向你发来感谢信。", "❓😼"),
        ("水分充值", "你的可爱电量还行，水分电量有点危险。", "去喝几大口再继续。", "🔋💧"),
        ("洗脸重启", "去洗把脸吧，把今天重新启动一次。", "冷水不用太猛。", "🫧🐱"),
        ("脚踝开会", "转转脚踝，让沉默半天的双脚发个言。", "左右各五圈。", "🦶🐾"),
        ("阳光领取", "如果外面有太阳，去领取一小块。", "晒不到也可以看看亮处。", "☀️😺"),
        ("手机流放", "把手机放远五分钟，让眼睛和脑袋清净会儿。", "猫猫担任临时保安。", "📵🐈"),
        ("深呼吸啦", "先别急，吸一大口气，再慢慢吐干净。", "事情不会趁你呼吸时逃跑。", "🍃🐱"),
        ("腰背伸展", "双手向上伸个大懒腰，别委屈你的后背。", "伸到舒服，不是伸到比赛。", "🙆🐾"),
        ("水杯召唤", "听见了吗？你的水杯正在小声叫你。", "去回应一下它。", "🔔🥤"),
        ("厕所别憋", "该去厕所就去，工作不会趁机偷偷上市。", "猫猫替你按住进度条。", "🚪😺"),
        ("散步两分", "站起来在房间里晃两圈，假装巡视领地。", "领地安全，你也活动到了。", "🚶🐈"),
        ("远眺模式", "把视线从屏幕搬到六米外，住二十秒。", "眼睛也要换换房间。", "🏞️🐱"),
        ("松开下巴", "别咬紧牙啦，把下巴轻轻放松。", "脸也不负责扛 KPI。", "😮‍💨🐾"),
        ("今日体检", "喝水了吗？走路了吗？厕所去了吗？", "任选一项，现在补交。", "🩺😼"),
        ("椅子放假", "让椅子独处两分钟，你起来溜达一下。", "它不会因为想你而哭。", "🪑🐱"),
        ("脑袋透气", "去门口或窗边换一口空气，脑袋快冒烟啦。", "回来可能就没那么卡了。", "💨🐈"),
        ("颈椎来信", "颈椎说它想换个姿势，请你现在批准。", "抬头、收下巴、慢慢转动。", "💌🐾"),
        ("小口补给", "喝三大口水，不许只抿一下糊弄猫猫。", "一、二、三，验收！", "3️⃣💧"),
        ("身体点名", "从头到脚感受一下，哪里最想被照顾？", "先照顾最吵的那个地方。", "🫶🐱"),
        ("屏幕暂停", "离开屏幕一分钟，世界不会因此停服。", "闭眼也算完成。", "⏸️😺"),
        ("别缩成团", "展开肩背坐好，你不是电脑前的一颗虾米。", "虾米今天也要舒展。", "🦐🐈"),
        ("补给时间", "水、厕所、走动，身体请你三选一。", "选完就去，不许开会。", "🎯🐾")
    ]

    static let all = entries.map {
        WellnessReminderCopy(title: $0.0, message: $0.1, footer: $0.2, emoji: $0.3)
    }
}
