import AppKit
import Combine
import SwiftUI

enum RoomCatCharacter {
    case badam
    case guagua

    var name: String { self == .badam ? "巴旦木" : "呱呱" }
}

private enum RoomPalette {
    static let ink = Color(red: 0.17, green: 0.125, blue: 0.115)
    static let paper = Color(red: 0.99, green: 0.965, blue: 0.90)
    static let wall = Color(red: 0.93, green: 0.85, blue: 0.81)
    static let floor = Color(red: 0.79, green: 0.54, blue: 0.57)
    static let chocolate = Color(red: 0.34, green: 0.16, blue: 0.20)
    static let pink = Color(red: 0.88, green: 0.53, blue: 0.62)
    static let sage = Color(red: 0.62, green: 0.72, blue: 0.62)
    static let blue = Color(red: 0.56, green: 0.70, blue: 0.76)
    static let yellow = Color(red: 0.91, green: 0.77, blue: 0.39)
}

struct RoomSceneView: View {
    let counts: [PieItemKind: Int]
    let onOpen: (PieItemKind) -> Void
    let onFortune: () -> Void
    let onResurface: () -> Void
    let onCat: (RoomCatCharacter) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var roomAlive = false
    @State private var catHovered = false
    @State private var currentDate = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {
            roomBackground

            Button { onOpen(.idea) } label: {
                IdeaWindowView(alive: roomAlive && !reduceMotion, count: counts[.idea, default: 0])
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("打开灵感窗")
            .position(x: 97, y: 159)

            Button(action: onFortune) {
                GachaMachineView()
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("扭一颗今日猫猫蛋")
            .position(x: 350, y: 160)

            Button { onOpen(.work) } label: {
                WorkDeskView(count: counts[.work, default: 0])
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("打开工作书桌")
            .position(x: 108, y: 335)

            Button { onOpen(.personal) } label: {
                PersonalSofaView(count: counts[.personal, default: 0])
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("打开个人沙发")
            .position(x: 323, y: 331)

            rug
                .position(x: 215, y: 526)

            ZStack {
                RoomCatArtwork(alive: roomAlive && !reduceMotion, hovered: catHovered)
                    .frame(width: 194, height: 174)

                HStack(spacing: 0) {
                    Button { onCat(.badam) } label: { Color.clear }
                        .help("和巴旦木说话")
                        .accessibilityLabel("巴旦木")
                    Button { onCat(.guagua) } label: { Color.clear }
                        .help("和呱呱说话")
                        .accessibilityLabel("呱呱")
                }
                .buttonStyle(.plain)
                .frame(width: 166, height: 105)
                .offset(y: 11)
            }
            .onHover { hovering in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    catHovered = hovering
                }
            }
            .position(x: 215, y: 493)

            YarnBallView(alive: roomAlive && !reduceMotion)
                .position(x: 215, y: 566)
                .allowsHitTesting(false)

            Button(action: onResurface) {
                OldIdeaBoxView()
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("回捞旧灵感")
            .position(x: 82, y: 550)

            Button { onOpen(.trash) } label: {
                EmotionTrashView(count: counts[.trash, default: 0], alive: roomAlive && !reduceMotion)
            }
            .buttonStyle(RoomObjectButtonStyle())
            .help("打开秘密情绪垃圾桶")
            .position(x: 367, y: 542)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                roomAlive = true
            }
        }
        .onReceive(clock) { currentDate = $0 }
    }

    private var roomBackground: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                roomWallColor

                Rectangle()
                    .fill(roomFloorColor)
                    .frame(height: max(0, proxy.size.height - 430))
                    .overlay {
                        Canvas { context, size in
                            for x in stride(from: 0.0, through: size.width, by: 70) {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(path, with: .color(RoomPalette.ink.opacity(0.10)), lineWidth: 1.5)
                            }
                            for y in stride(from: 0.0, through: size.height, by: 50) {
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(path, with: .color(RoomPalette.ink.opacity(0.10)), lineWidth: 1.5)
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(RoomPalette.ink).frame(height: 4)
                    }
                    .offset(y: 430)

                Canvas { context, size in
                    for index in 0..<100 {
                        let x = CGFloat((index * 43) % 431)
                        let y = CGFloat((index * 79) % 749)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: index % 3 == 0 ? 2 : 1, height: 1)),
                            with: .color(RoomPalette.ink.opacity(0.08))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var roomWallColor: Color {
        switch Calendar.current.component(.hour, from: currentDate) {
        case 6..<12: return Color(red: 0.96, green: 0.88, blue: 0.84)
        case 12..<18: return RoomPalette.wall
        case 18..<22: return Color(red: 0.88, green: 0.76, blue: 0.77)
        default: return Color(red: 0.48, green: 0.43, blue: 0.53)
        }
    }

    private var roomFloorColor: Color {
        switch Calendar.current.component(.hour, from: currentDate) {
        case 6..<18: return RoomPalette.floor
        case 18..<22: return Color(red: 0.70, green: 0.43, blue: 0.49)
        default: return Color(red: 0.36, green: 0.31, blue: 0.40)
        }
    }

    private var rug: some View {
        Ellipse()
            .fill(RoomPalette.yellow.opacity(0.92))
            .frame(width: 205, height: 82)
            .overlay(Ellipse().stroke(RoomPalette.ink, lineWidth: 3))
            .shadow(color: RoomPalette.ink.opacity(0.8), radius: 0, x: 5, y: 7)
            .overlay(alignment: .bottomTrailing) {
                Text("PAW!")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(RoomPalette.ink.opacity(0.20))
                    .rotationEffect(.degrees(-12))
                    .padding(.trailing, 24)
                    .padding(.bottom, 11)
            }
    }
}

private struct YarnBallView: View {
    let alive: Bool

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 3, y: 24))
                path.addCurve(
                    to: CGPoint(x: 52, y: 22),
                    control1: CGPoint(x: 18, y: 43),
                    control2: CGPoint(x: 38, y: 3)
                )
            }
            .stroke(RoomPalette.ink.opacity(0.62), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            ZStack {
                Circle()
                    .fill(RoomPalette.pink)
                    .overlay(Circle().stroke(RoomPalette.ink, lineWidth: 2.3))
                Path { path in
                    path.move(to: CGPoint(x: 5, y: 12))
                    path.addCurve(to: CGPoint(x: 23, y: 9), control1: CGPoint(x: 10, y: 3), control2: CGPoint(x: 18, y: 17))
                    path.move(to: CGPoint(x: 6, y: 18))
                    path.addCurve(to: CGPoint(x: 22, y: 17), control1: CGPoint(x: 12, y: 10), control2: CGPoint(x: 17, y: 24))
                }
                .stroke(RoomPalette.paper.opacity(0.78), lineWidth: 1.5)
            }
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(alive ? 320 : 0))
            .offset(x: alive ? 24 : -24, y: alive ? -2 : 3)
        }
        .frame(width: 80, height: 48)
        .animation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true), value: alive)
    }
}

private struct RoomObjectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RoomLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoomPalette.paper)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.7))
            .shadow(color: RoomPalette.ink, radius: 0, x: 2, y: 2)
    }
}

private struct RoomCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 8, weight: .black))
            .frame(minWidth: 20, minHeight: 20)
            .background(RoomPalette.yellow)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.7))
    }
}

private struct IdeaWindowView: View {
    let alive: Bool
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(RoomPalette.blue)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(RoomPalette.ink, lineWidth: 3))
                .frame(width: 155, height: 140)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.55, green: 0.75, blue: 0.78))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(RoomPalette.ink, lineWidth: 2.5))
                .frame(width: 133, height: 115)

            Group {
                Text("✦").offset(x: -38, y: -33).scaleEffect(alive ? 1.20 : 0.58)
                Text("✧").offset(x: 2, y: -18).scaleEffect(alive ? 0.58 : 1.15)
                Text("✦").offset(x: 40, y: -34).scaleEffect(alive ? 1.12 : 0.55)
            }
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(RoomPalette.paper)
            .shadow(color: RoomPalette.ink, radius: 0, x: 1.5, y: 1.5)

            Text("☁️")
                .font(.system(size: 24))
                .offset(x: alive ? 10 : -4, y: 26)

            HStack(spacing: 82) {
                curtain(left: true)
                    .rotationEffect(.degrees(alive ? 7 : 3), anchor: .topLeading)
                curtain(left: false)
                    .rotationEffect(.degrees(alive ? -7 : -3), anchor: .topTrailing)
            }

            RoomCountBadge(count: count).offset(x: 70, y: -67)
            RoomLabel(title: "灵感窗").offset(y: 80)
        }
        .frame(width: 175, height: 170)
    }

    private func curtain(left: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: left ? 9 : 2,
            bottomLeadingRadius: left ? 5 : 12,
            bottomTrailingRadius: left ? 12 : 5,
            topTrailingRadius: left ? 2 : 9
        )
        .fill(RoomPalette.pink)
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: left ? 9 : 2,
                bottomLeadingRadius: left ? 5 : 12,
                bottomTrailingRadius: left ? 12 : 5,
                topTrailingRadius: left ? 2 : 9
            )
            .stroke(RoomPalette.ink, lineWidth: 2)
        }
        .frame(width: 34, height: 112)
    }
}

private struct GachaMachineView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(RoomPalette.pink)
                .frame(width: 106, height: 145)
                .overlay(RoundedRectangle(cornerRadius: 36).stroke(RoomPalette.ink, lineWidth: 3))

            RoundedRectangle(cornerRadius: 32)
                .fill(RoomPalette.blue.opacity(0.45))
                .frame(width: 78, height: 67)
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(RoomPalette.ink, lineWidth: 2.5))
                .offset(y: -33)
                .overlay {
                    HStack(spacing: -6) {
                        capsule(RoomPalette.yellow).rotationEffect(.degrees(-17))
                        capsule(RoomPalette.sage).rotationEffect(.degrees(12))
                        capsule(RoomPalette.pink).rotationEffect(.degrees(4))
                    }
                    .offset(y: -32)
                }

            Text("猫猫扭蛋")
                .font(.system(size: 7.5, weight: .black))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(RoomPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(RoomPalette.ink, lineWidth: 1.5))
                .offset(y: 7)

            Circle()
                .fill(RoomPalette.yellow)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(RoomPalette.ink, lineWidth: 2.5))
                .overlay(Capsule().fill(RoomPalette.paper).frame(width: 5, height: 21).overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.5)))
                .offset(x: 21, y: 32)

            Capsule().fill(RoomPalette.chocolate).frame(width: 24, height: 7).offset(x: -25, y: 27)
            RoundedRectangle(cornerRadius: 7).fill(RoomPalette.chocolate).frame(width: 60, height: 24).offset(y: 58)
            RoomLabel(title: "猫猫扭蛋机").offset(y: 87)
        }
        .frame(width: 125, height: 185)
    }

    private func capsule(_ color: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [color, color, RoomPalette.paper, RoomPalette.paper], startPoint: .top, endPoint: .bottom))
            .frame(width: 24, height: 18)
            .overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.5))
    }
}

private struct WorkDeskView: View {
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(RoomPalette.chocolate.opacity(0.86)).frame(width: 181, height: 28).offset(y: 11)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(RoomPalette.ink, lineWidth: 3).frame(width: 181, height: 28).offset(y: 11))
            HStack(spacing: 130) {
                Rectangle().fill(RoomPalette.chocolate).frame(width: 14, height: 44)
                Rectangle().fill(RoomPalette.chocolate).frame(width: 14, height: 44)
            }
            .overlay { HStack(spacing: 130) { Rectangle().stroke(RoomPalette.ink, lineWidth: 2).frame(width: 14, height: 44); Rectangle().stroke(RoomPalette.ink, lineWidth: 2).frame(width: 14, height: 44) } }
            .offset(y: 46)

            RoundedRectangle(cornerRadius: 6).fill(RoomPalette.blue).frame(width: 76, height: 51)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(RoomPalette.ink, lineWidth: 3))
                .overlay(Text("🐱").font(.system(size: 23)))
                .offset(x: -24, y: -22)
            Text("!!!").font(.system(size: 12, weight: .black)).frame(width: 42, height: 30).background(RoomPalette.paper).overlay(Rectangle().stroke(RoomPalette.ink, lineWidth: 2)).rotationEffect(.degrees(7)).offset(x: 59, y: -11)
            RoomCountBadge(count: count).offset(x: 83, y: -55)
            RoomLabel(title: "工作书桌").offset(y: 83)
        }
        .frame(width: 195, height: 145)
    }
}

private struct PersonalSofaView: View {
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23).fill(RoomPalette.sage).frame(width: 163, height: 74).overlay(RoundedRectangle(cornerRadius: 23).stroke(RoomPalette.ink, lineWidth: 3)).offset(y: -9)
            RoundedRectangle(cornerRadius: 13).fill(RoomPalette.sage.opacity(0.86)).frame(width: 177, height: 40).overlay(RoundedRectangle(cornerRadius: 13).stroke(RoomPalette.ink, lineWidth: 3)).offset(y: 28)
            RoundedRectangle(cornerRadius: 9).fill(RoomPalette.pink).frame(width: 50, height: 43).overlay(RoundedRectangle(cornerRadius: 9).stroke(RoomPalette.ink, lineWidth: 2)).overlay(Text("♥").font(.system(size: 20, weight: .black))).rotationEffect(.degrees(7)).offset(x: 48, y: -17)
            HStack(spacing: 122) { Rectangle().fill(RoomPalette.chocolate).frame(width: 12, height: 17); Rectangle().fill(RoomPalette.chocolate).frame(width: 12, height: 17) }.offset(y: 54)
            RoomCountBadge(count: count).offset(x: 82, y: -61)
            RoomLabel(title: "个人沙发").offset(y: 82)
        }
        .frame(width: 195, height: 145)
    }
}

private struct OldIdeaBoxView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.69, green: 0.47, blue: 0.34)).frame(width: 116, height: 72).overlay(RoundedRectangle(cornerRadius: 10).stroke(RoomPalette.ink, lineWidth: 3))
            Text("旧灵感").font(.system(size: 14, weight: .black)).rotationEffect(.degrees(-4))
            Text("〜").font(.system(size: 54, weight: .black)).rotationEffect(.degrees(55)).offset(x: 42, y: -52)
            RoomLabel(title: "旧灵感纸箱").offset(y: 50)
        }
        .frame(width: 135, height: 125)
    }
}

private struct EmotionTrashView: View {
    let count: Int
    let alive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.52, green: 0.31, blue: 0.36)).frame(width: 83, height: 95).overlay(RoundedRectangle(cornerRadius: 12).stroke(RoomPalette.ink, lineWidth: 3))
            RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.43, green: 0.25, blue: 0.28)).frame(width: 99, height: 18).overlay(RoundedRectangle(cornerRadius: 7).stroke(RoomPalette.ink, lineWidth: 3)).offset(y: -47)
            Image(systemName: "trash.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(RoomPalette.paper)
            RoomCountBadge(count: count).offset(x: 43, y: -57)
            RoomLabel(title: "情绪垃圾桶").offset(y: 68)
        }
        .frame(width: 125, height: 145)
        .rotationEffect(.degrees(alive && count > 1 ? 2.5 : 0), anchor: .bottom)
    }
}

private struct RoomCatArtwork: View {
    let alive: Bool
    let hovered: Bool
    @State private var previewOutfit = ""
    @State private var previewVisible = false
    @State private var previewToken = UUID()

    var body: some View {
        ZStack {
            Group {
                if let url = Bundle.main.url(forResource: "TwoCats", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else if let url = Bundle.main.url(forResource: "RoomCat", withExtension: "svg"),
                          let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "cat.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(RoomPalette.paper)
                        .padding(24)
                }
            }

            if previewVisible, let emoji = GachaWardrobe.emoji(for: previewOutfit) {
                HStack(spacing: 4) {
                    Text("✨")
                    Text(emoji)
                    Text("试戴一下！")
                }
                .font(.system(size: 10, weight: .black, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoomPalette.paper)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.8))
                .shadow(color: RoomPalette.ink, radius: 0, x: 2, y: 3)
                .offset(x: -42, y: -67)
                .transition(.scale(scale: 0.45).combined(with: .opacity))
            }

            HStack(spacing: 20) {
                RoomCatNameTag(name: "巴旦木", symbol: "⚡️")
                RoomCatNameTag(name: "呱呱", symbol: "☁️")
            }
            .offset(y: 67)
        }
        .scaleEffect(hovered ? 1.055 : (alive ? 1.012 : 1))
        .rotationEffect(.degrees(hovered ? -2.5 : (alive ? 0.8 : -0.8)))
        .offset(x: alive ? 2 : -2, y: alive ? -2 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.58), value: hovered)
        .onReceive(NotificationCenter.default.publisher(for: .previewCatOutfit)) { note in
            guard let outfitID = note.object as? String else { return }
            let token = UUID()
            previewToken = token
            previewOutfit = outfitID
            withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
                previewVisible = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.7))
                guard previewToken == token else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    previewVisible = false
                }
            }
        }
    }
}

private struct RoomCatNameTag: View {
    let name: String
    let symbol: String

    var body: some View {
        Text("\(symbol) \(name)")
            .font(.system(size: 7.5, weight: .black, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoomPalette.paper)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(RoomPalette.ink, lineWidth: 1.2))
    }
}
