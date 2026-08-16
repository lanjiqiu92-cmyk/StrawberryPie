import Foundation
import Combine

@MainActor
final class PieStore: ObservableObject {
    static let shared = PieStore()

    @Published private(set) var items: [PieItem] = []
    @Published var toast: String?

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("ChocolatePie", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("items.json")
        load()
    }

    func add(
        text: String,
        kind: PieItemKind,
        dueDate: Date? = nil,
        expiresAt: Date? = nil,
        aiSuggestion: String? = nil
    ) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        items.insert(PieItem(text: cleanText, kind: kind, dueDate: dueDate, expiresAt: expiresAt, aiSuggestion: aiSuggestion), at: 0)
        save()
        switch kind {
        case .idea: showToast("猫猫接住了！")
        case .work: showToast("工作任务收好啦。")
        case .personal: showToast("给自己的事，也很重要。")
        case .trash: showToast("坏情绪关起来了 🔒")
        }
    }

    func toggle(_ item: PieItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
        save()
    }

    func delete(_ item: PieItem) {
        items.removeAll { $0.id == item.id }
        save()
        showToast("已经丢掉啦。")
    }

    func replaceText(for item: PieItem, with newText: String) {
        let cleanText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty,
              let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[index].aiSuggestion == nil {
            items[index].aiSuggestion = items[index].text
        }
        items[index].text = cleanText
        save()
        showToast(item.kind == .work ? "工作任务清爽多了 ✨" : "猫猫提醒已经贴好啦 🐾")
    }

    func items(for kind: PieItemKind) -> [PieItem] {
        items.filter { $0.kind == kind }
    }

    func count(for kind: PieItemKind) -> Int {
        items.lazy.filter { $0.kind == kind }.count
    }

    func convert(_ item: PieItem, to kind: PieItemKind) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].kind = kind
        items[index].dueDate = nil
        save()
        showToast("猫猫已经帮你挪过去了。")
    }

    func resurfaceCandidate(now: Date = Date()) -> PieItem? {
        let twoDaysAgo = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let candidates = items.filter { $0.kind == .idea && $0.createdAt < twoDaysAgo }
        guard !candidates.isEmpty else { return nil }

        let defaults = UserDefaults.standard
        if let lastDate = defaults.object(forKey: "resurface.lastDate") as? Date,
           Calendar.current.isDate(lastDate, inSameDayAs: now) {
            return nil
        }
        let lastID = defaults.string(forKey: "resurface.lastID")
        return candidates.first(where: { $0.id.uuidString != lastID }) ?? candidates.first
    }

    func markResurfaced(_ item: PieItem) {
        UserDefaults.standard.set(Date(), forKey: "resurface.lastDate")
        UserDefaults.standard.set(item.id.uuidString, forKey: "resurface.lastID")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PieItem].self, from: data) else { return }
        items = decoded
            .filter { $0.expiresAt.map { $0 > Date() } ?? true }
            .sorted { $0.createdAt > $1.createdAt }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }
}
