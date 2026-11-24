import SwiftUI

// MARK: - Character Illustration

/// Character illustration that renders the companion artwork.
///
/// Ripple (the default when no `characterId` is supplied) renders a Ripple v2
/// drawing picked by ``RipplePose``: either the explicit `pose:` argument or
/// `mood.pose`. Other companions keep the ``CharacterAssetResolver`` path.
/// The ambient `.characterAnimation(for:)` applies to every companion.
struct StressBuddyIllustration: View {
    let mood: RippleMood
    let size: CGFloat
    let characterId: String?
    let evolution: EvolutionStage?
    let pose: RipplePose?
    let crop: RippleCrop
    let lightChip: Bool

    init(
        mood: RippleMood,
        size: CGFloat,
        pose: RipplePose? = nil,
        crop: RippleCrop = .full,
        lightChip: Bool = false
    ) {
        self.mood = mood
        self.size = size
        self.characterId = nil
        self.evolution = nil
        self.pose = pose
        self.crop = crop
        self.lightChip = lightChip
    }

    init(
        characterId: String,
        evolution: EvolutionStage,
        mood: RippleMood,
        size: CGFloat,
        pose: RipplePose? = nil,
        crop: RippleCrop = .full,
        lightChip: Bool = false
    ) {
        self.mood = mood
        self.size = size
        self.characterId = characterId
        self.evolution = evolution
        self.pose = pose
        self.crop = crop
        self.lightChip = lightChip
    }

    /// The pose Ripple shows: explicit, else derived from the mood.
    var resolvedPose: RipplePose { pose ?? mood.pose }

    private var isRipple: Bool {
        guard let characterId else { return true }
        return CharacterAssetCatalog.assetName(for: characterId) == RipplePose.base.assetName
    }

    var body: some View {
        Group {
            if isRipple {
                RippleV2Image(
                    pose: resolvedPose,
                    crop: crop,
                    lightChip: lightChip,
                    size: size * (evolution?.scaleFactor ?? 1)
                )
            } else if let characterId, let evolution {
                CharacterAssetResolver.characterView(
                    for: characterId,
                    evolution: evolution,
                    mood: mood,
                    size: size
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: size, height: size)
        .characterAnimation(for: mood)
    }
}

// MARK: - Ripple v2 Image

/// One Ripple v2 drawing, optionally on the light-mode teal chip.
///
/// The suit outline is 1.34:1 on the light canvas, so small head crops sit on
/// a `#206A5D` circle in light mode (spec §4.3). The chip colour is clear in
/// dark mode, where the suit reads on its own.
struct RippleV2Image: View {
    let pose: RipplePose
    var crop: RippleCrop = .head
    var lightChip: Bool = false
    let size: CGFloat

    private var assetName: String {
        crop == .head ? pose.headAssetName : pose.assetName
    }

    var body: some View {
        ZStack {
            if lightChip {
                Circle().fill(Color.V2.rippleChip)
            }
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .padding(lightChip ? size * 0.08 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pose.accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Preview

#Preview("All Moods") {
    HStack(spacing: 20) {
        ForEach(RippleMood.allCases, id: \.self) { mood in
            VStack {
                StressBuddyIllustration(mood: mood, size: 120)
            }
        }
    }
    .padding()
    .background(Color.Wellness.adaptiveBackground)
}

#Preview("Ripple") {
    HStack(spacing: 20) {
        ForEach(RippleMood.allCases, id: \.self) { mood in
            StressBuddyIllustration(characterId: "ripple", evolution: .droplet, mood: mood, size: 120)
        }
    }
    .padding()
    .background(Color.Wellness.adaptiveBackground)
}

#Preview("Ripple v2 poses") {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(RipplePose.allCases, id: \.self) { pose in
                VStack {
                    StressBuddyIllustration(mood: .serene, size: 96, pose: pose)
                    StressBuddyIllustration(mood: .serene, size: 40, pose: pose, crop: .head, lightChip: true)
                }
            }
        }
        .padding()
    }
    .background(Color.V2.bg)
}

#Preview("Dark Mode") {
    HStack(spacing: 20) {
        ForEach(RippleMood.allCases, id: \.self) { mood in
            VStack {
                StressBuddyIllustration(mood: mood, size: 120)
            }
        }
    }
    .padding()
    .background(Color.Wellness.adaptiveBackground)
    .preferredColorScheme(.dark)
}
