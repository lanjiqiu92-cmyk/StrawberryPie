import Foundation

struct ActionEgg: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let message: String
    let footer: String
    let emoji: String
}

struct CatOutfit: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let message: String
}

enum GachaPlayDeck {
    static let actions: [ActionEgg] = [
        .init(id: 0, title: "屁股保卫行动", message: "站起来走两分钟，假装巡视自己的领地。", footer: "走完回来，猫猫给你盖章。", emoji: "🍑🐾"),
        .init(id: 1, title: "一口任务", message: "挑最烦的工作，只做它的第一小步。", footer: "只许做一口，不许偷偷加餐。", emoji: "🧩🐱"),
        .init(id: 2, title: "喝水行动", message: "现在去喝一整杯水，再回来继续。", footer: "猫猫会替你盯住光标。", emoji: "💧😺"),
        .init(id: 3, title: "窗边放风", message: "看窗外两分钟，找三样正在动的东西。", footer: "天空今天没有 KPI。", emoji: "☁️🐈"),
        .init(id: 4, title: "桌面救援", message: "只收拾出一个巴掌大的干净区域。", footer: "给好运腾一块坐垫。", emoji: "🧹🐾"),
        .init(id: 5, title: "肩膀下班", message: "耸肩、放松，重复三次，再慢慢呼气。", footer: "肩膀今天没领加班费。", emoji: "😌🐱"),
        .init(id: 6, title: "消息断舍离", message: "关掉一个现在不需要看的通知。", footer: "世界可以晚五分钟找到你。", emoji: "🔕😼"),
        .init(id: 7, title: "夸夸任务", message: "写下一件今天已经做好的小事。", footer: "小事也配拥有庆功宴。", emoji: "🏆🐾"),
        .init(id: 8, title: "拒绝练习", message: "把一句不想答应的话，先写成草稿。", footer: "不用发送，先听见自己。", emoji: "🙅🐱"),
        .init(id: 9, title: "眼睛散步", message: "把视线移到六米外，坚持二十秒。", footer: "眼睛也需要出去遛一圈。", emoji: "👀🐈"),
        .init(id: 10, title: "晚饭侦察", message: "现在决定下一顿要认真吃什么。", footer: "禁止咖啡冒充正餐。", emoji: "🍚😺"),
        .init(id: 11, title: "灵感捕捉", message: "记下一句最近反复冒出来的怪想法。", footer: "先抓住耳朵，身体以后再补。", emoji: "💡🐾"),
        .init(id: 12, title: "三分钟开机", message: "给一个拖延任务计时三分钟，只负责开始。", footer: "铃响就可以理直气壮地停。", emoji: "⏱️🐱"),
        .init(id: 13, title: "空气刷新", message: "打开窗或走到门口，换一口新鲜空气。", footer: "重新加载一下脑袋。", emoji: "🍃😺"),
        .init(id: 14, title: "好友投递", message: "给喜欢的人发一个不需要回复的表情。", footer: "小小地证明你想到了对方。", emoji: "💌🐈"),
        .init(id: 15, title: "手机流放", message: "把手机放到够不到的地方五分钟。", footer: "猫猫担任临时保安。", emoji: "📵😼"),
        .init(id: 16, title: "身体点名", message: "从头到脚感受一遍哪里最需要放松。", footer: "身体不是载具，是你的队友。", emoji: "🫶🐾"),
        .init(id: 17, title: "完成定义", message: "给手头任务写一句‘做到什么算结束’。", footer: "不许让终点偷偷往后跑。", emoji: "🏁🐱"),
        .init(id: 18, title: "甜味侦察", message: "找一件今天值得期待的小事。", footer: "再小也算生活塞的糖。", emoji: "🍬😺"),
        .init(id: 19, title: "脑袋清仓", message: "把脑中最吵的一句话扔进灵感或垃圾桶。", footer: "不许它继续免费住着。", emoji: "🗑️🐈")
    ]

    static let outfits: [CatOutfit] = [
        .init(id: "crown", name: "领地主人皇冠", emoji: "👑", message: "戴上它，今天谁都不许小看两位主子。"),
        .init(id: "sunglasses", name: "摸鱼墨镜", emoji: "🕶️", message: "看不见 KPI，KPI 就暂时不存在。"),
        .init(id: "ribbon", name: "今日漂亮蝴蝶结", emoji: "🎀", message: "可爱不是任务，是客观事实。"),
        .init(id: "tophat", name: "体面猫猫礼帽", emoji: "🎩", message: "适合一本正经地宣布下班。"),
        .init(id: "party", name: "庆功派对帽", emoji: "🥳", message: "哪怕只完成一件，也值得敲锣。"),
        .init(id: "flower", name: "散步小花", emoji: "🌼", message: "今天出门会捡到一点好心情。"),
        .init(id: "headphones", name: "拒绝打扰耳机", emoji: "🎧", message: "正在专心可爱，闲事稍后处理。"),
        .init(id: "detective", name: "灵感侦探帽", emoji: "🕵️", message: "专门追踪那些一闪而过的怪点子。"),
        .init(id: "star", name: "闪亮星星", emoji: "⭐️", message: "今天允许自己站在主角的位置。"),
        .init(id: "leaf", name: "充电小叶子", emoji: "🍃", message: "正在进行安静但有效的光合作用。"),
        .init(id: "scarf", name: "暖乎乎围巾", emoji: "🧣", message: "天气和世界都冷时，先把自己裹好。"),
        .init(id: "medal", name: "活着就很棒奖牌", emoji: "🏅", message: "今日参赛项目：认真生活。已经获奖。")
    ]

    static func randomAction(excluding id: Int? = nil) -> ActionEgg {
        actions.filter { $0.id != id }.randomElement() ?? actions[0]
    }

    static func randomOutfit(excluding id: String? = nil) -> CatOutfit {
        outfits.filter { $0.id != id }.randomElement() ?? outfits[0]
    }
}

enum GachaWardrobe {
    private static let unlockedKey = "gacha.unlockedOutfits"

    static var unlockedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: unlockedKey) ?? [])
    }

    static func unlock(_ outfit: CatOutfit) {
        var ids = unlockedIDs
        ids.insert(outfit.id)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: unlockedKey)
    }

    static func emoji(for id: String) -> String? {
        GachaPlayDeck.outfits.first(where: { $0.id == id })?.emoji
    }
}
