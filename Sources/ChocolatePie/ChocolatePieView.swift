import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

private enum PieTheme {
    static let paper = Color(red: 0.99, green: 0.965, blue: 0.90)
    static let milk = Color(red: 0.965, green: 0.90, blue: 0.80)
    static let ink = Color(red: 0.17, green: 0.125, blue: 0.115)
    static let chocolate = Color(red: 0.34, green: 0.16, blue: 0.20)
    static let cocoa = Color(red: 0.48, green: 0.24, blue: 0.28)
    static let pink = Color(red: 0.88, green: 0.53, blue: 0.62)
    static let sage = Color(red: 0.62, green: 0.72, blue: 0.62)
    static let blue = Color(red: 0.56, green: 0.70, blue: 0.76)
    static let yellow = Color(red: 0.91, green: 0.77, blue: 0.39)
    static let quiet = Color(red: 0.48, green: 0.39, blue: 0.36)
    static let comicBase = Color(red: 0.96, green: 0.87, blue: 0.86)

    static func tint(for kind: PieItemKind) -> Color {
        switch kind {
        case .idea: return cocoa
        case .work: return sage
        case .personal: return pink
        case .trash: return Color(red: 0.48, green: 0.28, blue: 0.31)
        }
    }
}

private enum CompletionCelebration: CaseIterable {
    case fireworks
    case gong
    case placard

    var caption: String {
        switch self {
        case .fireworks: return "完成啦！"
        case .gong: return "铛铛铛！下班进度 +1"
        case .placard: return "这都让你做完了？"
        }
    }

    var emoji: String {
        switch self {
        case .fireworks: return "🐱"
        case .gong: return "🐱🥁"
        case .placard: return "😼"
        }
    }
}

private enum TrashRitual: String, CaseIterable, Identifiable {
    case slap
    case crumple
    case burn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slap: return "抽它"
        case .crumple: return "揉掉"
        case .burn: return "烧掉"
        }
    }

    var tint: Color {
        switch self {
        case .slap: return PieTheme.pink
        case .crumple: return PieTheme.blue
        case .burn: return PieTheme.yellow
        }
    }
}

private struct CatFortune: Identifiable, Equatable {
    let id: Int
    let title: String
    let message: String
    let footer: String
    let emoji: String
    let accent: Color

    static func == (lhs: CatFortune, rhs: CatFortune) -> Bool { lhs.id == rhs.id }
}

private enum FortuneDeck {
    static var all: [CatFortune] {
        let accents = [PieTheme.pink, PieTheme.yellow, PieTheme.blue, PieTheme.sage]
        return FortuneLibrary.current.enumerated().map { index, copy in
            CatFortune(
                id: index,
                title: copy.title,
                message: copy.message,
                footer: copy.footer,
                emoji: copy.emoji,
                accent: accents[index % accents.count]
            )
        }
    }

    static func today() -> CatFortune {
        let defaults = UserDefaults.standard
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let index = day % all.count
        defaults.set(index, forKey: "fortune.today.index")
        return all[index]
    }

    static func another(excluding fortune: CatFortune) -> CatFortune {
        all.filter { $0.id != fortune.id }.randomElement() ?? fortune
    }
}

struct ChocolatePieView: View {
    @StateObject private var store = PieStore.shared
    @State private var draft = ""
    @State private var selectedKind: PieItemKind = .idea
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(3600)
    @State private var showingAI = false
    @State private var showingSettings = false
    @State private var showingTrashUnlock = false
    @State private var trashUnlocked = false
    @State private var pinDraft = ""
    @State private var pinError = ""
    @State private var aiResult = ""
    @State private var aiError = ""
    @State private var isThinking = false
    @State private var celebrationToken: UUID?
    @State private var celebrationStyle: CompletionCelebration = .fireworks
    @State private var trashRitualToken: UUID?
    @State private var selectedTrashRitual: TrashRitual = .slap
    @State private var resurfacedIdea: PieItem?
    @State private var showingFortune = false
    @State private var showingRoomDrawer = false
    @State private var pendingRoomDrawerAfterUnlock = false
    @State private var showingResurfaceCard = false
    @State private var showingCatSpeech = false
    @State private var catSpeech = "今天先做最重要的一件，好不好？"
    @State private var polishingItem: PieItem?
    @State private var polishSuggestion = ""
    @State private var polishError = ""
    @State private var isPolishing = false
    @State private var sortingNote: String?
    @State private var pendingSortedTrashText: String?
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isPINFocused: Bool
    @FocusState private var isQuickFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoomSceneView(
                counts: Dictionary(uniqueKeysWithValues: PieItemKind.allCases.map { ($0, store.count(for: $0)) }),
                onOpen: openRoomCategory,
                onFortune: {
                    showingFortune = true
                    isQuickFocused = false
                },
                onResurface: showOldIdea,
                onCat: talkToCat
            )

            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(PieTheme.comicBase.opacity(0.98))
                    .frame(height: 126)
                    .overlay(alignment: .top) {
                        Rectangle().fill(PieTheme.ink).frame(height: 3)
                    }
            }
            .allowsHitTesting(false)

            roomHeader
                .padding(.horizontal, 13)
                .padding(.top, 12)

            roomQuickCapture
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(sortingNote == nil ? 1 : 0.24)
                .allowsHitTesting(sortingNote == nil)

            if let sortingNote {
                PaperSortingLayer(
                    text: sortingNote,
                    onDrop: commitSortedNote,
                    onCancel: cancelSortingNote
                )
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .zIndex(18)
            }

            if showingCatSpeech {
                Text(catSpeech)
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(PieTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 3, y: 4)
                    .frame(maxWidth: 245)
                    .position(x: 210, y: 412)
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    .zIndex(15)
            }

            if showingResurfaceCard, let resurfacedIdea {
                VStack {
                    Spacer().frame(height: 370)
                    ResurfaceCard(
                        item: resurfacedIdea,
                        onContinue: {
                            showingResurfaceCard = false
                            continueResurfaced(resurfacedIdea)
                            showingRoomDrawer = true
                        },
                        onConvert: {
                            showingResurfaceCard = false
                            convertResurfaced(resurfacedIdea)
                            showingRoomDrawer = true
                        },
                        onDismiss: {
                            showingResurfaceCard = false
                            dismissResurfaced(resurfacedIdea)
                        }
                    )
                    .padding(.horizontal, 49)
                    Spacer()
                }
                .zIndex(16)
            }

            if showingRoomDrawer {
                roomDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }

            if let toast = store.toast {
                toastView(toast)
                    .padding(.top, 66)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }

            if celebrationToken != nil {
                CelebrationOverlay(style: celebrationStyle)
                    .id(celebrationToken)
                    .allowsHitTesting(false)
                    .zIndex(40)
            }

            if trashRitualToken != nil {
                TrashRitualOverlay(ritual: selectedTrashRitual)
                    .id(trashRitualToken)
                    .allowsHitTesting(false)
                    .zIndex(42)
            }

            if showingFortune {
                FortuneOverlay(
                    onClose: { showingFortune = false },
                    onCollect: { prize in
                        collectGachaPrize(prize)
                        showingFortune = false
                    }
                )
                .zIndex(55)
            }

            if let polishingItem {
                TaskPolishOverlay(
                    item: polishingItem,
                    suggestion: polishSuggestion,
                    error: polishError,
                    isLoading: isPolishing,
                    onClose: { closeTaskPolish() },
                    onRetry: { requestTaskPolish(polishingItem) },
                    onApply: {
                        store.replaceText(for: polishingItem, with: polishSuggestion)
                        closeTaskPolish()
                    }
                )
                .zIndex(58)
            }

            if showingTrashUnlock {
                trashUnlockOverlay
                    .zIndex(50)
            }
        }
        .frame(width: 430, height: 748)
        .foregroundStyle(PieTheme.ink)
        .animation(.easeOut(duration: 0.2), value: showingAI)
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showingRoomDrawer)
        .animation(.easeOut(duration: 0.2), value: showingCatSpeech)
        .onReceive(NotificationCenter.default.publisher(for: .focusChocolatePieComposer)) { _ in
            showingRoomDrawer = true
            isComposerFocused = true
        }
        .onAppear {
            if resurfacedIdea == nil {
                resurfacedIdea = store.resurfaceCandidate()
            }
        }
        .task {
            await FortuneLibrary.refreshIfNeeded()
        }
    }

    private var roomHeader: some View {
        HStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CatMark()
                    .frame(width: 39, height: 39)
                Text("🍓")
                    .font(.system(size: 12))
                    .offset(x: 3, y: 2)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("草莓派的房间")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text("巴旦木管行动，呱呱管生活。")
                    .font(.system(size: 8.8, weight: .bold))
                    .foregroundStyle(PieTheme.quiet)
            }

            Spacer()

            Button {
                showingFortune = true
                isQuickFocused = false
            } label: {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 31, height: 31)
                    .background(PieTheme.yellow)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .help("扭一颗猫猫蛋")

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 31, height: 31)
                    .background(PieTheme.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .help("设置")
            .popover(isPresented: $showingSettings, arrowEdge: .top) {
                SettingsView {
                    trashUnlocked = false
                    if selectedKind == .trash {
                        chooseCategory(.idea)
                        showingRoomDrawer = false
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(PieTheme.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(PieTheme.ink, lineWidth: 2.5))
        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 5)
    }

    private var roomQuickCapture: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Label("随手扔进房间", systemImage: "note.text.badge.plus")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))

                Spacer()
                Text("先写，再拖给家具")
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .foregroundStyle(PieTheme.cocoa)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(PieTheme.pink.opacity(0.45))
                    .clipShape(Capsule())
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("先写下来，不用想它属于哪里……")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(PieTheme.quiet.opacity(0.68))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 6)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draft)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .focused($isQuickFocused)
                        .frame(height: 48)
                        .padding(.horizontal, 1)
                }
                .padding(3)
                .background(Color.white.opacity(0.64))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PieTheme.ink.opacity(0.28), lineWidth: 1.3))
                .contentShape(Rectangle())
                .onTapGesture { isQuickFocused = true }

                VStack(spacing: 5) {
                    Button("变成纸条") { stageQuickDraft() }
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .buttonStyle(.plain)
                        .foregroundStyle(PieTheme.paper)
                        .frame(width: 76, height: 31)
                        .background(PieTheme.chocolate)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(PieTheme.ink, lineWidth: 2))
                        .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.48 : 1)
                        .keyboardShortcut(.return, modifiers: .command)

                    Menu("查看内容") {
                        ForEach(PieItemKind.allCases) { kind in
                            Button(kind.title) { openRoomCategory(kind) }
                        }
                    }
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .menuStyle(.borderlessButton)
                    .frame(width: 76)
                }
            }
        }
        .padding(10)
        .background(PieTheme.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(PieTheme.ink, lineWidth: 2.5))
        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 5)
    }

    private var roomDrawer: some View {
        ZStack(alignment: .bottom) {
            PieTheme.ink.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture { closeRoomDrawer() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(PieTheme.chocolate)
                    .frame(width: 68, height: 8)
                    .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.5))
                    .padding(.top, 9)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(listTitle)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Text(listHint)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PieTheme.quiet)
                    }
                    Spacer()
                    Text("\(store.count(for: selectedKind)) 条")
                        .font(.system(size: 8.5, weight: .black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(PieTheme.yellow)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.5))
                    Button(action: closeRoomDrawer) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .frame(width: 27, height: 27)
                            .background(PieTheme.paper)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help("关闭抽屉")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 9)

                composer
                    .padding(.horizontal, 14)

                if showingAI {
                    aiAssistant
                        .padding(.horizontal, 14)
                        .padding(.top, 7)
                }

                history
                    .padding(.top, 9)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: showingAI ? 620 : 535)
            .background(PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(PieTheme.ink, lineWidth: 3))
            .shadow(color: PieTheme.ink, radius: 0, x: 0, y: -7)
            .padding(.horizontal, 10)
            .offset(y: 12)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CatMark()
                .frame(width: 51, height: 51)

            VStack(alignment: .leading, spacing: 1) {
                Text("草莓派")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text(selectedKind == .trash ? "放心，猫猫嘴很严。" : "猫猫负责接住，你只管想到。")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(PieTheme.quiet)
            }

            Spacer()

            Button {
                showingFortune = true
                isComposerFocused = false
            } label: {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(PieTheme.yellow.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .help("抽一张猫猫签")

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(PieTheme.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingSettings, arrowEdge: .top) {
                SettingsView {
                    trashUnlocked = false
                    if selectedKind == .trash { chooseCategory(.idea) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 10)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(prompt)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Spacer()
                Text(selectedKind.title)
                    .font(.system(size: 9.5, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PieTheme.tint(for: selectedKind).opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.5))
            }

            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(PieTheme.quiet.opacity(0.68))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 7)
                }

                TextEditor(text: $draft)
                    .font(.system(size: 13.5, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .focused($isComposerFocused)
                    .frame(minHeight: 55, maxHeight: 72)
            }
            .padding(5)
            .background(Color.white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PieTheme.ink.opacity(0.25), lineWidth: 1))

            if selectedKind.supportsCompletion {
                HStack(spacing: 7) {
                    Toggle("提醒时间", isOn: $hasDueDate)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10.5, weight: .semibold))
                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .font(.system(size: 10))
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            if selectedKind == .trash {
                HStack(spacing: 6) {
                    Text("怎么处理？")
                        .font(.system(size: 10, weight: .black))
                    ForEach(TrashRitual.allCases) { ritual in
                        Button(ritual.title) {
                            selectedTrashRitual = ritual
                        }
                        .buttonStyle(ComicPillStyle(tint: ritual.tint, selected: selectedTrashRitual == ritual))
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            HStack(spacing: 5) {
                ForEach(PieItemKind.allCases) { kind in
                    Button {
                        requestCategory(kind)
                    } label: {
                        Text(kind.shortTitle)
                    }
                    .buttonStyle(ComicPillStyle(tint: PieTheme.tint(for: kind), selected: selectedKind == kind))
                }

                Spacer(minLength: 2)

                Button {
                    showingAI.toggle()
                    if showingAI { isComposerFocused = false }
                } label: {
                    Image(systemName: "sparkles")
                }
                .buttonStyle(ComicPillStyle(tint: PieTheme.blue, selected: showingAI))

                Button("啪！收进去") { saveDraft() }
                    .font(.system(size: 10.5, weight: .black))
                    .buttonStyle(.plain)
                    .foregroundStyle(PieTheme.paper)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PieTheme.chocolate)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PieTheme.ink, lineWidth: 2))
                    .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.52 : 1)
            }
        }
        .padding(13)
        .background(PieTheme.paper.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(PieTheme.ink, lineWidth: 2.2))
        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 5)
    }

    private var aiAssistant: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("猫猫帮你理一理", systemImage: "sparkles")
                    .font(.system(size: 11.5, weight: .black))
                Spacer()
                if isThinking { ProgressView().controlSize(.small) }
            }

            HStack(spacing: 6) {
                ForEach(AIAction.composerCases, id: \.self) { action in
                    Button(action.rawValue) { runAI(action) }
                        .font(.system(size: 10))
                        .buttonStyle(.bordered)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                }
            }

            if !aiResult.isEmpty {
                Text(aiResult)
                    .font(.system(size: 11.5))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PieTheme.blue.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("采用结果") { draft = aiResult }
                    Button("存为灵感") {
                        store.add(text: aiResult, kind: .idea, aiSuggestion: draft)
                        aiResult = ""
                    }
                    Spacer()
                }
                .font(.system(size: 10.5, weight: .bold))
                .buttonStyle(.plain)
                .foregroundStyle(PieTheme.cocoa)
            } else if !aiError.isEmpty {
                Text(aiError)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.red.opacity(0.78))
            } else {
                Text(AISettingsStore.hasConfiguredProvider() ? "原始文字会一直保留，AI 只提供建议。" : "在设置里连接任意兼容模型服务后，就可以整理、拆解和延伸。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(PieTheme.quiet)
            }
        }
        .padding(11)
        .background(PieTheme.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(PieTheme.ink, lineWidth: 2))
        .shadow(color: PieTheme.ink.opacity(0.9), radius: 0, x: 3, y: 3)
    }

    private var history: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(listTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    Text(listHint)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(PieTheme.quiet)
                }
                Spacer()
                Text("\(store.count(for: selectedKind)) 条")
                    .font(.system(size: 9.5, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PieTheme.yellow)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.5))
            }
            .padding(.horizontal, 17)

            let visibleItems = store.items(for: selectedKind)
            if visibleItems.isEmpty {
                VStack(spacing: 6) {
                    Text(selectedKind == .trash ? "😼" : "🐾")
                        .font(.system(size: 34))
                    Text("这里还空空的")
                        .font(.system(size: 12.5, weight: .black))
                    Text(listHint)
                        .font(.system(size: 10.5))
                        .foregroundStyle(PieTheme.quiet)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleItems) { item in
                            ItemRow(item: item, store: store) {
                                complete(item)
                            } onPolish: {
                                requestTaskPolish(item)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var categoryBar: some View {
        HStack(spacing: 3) {
            ForEach(PieItemKind.allCases) { kind in
                Button {
                    requestCategory(kind)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(kind.title)
                            .font(.system(size: 8.5, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selectedKind == kind ? PieTheme.tint(for: kind) : Color.clear)
                    .foregroundStyle(selectedKind == kind && kind == .trash ? PieTheme.paper : PieTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        Text("\(store.count(for: kind))")
                            .font(.system(size: 7.5, weight: .black))
                            .padding(.horizontal, 4)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(PieTheme.yellow)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1))
                            .offset(x: -4, y: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(PieTheme.paper.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PieTheme.ink, lineWidth: 2.2))
        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 4)
    }

    private var trashUnlockOverlay: some View {
        ZStack {
            PieTheme.ink.opacity(0.58).ignoresSafeArea()

            VStack(spacing: 10) {
                Text("😼")
                    .font(.system(size: 47))
                    .padding(.top, -42)
                Text("先对个暗号")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text("这里装的是只给自己看的情绪垃圾。\n默认暗号是四个 6。")
                    .font(.system(size: 10.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PieTheme.quiet)

                SecureField(
                    "",
                    text: $pinDraft,
                    prompt: Text("输入暗号")
                        .foregroundStyle(PieTheme.quiet.opacity(0.62))
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .background(PieTheme.pink.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(PieTheme.ink, lineWidth: 2))
                    .focused($isPINFocused)
                    .onSubmit(unlockTrash)

                Text(pinError)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.red.opacity(0.76))
                    .frame(height: 14)

                HStack(spacing: 8) {
                    Button("算了") {
                        showingTrashUnlock = false
                        pinDraft = ""
                        if let pendingSortedTrashText {
                            sortingNote = pendingSortedTrashText
                            self.pendingSortedTrashText = nil
                        }
                    }
                    .buttonStyle(ComicModalButtonStyle(primary: false))

                    Button("芝麻开门") { unlockTrash() }
                        .buttonStyle(ComicModalButtonStyle(primary: true))
                }
            }
            .padding(20)
            .frame(width: 305)
            .background(PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(PieTheme.ink, lineWidth: 3))
            .shadow(color: PieTheme.ink, radius: 0, x: 7, y: 8)
            .rotationEffect(.degrees(-0.8))
        }
        .onAppear {
            pinError = ""
            pinDraft = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPINFocused = true }
        }
    }

    private var prompt: String {
        switch selectedKind {
        case .idea: return "今天脑袋里蹦出了什么？"
        case .work: return "接下来要推进哪件工作？"
        case .personal: return "有什么事情想留给自己？"
        case .trash: return "来，偷偷骂两句。"
        }
    }

    private var placeholder: String {
        switch selectedKind {
        case .idea: return "随便写，乱一点也没关系……"
        case .work: return "把工作任务先扔进来……"
        case .personal: return "生活、运动、买东西都可以……"
        case .trash: return "放心写，这里需要密码才能打开……"
        }
    }

    private var listTitle: String {
        switch selectedKind {
        case .idea: return "灵感闪光箱"
        case .work: return "工作作战板"
        case .personal: return "自己的小日子"
        case .trash: return "秘密情绪垃圾桶"
        }
    }

    private var listHint: String {
        switch selectedKind {
        case .idea: return "灵感不必现在想完整"
        case .work: return "完成一个，就让猫猫庆祝一个"
        case .personal: return "先照顾好自己，再拯救世界"
        case .trash: return "说完就把坏情绪关在这里"
        }
    }

    private func openRoomCategory(_ kind: PieItemKind) {
        isQuickFocused = false
        showingCatSpeech = false
        showingResurfaceCard = false
        if kind == .trash && !trashUnlocked {
            pendingRoomDrawerAfterUnlock = true
            showingTrashUnlock = true
            return
        }
        pendingRoomDrawerAfterUnlock = false
        chooseCategory(kind)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showingRoomDrawer = true
        }
    }

    private func selectQuickKind(_ kind: PieItemKind) {
        if kind == .trash && !trashUnlocked {
            pendingRoomDrawerAfterUnlock = false
            showingTrashUnlock = true
            isQuickFocused = false
            return
        }
        chooseCategory(kind)
        isQuickFocused = true
    }

    private func saveQuickDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isQuickFocused = true
            return
        }
        if selectedKind == .trash && !trashUnlocked {
            pendingRoomDrawerAfterUnlock = false
            showingTrashUnlock = true
            isQuickFocused = false
            return
        }
        saveDraft()
        isQuickFocused = true
    }

    private func stageQuickDraft() {
        let cleanText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            isQuickFocused = true
            return
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
            sortingNote = cleanText
            draft = ""
            isQuickFocused = false
        }
        showCatSpeech("拖给窗户、书桌、沙发或垃圾桶，猫猫会接住。")
    }

    private func cancelSortingNote() {
        if let sortingNote { draft = sortingNote }
        withAnimation(.easeOut(duration: 0.18)) { sortingNote = nil }
        isQuickFocused = true
    }

    private func commitSortedNote(_ kind: PieItemKind) {
        guard let note = sortingNote else { return }
        withAnimation(.easeOut(duration: 0.18)) { sortingNote = nil }

        if kind == .trash && !trashUnlocked {
            pendingSortedTrashText = note
            pendingRoomDrawerAfterUnlock = false
            showingTrashUnlock = true
            return
        }

        store.add(text: note, kind: kind)
        selectedKind = kind
        switch kind {
        case .idea: showCatSpeech("呱呱把这颗灵感挂到窗边啦 ✦")
        case .work: showCatSpeech("巴旦木收好任务了：先做第一小步。")
        case .personal: showCatSpeech("呱呱把它放上沙发，不许忘记自己。")
        case .trash:
            playTrashRitual()
            showCatSpeech("呱呱关上桶盖：这份情绪到此为止。")
        }
    }

    private func playTrashRitual() {
        let token = UUID()
        trashRitualToken = token
        Task {
            try? await Task.sleep(for: .seconds(1.65))
            if trashRitualToken == token { trashRitualToken = nil }
        }
    }

    private func closeRoomDrawer() {
        withAnimation(.easeOut(duration: 0.22)) {
            showingRoomDrawer = false
            showingAI = false
        }
        isComposerFocused = false
    }

    private func showOldIdea() {
        isQuickFocused = false
        if resurfacedIdea != nil {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                showingResurfaceCard.toggle()
            }
        } else {
            showCatSpeech("旧纸箱今天空空的，以后再来翻～")
        }
    }

    private func talkToCat(_ cat: RoomCatCharacter) {
        let messages: [String]
        switch cat {
        case .badam:
            messages = [
                "巴旦木：先挑一件最重要的，我帮你盯着。",
                "巴旦木：工作太长就交给我，我负责剪短。",
                "巴旦木：只做第一小步也算开工。",
                "巴旦木：毛线球先借你，焦虑押在我这里。"
            ]
        case .guagua:
            messages = [
                "呱呱：今天也要给自己留一点位置。",
                "呱呱：该喝水啦，不许咖啡冒充。",
                "呱呱：坏情绪可以扔掉，不用分类回收。",
                "呱呱：累了就坐沙发，我给你挪个窝。"
            ]
        }
        showCatSpeech(messages.randomElement() ?? "\(cat.name)正在认真听。")
    }

    private func showCatSpeech(_ message: String) {
        catSpeech = message
        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
            showingCatSpeech = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if catSpeech == message {
                withAnimation(.easeOut(duration: 0.2)) { showingCatSpeech = false }
            }
        }
    }

    private func requestCategory(_ kind: PieItemKind) {
        if kind == .trash && !trashUnlocked {
            pendingRoomDrawerAfterUnlock = showingRoomDrawer
            showingTrashUnlock = true
            isComposerFocused = false
            return
        }
        chooseCategory(kind)
    }

    private func chooseCategory(_ kind: PieItemKind) {
        withAnimation(.easeOut(duration: 0.18)) {
            selectedKind = kind
            showingAI = false
            aiResult = ""
            aiError = ""
            hasDueDate = false
        }
    }

    private func unlockTrash() {
        if TrashPINStore.verify(pinDraft) {
            trashUnlocked = true
            showingTrashUnlock = false
            pinDraft = ""
            if let pendingText = pendingSortedTrashText {
                pendingSortedTrashText = nil
                store.add(text: pendingText, kind: .trash)
                playTrashRitual()
                showCatSpeech("呱呱把坏情绪关好啦。剩下的不用你管。")
                pendingRoomDrawerAfterUnlock = false
                return
            }
            chooseCategory(.trash)
            if pendingRoomDrawerAfterUnlock || !showingRoomDrawer {
                showingRoomDrawer = true
            }
            pendingRoomDrawerAfterUnlock = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                isComposerFocused = true
            }
        } else {
            pinError = "暗号不对，猫猫假装没听见。"
            pinDraft = ""
            isPINFocused = true
        }
    }

    private func complete(_ item: PieItem) {
        if item.kind == .trash {
            let token = UUID()
            trashRitualToken = token
            Task {
                try? await Task.sleep(nanoseconds: 1_650_000_000)
                if trashRitualToken == token { trashRitualToken = nil }
            }
            return
        }
        guard item.kind.supportsCompletion else { return }
        let willComplete = !item.isCompleted
        store.toggle(item)
        if willComplete {
            let token = UUID()
            celebrationStyle = CompletionCelebration.allCases.randomElement() ?? .fireworks
            celebrationToken = token
            Task {
                try? await Task.sleep(nanoseconds: 1_550_000_000)
                if celebrationToken == token { celebrationToken = nil }
            }
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11.5, weight: .black))
            .foregroundStyle(PieTheme.paper)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(PieTheme.chocolate)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 2))
            .shadow(color: PieTheme.ink, radius: 0, x: 2, y: 2)
    }

    private func saveDraft() {
        let savedKind = selectedKind
        let expiration = savedKind == .trash && selectedTrashRitual == .burn
            ? Date().addingTimeInterval(24 * 60 * 60)
            : nil
        store.add(
            text: draft,
            kind: savedKind,
            dueDate: savedKind.supportsCompletion && hasDueDate ? dueDate : nil,
            expiresAt: expiration
        )
        if savedKind == .trash {
            let token = UUID()
            trashRitualToken = token
            Task {
                try? await Task.sleep(nanoseconds: 1_650_000_000)
                if trashRitualToken == token { trashRitualToken = nil }
            }
        }
        draft = ""
        aiResult = ""
        aiError = ""
        showingAI = false
        isComposerFocused = showingRoomDrawer
        isQuickFocused = !showingRoomDrawer
    }

    private func continueResurfaced(_ item: PieItem) {
        store.markResurfaced(item)
        selectedKind = .idea
        draft = item.text + "\n"
        resurfacedIdea = nil
        isComposerFocused = true
    }

    private func convertResurfaced(_ item: PieItem) {
        store.convert(item, to: .work)
        store.markResurfaced(item)
        resurfacedIdea = nil
        selectedKind = .work
    }

    private func dismissResurfaced(_ item: PieItem) {
        store.markResurfaced(item)
        withAnimation(.easeOut(duration: 0.18)) { resurfacedIdea = nil }
    }

    private func runAI(_ action: AIAction) {
        let source = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        isThinking = true
        aiError = ""
        aiResult = ""
        Task {
            do {
                aiResult = try await AIService.shared.respond(to: source, action: action)
            } catch {
                aiError = error.localizedDescription
            }
            isThinking = false
        }
    }

    private func requestTaskPolish(_ item: PieItem) {
        guard item.kind == .work || item.kind == .personal else { return }
        polishingItem = item
        polishSuggestion = ""
        polishError = ""
        isPolishing = true
        let action: AIAction = item.kind == .work ? .condenseWork : .remindPersonal
        Task {
            do {
                polishSuggestion = try await AIService.shared.respond(to: item.text, action: action)
            } catch {
                polishError = error.localizedDescription
            }
            isPolishing = false
        }
    }

    private func closeTaskPolish() {
        polishingItem = nil
        polishSuggestion = ""
        polishError = ""
        isPolishing = false
    }

    private func collectGachaPrize(_ prize: GachaPrize) {
        switch prize {
        case .fortune(let fortune):
            store.add(text: "今日猫猫签：\(fortune.message)", kind: .idea)
        case .action(let action):
            store.add(text: action.message, kind: .personal)
        case .outfit(let outfit):
            previewGachaOutfit(outfit)
        case .double(let fortune, let bonus):
            store.add(text: "今日猫猫签：\(fortune.message)", kind: .idea)
            switch bonus {
            case .action(let action): store.add(text: action.message, kind: .personal)
            case .outfit(let outfit): previewGachaOutfit(outfit)
            }
        }
    }

    private func previewGachaOutfit(_ outfit: CatOutfit) {
        GachaWardrobe.unlock(outfit)
        NotificationCenter.default.post(name: .previewCatOutfit, object: outfit.id)
    }
}

private struct PaperSortingLayer: View {
    let text: String
    let onDrop: (PieItemKind) -> Void
    let onCancel: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var hoveredKind: PieItemKind?

    private let origin = CGPoint(x: 215, y: 486)

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.045)
                    .allowsHitTesting(false)

                instructionBanner
                    .position(x: 215, y: 102)

                targetGuide(.idea, title: "挂到灵感窗", symbol: "sparkles", frame: CGRect(x: 10, y: 105, width: 180, height: 150))
                targetGuide(.work, title: "交给巴旦木", symbol: "briefcase.fill", frame: CGRect(x: 12, y: 258, width: 198, height: 174))
                targetGuide(.personal, title: "交给呱呱", symbol: "heart.fill", frame: CGRect(x: 220, y: 258, width: 198, height: 174))
                targetGuide(.trash, title: "扔掉坏情绪", symbol: "trash.fill", frame: CGRect(x: 305, y: 438, width: 124, height: 176))

                noteCard
                    .position(origin)
                    .offset(dragOffset)
                    .gesture(
                        DragGesture(coordinateSpace: .named("paper-room"))
                            .onChanged { value in
                                dragOffset = CGSize(
                                    width: value.location.x - origin.x,
                                    height: value.location.y - origin.y
                                )
                                withAnimation(.easeOut(duration: 0.12)) {
                                    hoveredKind = dropTarget(at: value.location)
                                }
                            }
                            .onEnded { value in
                                if let target = dropTarget(at: value.location) {
                                    onDrop(target)
                                } else {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                                        dragOffset = .zero
                                        hoveredKind = nil
                                    }
                                }
                            }
                    )

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .black))
                        .frame(width: 25, height: 25)
                        .background(PieTheme.paper)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PieTheme.ink, lineWidth: 1.7))
                }
                .buttonStyle(.plain)
                .position(x: 401, y: 102)
                .help("把纸条放回输入框")
            }
            .coordinateSpace(name: "paper-room")
        }
    }

    private var instructionBanner: some View {
        VStack(spacing: 2) {
            Text("纸条做好啦，拖给房间里的家具")
                .font(.system(size: 10.5, weight: .black, design: .rounded))
            Text(hoveredKind.map(targetHint) ?? "猫猫猜它像「\(suggestedKind.shortTitle)」，也可以拖去别处。")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(PieTheme.quiet)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(PieTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PieTheme.ink, lineWidth: 2))
        .shadow(color: PieTheme.ink, radius: 0, x: 3, y: 4)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🍓 新纸条")
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                Spacer()
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .frame(width: 168)
        .frame(minHeight: 82)
        .background(PieTheme.yellow)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(PieTheme.ink, lineWidth: 2.5))
        .shadow(color: PieTheme.ink, radius: 0, x: 5, y: 6)
        .rotationEffect(.degrees(hoveredKind == nil ? -2 : 1.5))
        .scaleEffect(hoveredKind == nil ? 1 : 1.06)
    }

    private func targetGuide(_ kind: PieItemKind, title: String, symbol: String, frame: CGRect) -> some View {
        Button { onDrop(kind) } label: {
            RoundedRectangle(cornerRadius: 17)
                .fill(PieTheme.tint(for: kind).opacity(hoveredKind == kind ? 0.23 : (suggestedKind == kind ? 0.11 : 0.04)))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(
                            PieTheme.ink.opacity(hoveredKind == kind ? 0.9 : (suggestedKind == kind ? 0.52 : 0.24)),
                            style: StrokeStyle(lineWidth: hoveredKind == kind ? 3 : 1.5, dash: [7, 5])
                        )
                }
                .overlay(alignment: .top) {
                    Label(title, systemImage: symbol)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(hoveredKind == kind ? PieTheme.yellow : PieTheme.paper)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.2))
                        .offset(y: -10)
                }
        }
        .buttonStyle(.plain)
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .help(title)
    }

    private func dropTarget(at point: CGPoint) -> PieItemKind? {
        if CGRect(x: 10, y: 105, width: 180, height: 150).contains(point) { return .idea }
        if CGRect(x: 12, y: 258, width: 198, height: 174).contains(point) { return .work }
        if CGRect(x: 220, y: 258, width: 198, height: 174).contains(point) { return .personal }
        if CGRect(x: 305, y: 438, width: 124, height: 176).contains(point) { return .trash }
        return nil
    }

    private func targetHint(_ kind: PieItemKind) -> String {
        switch kind {
        case .idea: return "呱呱会把它挂到窗边慢慢发亮。"
        case .work: return "巴旦木会收好它，必要时帮你精简。"
        case .personal: return "呱呱会记得提醒你照顾自己的生活。"
        case .trash: return "丢进去吧，坏情绪不用带回家。"
        }
    }

    private var suggestedKind: PieItemKind {
        let workWords = ["工作", "汇报", "会议", "项目", "客户", "文档", "邮件", "上线", "发布"]
        let trashWords = ["烦", "生气", "讨厌", "领导", "想骂", "破事", "滚"]
        let personalWords = ["买", "喝水", "吃饭", "运动", "洗", "收拾", "家里", "猫砂", "睡觉"]
        if trashWords.contains(where: text.contains) { return .trash }
        if workWords.contains(where: text.contains) { return .work }
        if personalWords.contains(where: text.contains) { return .personal }
        return .idea
    }
}

private struct ResurfaceCard: View {
    let item: PieItem
    let onContinue: () -> Void
    let onConvert: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Text("🐱")
                .font(.system(size: 25))

            VStack(alignment: .leading, spacing: 3) {
                Text("猫猫从旧纸箱里捞到一条")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(PieTheme.cocoa)
                Text(item.text)
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(PieTheme.ink)
                    .lineLimit(2)
            }

            Spacer(minLength: 3)

            VStack(spacing: 4) {
                Button("继续想", action: onContinue)
                Button("转成工作", action: onConvert)
                Button("藏回去", action: onDismiss)
            }
            .font(.system(size: 8.5, weight: .black))
            .buttonStyle(ResurfaceActionButtonStyle())
        }
        .padding(10)
        .background(PieTheme.yellow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PieTheme.ink, lineWidth: 2.5))
        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 5)
    }
}

private struct ResurfaceActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PieTheme.cocoa)
            .frame(width: 65, height: 18)
            .background(PieTheme.paper)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.2))
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private enum GachaBonus: Equatable {
    case action(ActionEgg)
    case outfit(CatOutfit)

    var emoji: String {
        switch self { case .action(let value): return value.emoji; case .outfit(let value): return value.emoji }
    }

    var message: String {
        switch self { case .action(let value): return value.message; case .outfit(let value): return "解锁「\(value.name)」" }
    }
}

private enum GachaPrize: Equatable {
    case fortune(CatFortune)
    case action(ActionEgg)
    case outfit(CatOutfit)
    case double(CatFortune, GachaBonus)

    static func draw() -> GachaPrize {
        let roll = Int.random(in: 0..<100)
        if roll < 55 { return .fortune(FortuneDeck.all.randomElement() ?? FortuneDeck.today()) }
        if roll < 80 { return .action(GachaPlayDeck.randomAction()) }
        if roll < 95 { return .outfit(GachaPlayDeck.randomOutfit()) }
        let fortune = FortuneDeck.all.randomElement() ?? FortuneDeck.today()
        let bonus: GachaBonus = Bool.random() ? .action(GachaPlayDeck.randomAction()) : .outfit(GachaPlayDeck.randomOutfit())
        return .double(fortune, bonus)
    }

    var title: String {
        switch self {
        case .fortune(let value): return value.title
        case .action(let value): return value.title
        case .outfit(let value): return "装扮蛋 · \(value.name)"
        case .double: return "双黄蛋！！"
        }
    }

    var emoji: String {
        switch self {
        case .fortune(let value): return value.emoji
        case .action(let value): return value.emoji
        case .outfit(let value): return value.emoji
        case .double(let fortune, let bonus): return "\(fortune.emoji)  \(bonus.emoji)"
        }
    }

    var message: String {
        switch self {
        case .fortune(let value): return value.message
        case .action(let value): return value.message
        case .outfit(let value): return value.message
        case .double(let fortune, let bonus): return "\(fortune.message)\n＋ \(bonus.message)"
        }
    }

    var footer: String {
        switch self {
        case .fortune(let value): return value.footer
        case .action(let value): return value.footer
        case .outfit: return "收下后会让灰白崽子臭美两秒，然后乖乖摘掉。"
        case .double: return "猫猫今天偷偷往蛋里塞了两份。"
        }
    }

    var accent: Color {
        switch self {
        case .fortune(let value): return value.accent
        case .action: return PieTheme.sage
        case .outfit: return PieTheme.pink
        case .double: return PieTheme.yellow
        }
    }

    var collectLabel: String {
        switch self {
        case .fortune: return "存成灵感"
        case .action: return "存成个人待办"
        case .outfit: return "试戴一下"
        case .double: return "全部收下"
        }
    }
}

private struct FortuneOverlay: View {
    let onClose: () -> Void
    let onCollect: (GachaPrize) -> Void
    @State private var prize = GachaPrize.draw()
    @State private var revealed = false
    @State private var dropped = false
    @State private var showingWardrobe = false
    @State private var wardrobeVersion = 0
    @State private var capsuleHovered = false
    @State private var showingShareCard = false

    var body: some View {
        ZStack {
            PieTheme.ink.opacity(0.60).ignoresSafeArea()

            VStack(spacing: 11) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("🪙 猫猫扭蛋机")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                        Text(showingWardrobe ? "两只崽子的装扮收藏" : revealed ? revealCaption : "选好了！摸摸这颗蛋就会打开")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(PieTheme.quiet)
                        Text(FortuneLibrary.sourceLabel)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(PieTheme.quiet.opacity(0.78))
                    }
                    Spacer()
                    Button("衣柜 \(GachaWardrobe.unlockedIDs.count)/\(GachaPlayDeck.outfits.count)") {
                        withAnimation(.easeOut(duration: 0.18)) { showingWardrobe.toggle() }
                    }
                    .font(.system(size: 8.5, weight: .black))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(PieTheme.pink.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.2))
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .frame(width: 25, height: 25)
                            .background(PieTheme.paper)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 1.7))
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(showingWardrobe ? PieTheme.milk : revealed ? prize.accent.opacity(0.80) : PieTheme.blue.opacity(0.72))
                        .shadow(color: PieTheme.ink, radius: 0, x: 6, y: 7)

                    if showingWardrobe {
                        WardrobeGrid(version: wardrobeVersion) { outfit in
                            GachaWardrobe.unlock(outfit)
                            NotificationCenter.default.post(name: .previewCatOutfit, object: outfit.id)
                            onClose()
                        }
                            .padding(12)
                    } else if revealed {
                        VStack(spacing: 8) {
                            Text(prize.title)
                                .font(.system(size: 13.5, weight: .black, design: .rounded))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(PieTheme.paper.opacity(0.82))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 1.5))

                            Text(prize.emoji).font(.system(size: prize.isDouble ? 38 : 46))
                            Text(prize.message)
                                .font(.system(size: prize.isDouble ? 13.5 : 15.5, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(prize.footer)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PieTheme.quiet)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 18)
                        .transition(.scale(scale: 0.62).combined(with: .opacity))
                    } else {
                        capsuleButton
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(PieTheme.ink, lineWidth: 3))

                if showingWardrobe {
                    VStack(spacing: 5) {
                        Text("点一下已解锁装扮，崽子会试戴两秒给你看。")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(PieTheme.quiet)
                        Button("返回扭蛋") { showingWardrobe = false }
                            .buttonStyle(ComicModalButtonStyle(primary: true))
                    }
                } else if revealed {
                    VStack(spacing: 7) {
                        HStack(spacing: 8) {
                            Button(prize.collectLabel) { onCollect(prize) }
                                .buttonStyle(ComicModalButtonStyle(primary: false))
                            Button("再扭一颗") { drawAgain() }
                                .buttonStyle(ComicModalButtonStyle(primary: true))
                        }
                        Button {
                            showingShareCard = true
                        } label: {
                            Label("做成可爱卡片", systemImage: "square.and.arrow.up")
                                .font(.system(size: 9.5, weight: .black, design: .rounded))
                                .foregroundStyle(PieTheme.cocoa)
                                .frame(maxWidth: .infinity, minHeight: 27)
                                .background(PieTheme.pink.opacity(0.34))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(PieTheme.ink, lineWidth: 1.4))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button("这颗先不拆，收起来") { onClose() }
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .buttonStyle(.plain)
                        .foregroundStyle(PieTheme.quiet)
                }
            }
            .padding(18)
            .frame(width: 366)
            .background(PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PieTheme.ink, lineWidth: 3))
            .shadow(color: PieTheme.ink, radius: 0, x: 8, y: 9)

            if showingShareCard {
                FortuneCardExportOverlay(
                    prize: prize,
                    onClose: { showingShareCard = false }
                )
                .zIndex(20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.68)) { dropped = true }
        }
    }

    private var revealCaption: String {
        switch prize { case .fortune: return "咯哒！是一张猫猫签"; case .action: return "咯哒！掉出一个行动蛋"; case .outfit: return "咯哒！解锁新装扮"; case .double: return "哐当！！居然是双黄蛋" }
    }

    private var capsuleButton: some View {
        Button {
            if case .outfit(let outfit) = prize { GachaWardrobe.unlock(outfit); wardrobeVersion += 1 }
            if case .double(_, .outfit(let outfit)) = prize { GachaWardrobe.unlock(outfit); wardrobeVersion += 1 }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { revealed = true }
        } label: {
            VStack(spacing: 11) {
                ZStack {
                    Text("✦").font(.system(size: 23, weight: .black)).foregroundStyle(PieTheme.yellow).offset(x: -88, y: -48).scaleEffect(capsuleHovered ? 1.28 : 0.82)
                    Text("✧").font(.system(size: 25, weight: .black)).foregroundStyle(PieTheme.paper).offset(x: 88, y: -31).scaleEffect(capsuleHovered ? 0.82 : 1.22)
                    Text("♡").font(.system(size: 19, weight: .black)).foregroundStyle(PieTheme.pink).offset(x: 82, y: 48).rotationEffect(.degrees(capsuleHovered ? 12 : -8))
                    VStack(spacing: -3) {
                        UnevenRoundedRectangle(topLeadingRadius: 58, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 58)
                            .fill(PieTheme.pink).frame(width: 124, height: 54)
                            .overlay(UnevenRoundedRectangle(topLeadingRadius: 58, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 58).stroke(PieTheme.ink, lineWidth: 4))
                        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 58, bottomTrailingRadius: 58, topTrailingRadius: 8)
                            .fill(PieTheme.paper).frame(width: 124, height: 54)
                            .overlay(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 58, bottomTrailingRadius: 58, topTrailingRadius: 8).stroke(PieTheme.ink, lineWidth: 4))
                    }
                    Capsule().fill(PieTheme.yellow).frame(width: 130, height: 14).overlay(Capsule().stroke(PieTheme.ink, lineWidth: 3))
                    Text("🐱🐱").font(.system(size: 29)).offset(y: -8)
                }
                .shadow(color: PieTheme.ink.opacity(0.52), radius: 0, x: 5, y: 7)

                VStack(spacing: 4) {
                    Text("轻轻戳一下")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(PieTheme.quiet)
                    Label("拆开看看！", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(PieTheme.paper)
                        .padding(.horizontal, 22)
                        .frame(height: 36)
                        .background(PieTheme.chocolate)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(PieTheme.ink, lineWidth: 2))
                        .shadow(color: PieTheme.ink, radius: 0, x: 3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) { capsuleHovered = hovering }
        }
        .scaleEffect(dropped ? (capsuleHovered ? 1.045 : 1) : 0.55)
        .offset(y: dropped ? 0 : -130)
        .rotationEffect(.degrees(dropped ? (capsuleHovered ? -2 : 0) : -130))
    }

    private func drawAgain() {
        withAnimation(.easeIn(duration: 0.18)) { revealed = false; dropped = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            prize = GachaPrize.draw()
            withAnimation(.spring(response: 0.58, dampingFraction: 0.66)) { dropped = true }
        }
    }
}

private extension GachaPrize {
    var isDouble: Bool { if case .double = self { return true }; return false }
}

private struct WardrobeGrid: View {
    let version: Int
    let onPreview: (CatOutfit) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(GachaPlayDeck.outfits) { outfit in
                    let unlocked = GachaWardrobe.unlockedIDs.contains(outfit.id)
                    Button {
                        guard unlocked else { return }
                        onPreview(outfit)
                    } label: {
                        VStack(spacing: 3) {
                            Text(unlocked ? outfit.emoji : "❔").font(.system(size: 23))
                            Text(unlocked ? outfit.name : "神秘装扮")
                                .font(.system(size: 7.5, weight: .black))
                                .lineLimit(1)
                            if unlocked { Text("点我试戴").font(.system(size: 7, weight: .black)).foregroundStyle(PieTheme.cocoa) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(PieTheme.paper.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(PieTheme.ink.opacity(unlocked ? 0.78 : 0.28), lineWidth: 1.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                }
            }
        }
        .id(version)
    }
}

private struct FortuneCardExportOverlay: View {
    let prize: GachaPrize
    let onClose: () -> Void

    @State private var statusMessage = ""
    @State private var sharingPicker: NSSharingServicePicker?

    var body: some View {
        ZStack {
            PieTheme.ink.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("🍓 草莓派分享卡")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        Text("巴旦木和呱呱已经替你排好版啦")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(PieTheme.quiet)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                            .frame(width: 25, height: 25)
                            .background(PieTheme.paper)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 1.7))
                    }
                    .buttonStyle(.plain)
                }

                FortuneShareCard(prize: prize)
                    .frame(width: 1080, height: 1350)
                    .scaleEffect(0.224, anchor: .center)
                    .frame(width: 242, height: 302)
                    .shadow(color: PieTheme.ink.opacity(0.45), radius: 0, x: 6, y: 7)

                Text(statusMessage.isEmpty ? "高清 PNG · 1080 × 1350 · 适合发给朋友" : statusMessage)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(statusMessage.hasPrefix("保存失败") ? Color.red : PieTheme.quiet)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Button {
                        savePNG()
                    } label: {
                        Label("保存 PNG", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(ComicModalButtonStyle(primary: false))

                    Button {
                        shareCard()
                    } label: {
                        Label("分享给朋友", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(ComicModalButtonStyle(primary: true))
                }
            }
            .padding(16)
            .frame(width: 330)
            .background(PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PieTheme.ink, lineWidth: 3))
            .shadow(color: PieTheme.ink, radius: 0, x: 8, y: 9)
        }
    }

    @MainActor
    private func renderCard() -> NSImage? {
        let renderer = ImageRenderer(
            content: FortuneShareCard(prize: prize)
                .frame(width: 1080, height: 1350)
        )
        renderer.scale = 1
        return renderer.nsImage
    }

    @MainActor
    private func savePNG() {
        guard let image = renderCard(),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            statusMessage = "保存失败：猫猫没有成功冲洗照片"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFileName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                statusMessage = "保存成功，可以发给朋友啦 ✨"
            } catch {
                statusMessage = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func shareCard() {
        guard let image = renderCard(), let contentView = NSApp.keyWindow?.contentView else {
            statusMessage = "分享失败：猫猫找不到分享窗口"
            return
        }
        let picker = NSSharingServicePicker(items: [image])
        sharingPicker = picker
        let anchor = NSRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }

    private var exportFileName: String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let safeTitle = prize.title.components(separatedBy: invalid).joined(separator: "-")
        return "草莓派-\(safeTitle).png"
    }
}

private struct FortuneShareCard: View {
    let prize: GachaPrize

    private let ink = Color(red: 0.18, green: 0.10, blue: 0.12)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.87)
    private let strawberry = Color(red: 0.90, green: 0.34, blue: 0.46)

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.77, blue: 0.79)

            RoundedRectangle(cornerRadius: 78)
                .fill(cream)
                .padding(48)
                .overlay {
                    RoundedRectangle(cornerRadius: 78)
                        .stroke(ink, lineWidth: 12)
                        .padding(48)
                }

            decorativeDoodles

            VStack(spacing: 24) {
                HStack {
                    HStack(spacing: 14) {
                        Text("🍓")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("草莓派")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                            Text("巴旦木 × 呱呱 今日出品")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.62))
                        }
                    }
                    Spacer()
                    Text("NO. \(cardNumber)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(prize.accent.opacity(0.62))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ink, lineWidth: 5))
                }

                VStack(spacing: 20) {
                    Text(prize.title)
                        .font(.system(size: 35, weight: .black, design: .rounded))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ink, lineWidth: 5))

                    Text(prize.emoji)
                        .font(.system(size: prize.isDouble ? 82 : 104))

                    Text(prize.message)
                        .font(.system(size: prize.isDouble ? 43 : 49, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundStyle(ink)
                        .frame(maxWidth: 820)

                    Text(prize.footer)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink.opacity(0.58))
                        .frame(maxWidth: 760)
                }
                .frame(maxHeight: .infinity)

                FortuneShareIllustration(style: styleIndex)
                    .frame(height: 340)

                HStack {
                    Label("今天也被猫猫认真祝福了", systemImage: "pawprint.fill")
                    Spacer()
                    Text("把好运分一半给你")
                }
                .font(.system(size: 23, weight: .black, design: .rounded))
                .padding(.horizontal, 28)
                .frame(height: 64)
                .background(strawberry)
                .foregroundStyle(cream)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink, lineWidth: 5))
            }
            .padding(82)
        }
        .frame(width: 1080, height: 1350)
        .clipShape(RoundedRectangle(cornerRadius: 42))
    }

    private var decorativeDoodles: some View {
        ZStack {
            Text(decorations[0]).font(.system(size: 55)).position(x: 105, y: 240).rotationEffect(.degrees(-12))
            Text(decorations[1]).font(.system(size: 48)).position(x: 965, y: 310).rotationEffect(.degrees(13))
            Text(decorations[2]).font(.system(size: 52)).position(x: 120, y: 770).rotationEffect(.degrees(9))
            Text(decorations[3]).font(.system(size: 48)).position(x: 950, y: 820).rotationEffect(.degrees(-10))
            Text("✦").font(.system(size: 44, weight: .black)).foregroundStyle(strawberry).position(x: 920, y: 190)
            Text("♡").font(.system(size: 50, weight: .black)).foregroundStyle(ink.opacity(0.50)).position(x: 165, y: 965)
        }
    }

    private var decorations: [String] {
        switch styleIndex {
        case 0: return ["🍓", "🐾", "✧", "🧶"]
        case 1: return ["🌼", "☁️", "🐾", "🍬"]
        default: return ["🎀", "⭐️", "🍓", "✦"]
        }
    }

    private var styleIndex: Int {
        prize.title.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 3
    }

    private var cardNumber: String {
        String(format: "%03d", prize.title.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 997)
    }
}

private struct FortuneShareIllustration: View {
    let style: Int

    var body: some View {
        ZStack {
            Ellipse()
                .fill(style == 1 ? PieTheme.sage : PieTheme.yellow)
                .frame(width: 650, height: 205)
                .overlay(Ellipse().stroke(PieTheme.ink, lineWidth: 8))
                .shadow(color: PieTheme.ink.opacity(0.65), radius: 0, x: 13, y: 15)
                .offset(y: 55)

            ShareCardCatsArtwork()
                .frame(width: 520, height: 300)
                .offset(y: -3)

            Text(style == 0 ? "🧶" : style == 1 ? "🌼" : "🍓")
                .font(.system(size: 72))
                .offset(x: -280, y: 92)
                .rotationEffect(.degrees(-12))

            Text(style == 0 ? "🍓" : style == 1 ? "☁️" : "🎀")
                .font(.system(size: 68))
                .offset(x: 285, y: 70)
                .rotationEffect(.degrees(10))

            Text("巴旦木")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .padding(.horizontal, 17)
                .padding(.vertical, 8)
                .background(PieTheme.paper)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 4))
                .offset(x: -135, y: 130)

            Text("呱呱")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .padding(.horizontal, 17)
                .padding(.vertical, 8)
                .background(PieTheme.paper)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PieTheme.ink, lineWidth: 4))
                .offset(x: 130, y: 130)
        }
    }
}

private struct ShareCardCatsArtwork: View {
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "TwoCats", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Text("🐱  🐱")
                    .font(.system(size: 130))
            }
        }
    }
}

private struct TaskPolishOverlay: View {
    let item: PieItem
    let suggestion: String
    let error: String
    let isLoading: Bool
    let onClose: () -> Void
    let onRetry: () -> Void
    let onApply: () -> Void

    var body: some View {
        ZStack {
            PieTheme.ink.opacity(0.60).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.kind == .work ? "🐱 猫猫给工作瘦个身" : "🐱 猫猫替你贴个提醒")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text("先看建议，只有点了采用才会修改原文。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(PieTheme.quiet)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .frame(width: 25, height: 25)
                            .background(PieTheme.paper)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 1.7))
                    }
                    .buttonStyle(.plain)
                }

                comparisonBlock(title: "原来的", text: item.text, tint: PieTheme.milk)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(item.kind == .work ? "精简建议" : "提醒建议")
                            .font(.system(size: 10, weight: .black))
                        Spacer()
                        if isLoading { ProgressView().controlSize(.small) }
                    }

                    if isLoading {
                        Text(item.kind == .work ? "猫猫正在叼走废话……" : "猫猫正在挑一句不烦人的提醒……")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PieTheme.quiet)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    } else if !error.isEmpty {
                        Text(error)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.78))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    } else {
                        Text(suggestion)
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    }
                }
                .padding(11)
                .background((item.kind == .work ? PieTheme.sage : PieTheme.pink).opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(PieTheme.ink, lineWidth: 1.7))

                HStack(spacing: 8) {
                    Button("保留原文", action: onClose)
                        .buttonStyle(ComicModalButtonStyle(primary: false))
                    if !error.isEmpty {
                        Button("再试一次", action: onRetry)
                            .buttonStyle(ComicModalButtonStyle(primary: true))
                    } else {
                        Button(item.kind == .work ? "采用精简版" : "采用提醒版", action: onApply)
                            .buttonStyle(ComicModalButtonStyle(primary: true))
                            .disabled(isLoading || suggestion.isEmpty)
                    }
                }
            }
            .padding(17)
            .frame(width: 356)
            .background(PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PieTheme.ink, lineWidth: 3))
            .shadow(color: PieTheme.ink, radius: 0, x: 8, y: 9)
        }
    }

    private func comparisonBlock(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(PieTheme.quiet)
            Text(text)
                .font(.system(size: 11.5, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(tint.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ItemRow: View {
    let item: PieItem
    @ObservedObject var store: PieStore
    let onToggle: () -> Void
    let onPolish: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(PieTheme.ink)
                    .frame(width: 23, height: 23)
                    .background(item.isCompleted ? PieTheme.sage : PieTheme.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink, lineWidth: item.kind == .idea ? 0 : 2))
            }
            .buttonStyle(.plain)
            .disabled(item.kind == .idea)
            .help(item.kind == .trash ? "重播情绪处理特效" : item.kind.supportsCompletion ? "切换完成状态" : "")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 12.5, weight: .bold))
                    .strikethrough(item.isCompleted, color: PieTheme.ink)
                    .foregroundStyle(item.isCompleted ? PieTheme.quiet.opacity(0.62) : PieTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Text(item.kind.title)
                    Text("·")
                    Text(item.createdAt, format: .dateTime.hour().minute())
                    if let due = item.dueDate {
                        Text("·")
                        Text(due, format: .dateTime.month().day().hour().minute())
                    }
                    if item.expiresAt != nil {
                        Text("· 24小时后化成灰")
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(PieTheme.quiet)

                if item.kind == .work || item.kind == .personal {
                    Button(action: onPolish) {
                        Label(item.kind == .work ? "巴旦木精简" : "呱呱提醒", systemImage: "sparkles")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(item.kind == .work ? PieTheme.sage.opacity(0.72) : PieTheme.pink.opacity(0.72))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PieTheme.ink.opacity(0.65), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(item.kind == .work ? "让 DeepSeek 给出精简建议，确认后才替换" : "让 DeepSeek 改成温柔提醒，确认后才替换")
                }
            }

            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.18)) {
                    store.delete(item)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PieTheme.quiet)
                    .frame(width: 24, height: 24)
                    .background(PieTheme.paper.opacity(0.72))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PieTheme.ink.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("删除这条\(item.kind.title)")
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 11)
                .fill(item.kind == .trash ? PieTheme.pink.opacity(0.42) : PieTheme.paper.opacity(item.isCompleted ? 0.72 : 0.96))
                .shadow(color: PieTheme.ink.opacity(0.9), radius: 0, x: 2, y: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(PieTheme.ink, lineWidth: 1.8))
    }

    private var icon: String {
        if item.kind == .idea { return "sparkles" }
        if item.kind == .trash { return "flame.fill" }
        return item.isCompleted ? "checkmark" : ""
    }
}

private struct ComicPillStyle: ButtonStyle {
    let tint: Color
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.5, weight: .black))
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? PieTheme.ink : PieTheme.quiet)
            .background(selected ? tint : PieTheme.paper.opacity(0.52))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PieTheme.ink.opacity(selected ? 1 : 0.35), lineWidth: selected ? 1.7 : 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct ComicModalButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(primary ? PieTheme.paper : PieTheme.ink)
            .background(primary ? PieTheme.chocolate : PieTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(PieTheme.ink, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct QuickKindButtonStyle: ButtonStyle {
    let tint: Color
    let selected: Bool
    let inverted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .foregroundStyle(selected && inverted ? PieTheme.paper : PieTheme.ink)
            .padding(.horizontal, 7)
            .frame(height: 23)
            .background(selected ? tint : PieTheme.paper)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PieTheme.ink.opacity(selected ? 1 : 0.42), lineWidth: selected ? 1.8 : 1.2))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct CatMark: View {
    var body: some View {
        Canvas { context, size in
            let ink = PieTheme.ink
            var head = Path()
            head.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.58))
            head.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.17))
            head.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.34))
            head.addQuadCurve(to: CGPoint(x: size.width * 0.70, y: size.height * 0.34), control: CGPoint(x: size.width * 0.56, y: size.height * 0.26))
            head.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.16))
            head.addLine(to: CGPoint(x: size.width * 0.91, y: size.height * 0.62))
            head.addQuadCurve(to: CGPoint(x: size.width * 0.51, y: size.height * 0.92), control: CGPoint(x: size.width * 0.83, y: size.height * 0.92))
            head.addQuadCurve(to: CGPoint(x: size.width * 0.12, y: size.height * 0.58), control: CGPoint(x: size.width * 0.18, y: size.height * 0.91))
            head.closeSubpath()
            context.fill(head, with: .color(PieTheme.paper))
            context.stroke(head, with: .color(ink), style: StrokeStyle(lineWidth: 3.4, lineJoin: .round))

            let eyeSize = CGSize(width: 4.5, height: 7)
            context.fill(Path(ellipseIn: CGRect(origin: CGPoint(x: size.width * 0.34, y: size.height * 0.52), size: eyeSize)), with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(origin: CGPoint(x: size.width * 0.64, y: size.height * 0.52), size: eyeSize)), with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.45, y: size.height * 0.66, width: 7, height: 5)), with: .color(PieTheme.pink))
        }
    }
}

private struct ComicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PieTheme.comicBase

                Text("ฅ^•ﻌ•^ฅ")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(PieTheme.ink.opacity(0.055))
                    .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.72)

                Text("PAW!")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(PieTheme.ink.opacity(0.10))
                    .rotationEffect(.degrees(-7))
                    .position(x: 55, y: proxy.size.height * 0.56)

                Canvas { context, size in
                    for index in 0..<110 {
                        let x = CGFloat((index * 47) % 431)
                        let y = CGFloat((index * 83) % 749)
                        let rect = CGRect(x: x, y: y, width: index % 3 == 0 ? 2 : 1, height: 1)
                        context.fill(Path(ellipseIn: rect), with: .color(PieTheme.ink.opacity(0.08)))
                    }
                }
                .blendMode(.multiply)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

private struct CelebrationOverlay: View {
    let style: CompletionCelebration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false
    @State private var fading = false

    private let colors = [PieTheme.pink, PieTheme.yellow, PieTheme.sage, PieTheme.blue, Color(red: 0.95, green: 0.55, blue: 0.40)]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !reduceMotion && style == .fireworks {
                    ForEach(0..<24, id: \.self) { index in
                        let angle = Double(index) * (.pi * 2 / 24)
                        let distance = CGFloat(58 + (index % 4) * 14)
                        FireworkSpark(
                            color: colors[index % colors.count],
                            size: CGFloat(5 + index % 3 * 2),
                            center: CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.50),
                            offset: CGSize(width: CGFloat(cos(angle)) * distance, height: CGFloat(sin(angle)) * distance),
                            delay: Double(index % 3) * 0.035,
                            burst: burst
                        )
                    }

                    ForEach(0..<14, id: \.self) { index in
                        FallingConfetti(
                            color: colors[(index + 2) % colors.count],
                            x: CGFloat(25 + index * 29),
                            distance: proxy.size.height + 30,
                            rotation: Double(360 + index * 45),
                            delay: Double(index % 5) * 0.05,
                            falling: burst,
                            fading: fading
                        )
                    }
                }

                VStack(spacing: 5) {
                    Text(style.caption)
                        .font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PieTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(PieTheme.ink, lineWidth: 2))
                        .rotationEffect(.degrees(5))
                    Text(style.emoji)
                        .font(.system(size: style == .gong ? 34 : 44))
                        .frame(width: 68, height: 68)
                        .background(PieTheme.paper)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PieTheme.ink, lineWidth: 3))
                        .shadow(color: PieTheme.ink, radius: 0, x: 4, y: 5)
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.51)
                .scaleEffect(burst ? 1 : 0.2)
                .offset(y: burst ? -70 : 22)
                .rotationEffect(.degrees(burst ? 4 : -15))
                .opacity(fading ? 0 : 1)
                .animation(reduceMotion ? .none : .spring(response: 0.44, dampingFraction: 0.55), value: burst)
                .animation(.easeOut(duration: 0.28), value: fading)
            }
        }
        .onAppear {
            burst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.08) { fading = true }
        }
    }
}

private struct TrashRitualOverlay: View {
    let ritual: TrashRitual
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strike = false
    @State private var fading = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white.opacity(strike ? 0.12 : 0)
                ritualScene(proxy: proxy)
            }
            .opacity(fading ? 0 : 1)
            .animation(.easeOut(duration: 0.30), value: fading)
        }
        .onAppear {
            strike = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) { fading = true }
        }
    }

    @ViewBuilder
    private func ritualScene(proxy: GeometryProxy) -> some View {
        switch ritual {
        case .slap:
            VStack(spacing: 7) {
                ritualCaption("今天不内耗，啪！")
                HStack(spacing: 70) {
                    ritualFace("😼", color: PieTheme.paper)
                    ritualFace(strike ? "😵‍💫" : "👔", color: PieTheme.pink.opacity(0.88))
                        .rotationEffect(.degrees(strike ? 13 : 0))
                }
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.48)

            Text("🐾")
                .font(.system(size: 57))
                .position(x: proxy.size.width * 0.39, y: proxy.size.height * 0.51)
                .offset(x: strike ? 92 : -18, y: strike ? -5 : 16)
                .rotationEffect(.degrees(strike ? 76 : -28))
                .scaleEffect(strike ? 1.05 : 0.72)
                .animation(reduceMotion ? .none : .interpolatingSpring(stiffness: 240, damping: 13), value: strike)

            impactText("啪！！", proxy: proxy)

        case .crumple:
            VStack(spacing: 10) {
                ritualCaption("揉成一团，咻～")
                Text("📄")
                    .font(.system(size: 65))
                    .scaleEffect(strike ? 0.32 : 1)
                    .rotationEffect(.degrees(strike ? 420 : 0))
                    .offset(x: strike ? 72 : 0, y: strike ? 78 : 0)
                    .animation(reduceMotion ? .none : .easeIn(duration: 0.78), value: strike)
                Text("🗑️")
                    .font(.system(size: 58))
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.46)

        case .burn:
            VStack(spacing: 8) {
                ritualCaption("烧掉了，24 小时后化成灰")
                ZStack(alignment: .bottom) {
                    Text("📄")
                        .font(.system(size: 72))
                        .opacity(strike ? 0.28 : 1)
                        .scaleEffect(strike ? 0.72 : 1)
                    Text("🔥")
                        .font(.system(size: 72))
                        .scaleEffect(strike ? 1.15 : 0.12)
                        .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.52), value: strike)
                }
                Text("猫猫已安排自动清理")
                    .font(.system(size: 10.5, weight: .black))
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.48)
        }
    }

    private func ritualCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(PieTheme.yellow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PieTheme.ink, lineWidth: 2))
            .rotationEffect(.degrees(-4))
    }

    private func ritualFace(_ emoji: String, color: Color) -> some View {
        Text(emoji)
            .font(.system(size: 50))
            .frame(width: 78, height: 78)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 3))
    }

    private func impactText(_ text: String, proxy: GeometryProxy) -> some View {
        Text(text)
            .font(.system(size: 25, weight: .black, design: .rounded))
            .foregroundStyle(PieTheme.ink)
            .padding(9)
            .background(PieTheme.yellow)
            .clipShape(Circle())
            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 3))
            .position(x: proxy.size.width * 0.67, y: proxy.size.height * 0.40)
            .scaleEffect(strike ? 1 : 0.05)
            .rotationEffect(.degrees(9))
            .animation(reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.46).delay(0.16), value: strike)
    }
}

private struct FireworkSpark: View {
    let color: Color
    let size: CGFloat
    let center: CGPoint
    let offset: CGSize
    let delay: Double
    let burst: Bool

    var body: some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(PieTheme.ink, lineWidth: 1.2))
            .frame(width: size, height: size)
            .position(center)
            .offset(burst ? offset : .zero)
            .opacity(burst ? 0 : 1)
            .animation(.easeOut(duration: 0.82).delay(delay), value: burst)
    }
}

private struct FallingConfetti: View {
    let color: Color
    let x: CGFloat
    let distance: CGFloat
    let rotation: Double
    let delay: Double
    let falling: Bool
    let fading: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(PieTheme.ink, lineWidth: 1))
            .frame(width: 7, height: 12)
            .position(x: x, y: -10)
            .offset(y: falling ? distance : 0)
            .rotationEffect(.degrees(falling ? rotation : 0))
            .opacity(fading ? 0 : 1)
            .animation(.easeIn(duration: 1.35).delay(delay), value: falling)
    }
}

enum TrashPINStore {
    private static let key = "trash.pin"
    static var current: String { UserDefaults.standard.string(forKey: key) ?? "6666" }
    static func verify(_ value: String) -> Bool { value == current }
    static func update(_ value: String) { UserDefaults.standard.set(value, forKey: key) }
}

private struct SettingsView: View {
    @StateObject private var settings = AISettingsStore()
    @ObservedObject private var reminderScheduler = WellnessReminderScheduler.shared
    @AppStorage(ReminderPreferenceKeys.enabled) private var reminderEnabled = false
    @AppStorage(ReminderPreferenceKeys.intervalMinutes) private var reminderInterval = 45
    @AppStorage(ReminderPreferenceKeys.startHour) private var reminderStartHour = 9
    @AppStorage(ReminderPreferenceKeys.endHour) private var reminderEndHour = 22
    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var pinStatus = ""
    let onPINChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("连接 AI 模型")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text("选择你已经拥有 API Key 的服务商")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(settings.hasSavedKey ? PieTheme.sage : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }

                Picker("模型服务商", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .onChange(of: settings.provider) { _, newValue in settings.select(newValue) }

                labeledField("API Key") {
                    SecureField(settings.hasSavedKey ? "已保存，留空表示不修改" : "粘贴服务商提供的 API Key", text: $settings.apiKey)
                }
                labeledField("模型名称") {
                    TextField("例如 deepseek-chat", text: $settings.model)
                }
                labeledField("接口地址") {
                    TextField("https://…", text: $settings.baseURL)
                        .font(.system(size: 10.5, design: .monospaced))
                }

                Text(providerHint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !settings.statusMessage.isEmpty {
                    Text(settings.statusMessage)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(settings.statusMessage.contains("成功") || settings.statusMessage.contains("已安全") ? PieTheme.sage : .secondary)
                }

                HStack {
                    Button("测试连接") { testConnection() }
                        .disabled(settings.isTesting || settings.isSaving)
                    if settings.isTesting { ProgressView().controlSize(.small) }
                    Spacer()
                    if settings.isSaving { ProgressView().controlSize(.small) }
                    Button("保存 AI 设置") {
                        Task { _ = await settings.save() }
                    }
                        .disabled(settings.isTesting || settings.isSaving)
                        .buttonStyle(.borderedProminent)
                        .tint(PieTheme.chocolate)
                }

                Divider()

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("猫猫定时提醒", systemImage: "bell.and.waves.left.and.right.fill")
                                .font(.system(size: 12.5, weight: .black))
                            Text(ReminderLibrary.sourceLabel)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $reminderEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Stepper(value: $reminderInterval, in: 10...180, step: 5) {
                        HStack {
                            Text("每隔")
                            Text("\(reminderInterval) 分钟")
                                .fontWeight(.black)
                            Text("提醒一次")
                        }
                        .font(.system(size: 11, design: .rounded))
                    }

                    HStack(spacing: 8) {
                        Text("活跃时段")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("开始", selection: $reminderStartHour) {
                            ForEach(6..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 82)
                        Text("到")
                            .font(.system(size: 10))
                        Picker("结束", selection: $reminderEndHour) {
                            ForEach(7..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 82)
                    }

                    Text(reminderScheduler.nextFireLabel)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(reminderEnabled ? PieTheme.sage : .secondary)

                    HStack {
                        Text("应用在菜单栏运行时生效，勿扰时段不会弹出。")
                            .font(.system(size: 9.2))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack {
                        Button("先弹一条看看") { reminderScheduler.showTestReminder() }
                        Spacer()
                        Button("保存提醒时间") { reminderScheduler.reload(resetSchedule: true) }
                            .buttonStyle(.borderedProminent)
                            .tint(PieTheme.pink)
                    }
                }
                .onChange(of: reminderEnabled) { _, _ in
                    reminderScheduler.reload(resetSchedule: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("情绪垃圾桶暗号", systemImage: "lock.fill")
                        .font(.system(size: 12.5, weight: .black))
                    SecureField("当前暗号（默认 6666）", text: $currentPIN)
                        .textFieldStyle(.roundedBorder)
                    SecureField("新暗号，4–8 位数字", text: $newPIN)
                        .textFieldStyle(.roundedBorder)
                    if !pinStatus.isEmpty {
                        Text(pinStatus)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(pinStatus.contains("记住") ? PieTheme.sage : .red.opacity(0.78))
                    }
                    HStack {
                        Text("密码只负责应用内遮挡。")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("保存新暗号") { savePIN() }
                    }
                }

                Divider()

                HStack {
                    Label("Key 只保存在这台 Mac 的钥匙串中", systemImage: "key.fill")
                    Spacer()
                    Text("⌥ Space")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .frame(width: 340, height: 610)
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            content().textFieldStyle(.roundedBorder)
        }
    }

    private var providerHint: String {
        switch settings.provider {
        case .deepSeek: return "适合日常整理和拆解任务，中文效果好、调用成本低。"
        case .qwen: return "使用阿里云百炼 API Key；不同地域可能对应不同接口地址。"
        case .kimi: return "使用 Kimi 开放平台 API Key，并可按需更换模型名称。"
        case .openAI: return "使用 OpenAI API Key，与 ChatGPT 会员并不互通。"
        case .custom: return "支持采用 OpenAI Chat Completions 格式的第三方服务。"
        }
    }

    private func savePIN() {
        if !TrashPINStore.verify(currentPIN) {
            pinStatus = "当前暗号不对。"
        } else if newPIN.range(of: "^[0-9]{4,8}$", options: .regularExpression) == nil {
            pinStatus = "新暗号需要是 4–8 位数字。"
        } else {
            TrashPINStore.update(newPIN)
            currentPIN = ""
            newPIN = ""
            pinStatus = "新暗号记住啦 🔐"
            onPINChanged()
        }
    }

    private func testConnection() {
        settings.isTesting = true
        settings.statusMessage = "正在读取配置…"
        Task {
            guard let configuration = await settings.configuration(useDraftKey: true) else {
                settings.statusMessage = "请先填写 API Key。"
                settings.isTesting = false
                return
            }
            settings.statusMessage = "正在测试连接…"
            do {
                _ = try await AIService.shared.respond(to: "用不超过六个字回复：连接成功", action: .clarify, configuration: configuration)
                settings.statusMessage = "连接成功，可以用了。"
            } catch {
                settings.statusMessage = error.localizedDescription
            }
            settings.isTesting = false
        }
    }
}
