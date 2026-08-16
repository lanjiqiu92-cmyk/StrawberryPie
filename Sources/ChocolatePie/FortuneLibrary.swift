import Foundation

struct FortuneCopy: Codable, Hashable, Sendable {
    let title: String
    let message: String
    let footer: String
    let emoji: String
}

enum FortuneLibrary {
    private static let cacheKey = "fortune.weekly.deck.v1"
    private static let lastSuccessKey = "fortune.weekly.lastSuccess"
    private static let lastAttemptKey = "fortune.weekly.lastAttempt"
    private static let week: TimeInterval = 7 * 24 * 60 * 60
    private static let retryDelay: TimeInterval = 24 * 60 * 60

    static var current: [FortuneCopy] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([FortuneCopy].self, from: data),
              cached.count >= 100 else {
            return FortuneSeedDeck.all
        }
        return cached
    }

    static var sourceLabel: String {
        if UserDefaults.standard.object(forKey: lastSuccessKey) != nil {
            return "DeepSeek 本周猫猫签 · \(current.count) 条"
        }
        return "离线猫猫签 · \(current.count) 条"
    }

    static func refreshIfNeeded(force: Bool = false) async {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "ai.provider") == AIProvider.deepSeek.rawValue else { return }

        let now = Date()
        if !force,
           let lastSuccess = defaults.object(forKey: lastSuccessKey) as? Date,
           now.timeIntervalSince(lastSuccess) < week {
            return
        }
        if !force,
           let lastAttempt = defaults.object(forKey: lastAttemptKey) as? Date,
           now.timeIntervalSince(lastAttempt) < retryDelay {
            return
        }

        defaults.set(now, forKey: lastAttemptKey)
        do {
            let generated = try await AIService.shared.generateWeeklyFortunes(count: 100)
            let cleaned = validated(generated)
            guard cleaned.count >= 100,
                  let data = try? JSONEncoder().encode(Array(cleaned.prefix(100))) else { return }
            defaults.set(data, forKey: cacheKey)
            defaults.set(now, forKey: lastSuccessKey)
        } catch {
            // The bundled deck remains fully usable when the model or network is unavailable.
        }
    }

    private static func validated(_ fortunes: [FortuneCopy]) -> [FortuneCopy] {
        var seen = Set<String>()
        return fortunes.compactMap { fortune in
            let title = fortune.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = fortune.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let footer = fortune.footer.trimmingCharacters(in: .whitespacesAndNewlines)
            let emoji = fortune.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !message.isEmpty, !footer.isEmpty,
                  message.count <= 42, footer.count <= 32,
                  seen.insert(message).inserted else { return nil }
            return FortuneCopy(title: title, message: message, footer: footer, emoji: emoji.isEmpty ? "🐱✨" : emoji)
        }
    }
}

private enum FortuneSeedDeck {
    private static let messages = [
        "今天的你可又不得了地好看了！",
        "快起来走走！要不然屁股要扁了！！",
        "今天可以努力，但不许偷偷把自己榨干。",
        "你脑袋里那个怪想法，可能真有点东西。",
        "再忙也要好好吃饭，不许拿咖啡冒充午餐。",
        "今天会有一件小事，偷偷站在你这边。",
        "不想答应的事情，可以晚一点再回答。",
        "今晚早点睡，世界不会趁你睡着偷偷上市。",
        "你已经处理了很多事，只是自己没认真数过。",
        "合理摸鱼不是偷懒，是给脑子偷偷充电。",
        "去喝口水。对，就是现在，别假装没看见。",
        "别等完美开场，先做一个丑丑的第一步。",
        "今天适合把烦恼缩小，把快乐放大一点。",
        "你可以慢慢来，猫猫又没有拿秒表催你。",
        "有些事做到六十分，就已经很会生活了。",
        "今天拒绝精神内耗，谁的锅谁自己背好。",
        "你不是没进度，你只是在悄悄蓄力。",
        "先伸个懒腰，灵魂可能还卡在椅子缝里。",
        "别皱眉啦，再皱猫猫要来熨平了。",
        "今天的好运正在路上，就是走得有点猫步。",
        "允许自己笨拙一点，可爱的人不用事事熟练。",
        "先把最讨厌的那件小事啃掉一口。",
        "你的情绪不是麻烦，是今天需要照顾的小动物。",
        "别偷偷否定自己，猫猫刚刚投了赞成票。",
        "今天宜清空脑袋，不宜塞满别人的期待。",
        "去看看窗外，天空没有 KPI。",
        "这件事没那么吓人，先给它起个小名。",
        "今天可以不厉害，只要诚实地活着就好。",
        "你值得一顿热乎乎的饭和一个不赶时间的晚上。",
        "先完成一件，剩下的交给明天那个更聪明的你。",
        "别把所有人的期待都背回家，猫猫嫌沉。",
        "今天的你无需证明，存在本身就很有分量。",
        "卡住的时候先站起来，答案可能压在屁股下面。",
        "你的努力没有消失，只是还没来得及开花。",
        "今天请把自己放在待办清单的第一行。",
        "做不完也没关系，月亮每天都留一点没照完。",
        "允许计划拐个弯，猫猫走路也不是直线。",
        "今天适合夸自己，理由可以稍后再补。",
        "不要和昨天的自己打架，它已经下班了。",
        "你的小进步正在排队，马上就轮到它亮相。",
        "先呼吸三次，再决定要不要为这件事生气。",
        "今天不许把别人的坏脸色装进自己的口袋。",
        "你有权把不重要的事，轻轻放回地上。",
        "灵感不必完整，露个耳朵就先抓住它。",
        "累了不是失败，是身体发来的猫猫通知。",
        "今天少想一点别人怎么看，多想一口吃什么。",
        "你不是拖延，你只是在等一个可爱的启动仪式。",
        "把手机放远五分钟，让眼睛去散个步。",
        "今天最重要的任务：别对自己太凶。",
        "有些答案睡一觉会自己长出来。",
        "先做能做的那一厘米，也算向前。",
        "今天的麻烦看起来很大，其实可能只是毛比较蓬。",
        "放心，你的可爱没有因为犯错而扣分。",
        "把肩膀放下来，它们今天没领加班费。",
        "不开心可以写下来，别让它在脑袋里交房租。",
        "今天适合说一句：这事儿先到这儿吧。",
        "你的节奏没有错，只是和别人不一样。",
        "请领取今日份理直气壮的小休息。",
        "别急着赶路，鞋带和心情都可以先系好。",
        "今天会遇见一点甜，可能藏在很普通的地方。",
        "你已经很好了，改进只是锦上添猫。",
        "先把桌面收出一小块，给好运留个座位。",
        "今天不做情绪客服，下班后概不接单。",
        "你可以改变主意，这不叫反复，叫更新版本。",
        "小小地期待一下吧，生活偶尔会偷偷加彩蛋。",
        "现在去洗把脸，重新加载一下今天。",
        "别因为走得慢，就怀疑自己走错了。",
        "今天的烦恼先寄存，取件码猫猫弄丢了。",
        "做完这件事，就奖励自己发两分钟呆。",
        "你不需要随时积极，电量低也可以安静待机。",
        "今天把一句‘我不想’说得小声但清楚。",
        "你认真生活的样子，已经被猫猫截图保存。",
        "先别预演最坏结果，导演今天请假了。",
        "给自己留一点空白，灵感才有地方坐下。",
        "今天宜晒太阳，顺便晾一晾潮湿的心情。",
        "别拿放大镜看缺点，猫猫要拿去照罐头。",
        "你可以求助，英雄偶尔也需要代班猫。",
        "今天只解决今天的问题，未来的先排队。",
        "喝水、眨眼、松肩，你的身体在催三个小待办。",
        "那些没说出口的委屈，猫猫允许它们冒个泡。",
        "你不是敏感，只是接收器调得比较清楚。",
        "今天少一点应该，多一点我愿意。",
        "工作不会跑，但你的晚饭真的会凉。",
        "先完成最小版本，漂亮可以留给第二遍。",
        "请相信那个偷偷坚持了很久的自己。",
        "今天的你有点累，但依然非常值得喜欢。",
        "把复杂的事切成小块，猫猫负责叼走边角料。",
        "不必每次都赢，别每次都委屈自己就好。",
        "今天给脑子关一个窗口，风才能吹进来。",
        "你可以先开心，再慢慢想清楚原因。",
        "别催花开，先给自己浇点水。",
        "今天若有尴尬，就当宇宙在加笑点。",
        "你做出的选择，已经是当时最勇敢的版本。",
        "把今天过小一点，也会更容易抱住。",
        "先别自责，猫猫要检查证据是否充分。",
        "今天适合偷偷得意一下，不用写汇报。",
        "你值得被温柔对待，尤其是被自己。",
        "起身活动两分钟，顺便把坏心情抖掉。",
        "没灵感也没关系，空白页正在深呼吸。",
        "今天就算只照顾好自己，也是一项大工程。"
    ]

    private static let titles = [
        "漂亮签", "屁股保卫签", "别卷签", "灵感签", "吃饭签",
        "好运签", "拒绝签", "睡觉签", "夸夸签", "摸鱼签",
        "喝水签", "行动签", "松一口气签", "慢慢来签", "边界签",
        "充电签", "太阳签", "小勇气签", "清醒签", "抱抱签"
    ]

    private static let footers = [
        "猫猫批准你多照两次镜子。", "现在就动一动，猫猫替你看电脑。", "完成最重要的一件就很厉害。",
        "先记下来，不许急着嘲笑自己。", "猫猫已经把碗推到你面前了。", "留意那些不起眼的顺利。",
        "沉默五分钟也算一种边界。", "猫猫今晚替你值夜班。", "今天允许骄傲三分钟。",
        "看窗外两分钟，回来再继续。", "喝完水再回来领奖励。", "第一步走完，后面会自己长出来。",
        "先松开肩膀，事情不会因此跑掉。", "慢一点也算是在认真前进。", "不属于你的任务，放回原处。",
        "电量不足时，可爱也可以省电。", "去晒一小块太阳吧。", "猫猫给你的勇气盖了章。",
        "先照顾事实，再照顾想象。", "今天也要站在自己这边。"
    ]

    private static let emojis = ["🐱✨", "🍑🐾", "😼☕️", "💡🐱", "🍚🐈", "🍀🐾", "🙅🐱", "🌙😺", "🏆🐱", "🐟😼", "💧🐱", "🚀🐾"]

    static let all: [FortuneCopy] = messages.enumerated().map { index, message in
        FortuneCopy(
            title: titles[index % titles.count],
            message: message,
            footer: footers[(index * 7) % footers.count],
            emoji: emojis[(index * 5) % emojis.count]
        )
    }
}
