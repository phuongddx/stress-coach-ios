import SwiftUI

// MARK: - CharacterCreature

/// The five elemental companions from iOS Design System §11.
///
/// Each companion is rendered as an inline SVG (drawn with SwiftUI shapes),
/// never as an emoji.  Ripple (Water Otter) is the default and appears on
/// Home and in complications; the others are selectable as watch-face
/// themes.  Hex values are the canonical DS character palette.
enum CharacterCreature: String, CaseIterable, Codable, Sendable, Identifiable {
    case ripple   // Water Otter — free, default
    case blossom  // Forest Sprite — free
    case ember    // Flame Fox — plus
    case zephyr   // Wind Wisp — plus
    case lumi     // Star Owl — 30-day streak

    var id: String { rawValue }

    // MARK: - Metadata

    var displayName: String {
        switch self {
        case .ripple:  return "Ripple"
        case .blossom: return "Blossom"
        case .ember:   return "Ember"
        case .zephyr:  return "Zephyr"
        case .lumi:    return "Lumi"
        }
    }

    var subtitle: String {
        switch self {
        case .ripple:  return "Water Otter"
        case .blossom: return "Forest Sprite"
        case .ember:   return "Flame Fox"
        case .zephyr:  return "Wind Wisp"
        case .lumi:    return "Star Owl"
        }
    }

    /// Primary character colour (`--ripple`, `--blossom`, …).
    var primaryColor: Color {
        switch self {
        case .ripple:  return Color(hex: "#4FC3F7")
        case .blossom: return Color(hex: "#A5D6A7")
        case .ember:   return Color(hex: "#FFAB91")
        case .zephyr:  return Color(hex: "#D1C4E9")
        case .lumi:    return Color(hex: "#7986CB")
        }
    }

    /// Deeper companion colour used for gradient ramps.
    var secondaryColor: Color {
        switch self {
        case .ripple:  return Color(hex: "#0288D1")
        case .blossom: return Color(hex: "#81C784")
        case .ember:   return Color(hex: "#FF8A65")
        case .zephyr:  return Color(hex: "#B39DDB")
        case .lumi:    return Color(hex: "#5C6BC0")
        }
    }

    /// Accent halo tint used behind the character on Home / empty states.
    var haloColor: Color { primaryColor }
}

// MARK: - Default active character

extension CharacterCreature {
    /// The companion shown on Home and in complications.  Ripple is the
    /// watch default (matches iOS); the user's watch-face theme selection
    /// overrides this for the Settings preview only.
    static let watchDefault: CharacterCreature = .ripple
}

// MARK: - CharacterFaceView

/// Renders one of the five elemental companions as an inline vector
/// illustration.  Replaces the previous emoji-based face entirely.
///
/// The character's expression adapts to the current stress category:
/// smile for `.relaxed` / `.mild`, neutral for `.moderate`, frown for
/// `.high` / `.severe`.  An optional accent-coloured ring and radial halo
/// can be drawn behind the character.
struct CharacterFaceView: View {
    let creature: CharacterCreature
    /// `nil` renders a neutral face with no tier colour, for when there is no reading.
    var category: StressCategory? = .relaxed
    var size: CGFloat = 80
    var showsRing: Bool = false
    var showsHalo: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambientScale: CGFloat = 0.96

    var body: some View {
        ZStack {
            if showsHalo {
                Circle()
                    .fill(haloGradient)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .blur(radius: size * 0.06)
                    .scaleEffect(ambientScale)
                    .opacity(reduceMotion ? 1 : 0.85)
            }

            if showsRing {
                Circle()
                    .stroke((category?.color ?? WatchDesignTokens.mutedSystem).opacity(0.22),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            }

            characterBody
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            guard !reduceMotion else { ambientScale = 1; return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                ambientScale = 1.04
            }
        }
    }

    private var ringWidth: CGFloat { max(3, size * 0.045) }

    private var haloGradient: RadialGradient {
        RadialGradient(
            colors: [creature.haloColor.opacity(0.32), .clear],
            center: .center,
            startRadius: size * 0.05,
            endRadius: size * 0.5
        )
    }

    private var accessibilityLabel: String {
        guard let category else { return "\(creature.displayName), no reading yet" }
        let mood: String
        switch category {
        case .relaxed, .mild:
            mood = "calm"
        case .moderate:
            mood = "balanced"
        case .high:
            mood = "tense"
        case .severe:
            mood = "overwhelmed"
        }
        return "\(creature.displayName), \(mood). \(category.accessibilityDescription)"
    }

    // MARK: - Creature dispatch

    @ViewBuilder
    private var characterBody: some View {
        switch creature {
        case .ripple:  RippleOtter(size: size, category: category)
        case .blossom: BlossomSprite(size: size, category: category)
        case .ember:   EmberFox(size: size, category: category)
        case .zephyr:  ZephyrWisp(size: size, category: category)
        case .lumi:    LumiOwl(size: size, category: category)
        }
    }
}

// MARK: - Expression helpers

private extension StressCategory {
    /// `true` for high/severe — the character frowns.
    var isFrowning: Bool {
        switch self {
        case .high, .severe: return true
        default:             return false
        }
    }

    /// `true` for relaxed/mild — the character smiles.
    var isSmiling: Bool {
        switch self {
        case .relaxed, .mild: return true
        default:              return false
        }
    }
}

private extension Optional where Wrapped == StressCategory {
    var isFrowning: Bool { self?.isFrowning ?? false }
    var isSmiling: Bool { self?.isSmiling ?? false }
}

// MARK: - Ripple · Water Otter

/// Inline vector otter — exact shapes from iOS Design System §11.
/// Slate ink (#0A1929) features on a light muzzle (#E1F5FE).
struct RippleOtter: View {
    let size: CGFloat
    let category: StressCategory?

    private let fur    = Color(hex: "#4FC3F7")
    private let deep   = Color(hex: "#0288D1")
    private let muzzle = Color(hex: "#E1F5FE")
    private let ink    = Color(hex: "#0A1929")

    var body: some View {
        let s = size / 100
        return ZStack {
            // Shadow ellipse under feet
            Ellipse()
                .fill(deep.opacity(0.18))
                .frame(width: 64*s, height: 6*s)
                .offset(y: 34*s)
            // Feet
            Ellipse().fill(fur).frame(width: 12*s, height: 6*s).offset(x: -12*s, y: 28*s)
            Ellipse().fill(fur).frame(width: 12*s, height: 6*s).offset(x:  12*s, y: 28*s)
            // Body
            Ellipse().fill(fur).frame(width: 44*s, height: 40*s).offset(y: 0)
            // Head
            Ellipse().fill(fur).frame(width: 36*s, height: 32*s).offset(y: -24*s)
            // Ears
            Ellipse().fill(fur).frame(width: 12*s, height: 16*s).offset(x: -12*s, y: -32*s)
            Ellipse().fill(fur).frame(width: 12*s, height: 16*s).offset(x:  12*s, y: -32*s)
            Ellipse().fill(deep.opacity(0.4)).frame(width: 6*s, height: 8*s).offset(x: -12*s, y: -30*s)
            Ellipse().fill(deep.opacity(0.4)).frame(width: 6*s, height: 8*s).offset(x:  12*s, y: -30*s)
            // Muzzle
            Ellipse().fill(muzzle).frame(width: 24*s, height: 18*s).offset(y: -20*s)
            // Eyes
            Circle().fill(ink).frame(width: 4.4*s, height: 4.4*s).offset(x: -6*s, y: -24*s)
            Circle().fill(ink).frame(width: 4.4*s, height: 4.4*s).offset(x:  6*s, y: -24*s)
            // Nose
            Ellipse().fill(ink).frame(width: 3*s, height: 2*s).offset(y: -18*s)
            // Mouth
            MouthShape(smile: category.isSmiling, frown: category.isFrowning)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.2*s, lineCap: .round))
                .frame(width: 12*s, height: 6*s)
                .offset(y: -15*s)
        }
    }
}

// MARK: - Blossom · Forest Sprite

struct BlossomSprite: View {
    let size: CGFloat
    let category: StressCategory?

    private let leaf   = Color(hex: "#A5D6A7")
    private let cheek  = Color(hex: "#C8E6C9")
    private let crown  = Color(hex: "#66BB6A")
    private let ink    = Color(hex: "#1B5E20")

    var body: some View {
        let s = size / 100
        return ZStack {
            Ellipse().fill(leaf.opacity(0.2)).frame(width: 60*s, height: 6*s).offset(y: 34*s)
            // Body
            Ellipse().fill(leaf).frame(width: 44*s, height: 40*s)
            // Head
            Ellipse().fill(cheek).frame(width: 34*s, height: 30*s).offset(y: -24*s)
            // Leaf crown
            CrownLeaf().fill(crown).frame(width: 28*s, height: 16*s).offset(y: -40*s)
            // Cheeks
            Ellipse().fill(cheek).frame(width: 12*s, height: 14*s).offset(x: -8*s, y: -26*s)
            Ellipse().fill(cheek).frame(width: 12*s, height: 14*s).offset(x:  8*s, y: -26*s)
            // Eyes
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x: -6*s, y: -26*s)
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x:  6*s, y: -26*s)
            // Mouth
            MouthShape(smile: category.isSmiling, frown: category.isFrowning)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.0*s, lineCap: .round))
                .frame(width: 10*s, height: 5*s)
                .offset(y: -19*s)
        }
    }
}

private struct CrownLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Central leaf
        p.move(to: CGPoint(x: w/2, y: h))
        p.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: w*0.35, y: h*0.4))
        p.addQuadCurve(to: CGPoint(x: w/2, y: h), control: CGPoint(x: w*0.65, y: h*0.4))
        return p
    }
}

// MARK: - Ember · Flame Fox

struct EmberFox: View {
    let size: CGFloat
    let category: StressCategory?

    private let flame  = Color(hex: "#FFAB91")
    private let flameCore = Color(hex: "#FF7043")
    private let face   = Color(hex: "#FFCCBC")
    private let ink    = Color(hex: "#BF360C")

    var body: some View {
        let s = size / 100
        return ZStack {
            // Flame body
            FlameBody().fill(flame).frame(width: 56*s, height: 64*s).offset(y: -4*s)
            FlameBody().fill(flameCore.opacity(0.7)).frame(width: 40*s, height: 48*s).offset(y: 0)
            // Face
            Ellipse().fill(face).frame(width: 36*s, height: 32*s).offset(y: -2*s)
            // Ears (triangles)
            Triangle().fill(flameCore).frame(width: 12*s, height: 14*s).rotationEffect(.degrees(15)).offset(x: -14*s, y: -18*s)
            Triangle().fill(flameCore).frame(width: 12*s, height: 14*s).rotationEffect(.degrees(-15)).offset(x: 14*s, y: -18*s)
            // Eyes
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x: -6*s, y: -5*s)
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x:  6*s, y: -5*s)
            // Nose
            Ellipse().fill(ink).frame(width: 3*s, height: 2*s).offset(y: 2*s)
            // Mouth
            MouthShape(smile: category.isSmiling, frown: category.isFrowning)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.0*s, lineCap: .round))
                .frame(width: 10*s, height: 5*s)
                .offset(y: 5*s)
        }
    }
}

private struct FlameBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w/2, y: 0))
        p.addQuadCurve(to: CGPoint(x: w*0.2, y: h*0.45), control: CGPoint(x: w*0.32, y: h*0.2))
        p.addQuadCurve(to: CGPoint(x: w*0.1, y: h*0.75), control: CGPoint(x: w*0.22, y: h*0.6))
        p.addQuadCurve(to: CGPoint(x: w*0.35, y: h), control: CGPoint(x: w*0.18, y: h*0.95))
        p.addQuadCurve(to: CGPoint(x: w/2, y: h*0.92), control: CGPoint(x: w*0.42, y: h*0.98))
        p.addQuadCurve(to: CGPoint(x: w*0.65, y: h), control: CGPoint(x: w*0.58, y: h*0.98))
        p.addQuadCurve(to: CGPoint(x: w*0.9, y: h*0.75), control: CGPoint(x: w*0.82, y: h*0.95))
        p.addQuadCurve(to: CGPoint(x: w*0.8, y: h*0.45), control: CGPoint(x: w*0.78, y: h*0.6))
        p.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: w*0.68, y: h*0.2))
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Zephyr · Wind Wisp

struct ZephyrWisp: View {
    let size: CGFloat
    let category: StressCategory?

    private let pelt   = Color(hex: "#EDE7F6")
    private let crown  = Color(hex: "#D1C4E9")
    private let swirl  = Color(hex: "#B39DDB")
    private let ink    = Color(hex: "#311B92")

    var body: some View {
        let s = size / 100
        return ZStack {
            // Ear tufts
            Ellipse().fill(crown).frame(width: 10*s, height: 28*s).offset(x: -14*s, y: -28*s)
            Ellipse().fill(crown).frame(width: 10*s, height: 28*s).offset(x:  14*s, y: -28*s)
            Ellipse().fill(swirl.opacity(0.6)).frame(width: 5*s, height: 18*s).offset(x: -14*s, y: -26*s)
            Ellipse().fill(swirl.opacity(0.6)).frame(width: 5*s, height: 18*s).offset(x:  14*s, y: -26*s)
            // Body
            Ellipse().fill(pelt).frame(width: 48*s, height: 44*s)
            // Head
            Ellipse().fill(crown).frame(width: 32*s, height: 28*s).offset(y: -22*s)
            // Cheek swirls
            WindSwirl().stroke(swirl, style: StrokeStyle(lineWidth: 2*s, lineCap: .round))
                .frame(width: 12*s, height: 12*s).offset(x: -22*s, y: 2*s)
            WindSwirl().stroke(swirl, style: StrokeStyle(lineWidth: 2*s, lineCap: .round))
                .frame(width: 12*s, height: 12*s).offset(x: 22*s, y: 2*s).rotationEffect(.degrees(180))
            // Eyes
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x: -6*s, y: -24*s)
            Circle().fill(ink).frame(width: 4*s, height: 4*s).offset(x:  6*s, y: -24*s)
            // Mouth
            MouthShape(smile: category.isSmiling, frown: category.isFrowning)
                .stroke(ink, style: StrokeStyle(lineWidth: 0.9*s, lineCap: .round))
                .frame(width: 10*s, height: 5*s)
                .offset(y: -17*s)
        }
    }
}

private struct WindSwirl: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w, y: h*0.4))
        p.addQuadCurve(to: CGPoint(x: 0, y: h*0.4), control: CGPoint(x: w*0.5, y: h*0.1))
        p.addQuadCurve(to: CGPoint(x: w*0.3, y: h), control: CGPoint(x: 0, y: h*0.7))
        return p
    }
}

// MARK: - Lumi · Star Owl

struct LumiOwl: View {
    let size: CGFloat
    let category: StressCategory?

    private let pelt    = Color(hex: "#7986CB")
    private let head    = Color(hex: "#9FA8DA")
    private let eyeDisc = Color(hex: "#E8EAF6")
    private let pupil   = Color(hex: "#1A237E")
    private let beak    = Color(hex: "#FFD54F")
    private let star    = Color(hex: "#FE9901")

    var body: some View {
        let s = size / 100
        return ZStack {
            // Body
            Ellipse().fill(pelt).frame(width: 44*s, height: 48*s)
            // Head
            Ellipse().fill(head).frame(width: 40*s, height: 36*s).offset(y: -20*s)
            // Stars
            Star().fill(star).frame(width: 8*s, height: 8*s).offset(x: -24*s, y: -30*s)
            Star().fill(star).frame(width: 8*s, height: 8*s).offset(x:  24*s, y: -30*s)
            // Eye discs
            Circle().fill(eyeDisc).frame(width: 12*s, height: 12*s).offset(x: -8*s, y: -22*s)
            Circle().fill(eyeDisc).frame(width: 12*s, height: 12*s).offset(x:  8*s, y: -22*s)
            // Pupils
            Circle().fill(pupil).frame(width: 7*s, height: 7*s).offset(x: -8*s, y: -22*s)
            Circle().fill(pupil).frame(width: 7*s, height: 7*s).offset(x:  8*s, y: -22*s)
            // Beak
            Triangle().fill(beak).frame(width: 6*s, height: 5*s).rotationEffect(.degrees(180)).offset(y: -14*s)
        }
    }
}

private struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        let ri = r * 0.45
        for i in 0..<10 {
            let angle = Angle.degrees(Double(i) * 36 - 90).radians
            let radius = i.isMultiple(of: 2) ? r : ri
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * radius,
                             y: c.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - MouthShape

/// Reusable smile / neutral / frown mouth used by every companion.
/// `smile = true` curves up at the corners; `frown = true` curves down;
/// otherwise it draws a soft neutral line.
private struct MouthShape: Shape {
    var smile: Bool
    var frown: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h/2))
        let controlY: CGFloat
        if smile { controlY = h }      // curve down → corners up (smile)
        else if frown { controlY = 0 } // curve up → corners down (frown)
        else { controlY = h/2 }        // flat neutral
        p.addQuadCurve(
            to: CGPoint(x: w, y: h/2),
            control: CGPoint(x: w/2, y: controlY)
        )
        return p
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Character Roster") {
    CharacterRosterPreview()
}

private struct CharacterRosterPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(CharacterCreature.allCases) { creature in
                VStack(spacing: 6) {
                    CharacterFaceView(creature: creature, category: .relaxed, size: 72, showsHalo: true)
                    Text(creature.displayName)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchDesignTokens.muted)
                }
            }
        }
        .padding()
        .background(WatchDesignTokens.canvas)
    }
}

#Preview("Expressions") {
    ExpressionPreview()
}

private struct ExpressionPreview: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(StressCategory.allCases) { tier in
                VStack(spacing: 4) {
                    CharacterFaceView(creature: .ripple, category: tier, size: 64, showsRing: true)
                    Text(tier.glyphLabel)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(WatchDesignTokens.muted)
                }
            }
        }
        .padding()
        .background(WatchDesignTokens.canvas)
    }
}
#endif
