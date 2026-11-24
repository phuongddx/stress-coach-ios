import SwiftUI

// MARK: - Duo layout rules
//
// iPhone Duo support (iOS 27.1 SDK). Layout is decided by the size class and
// the container's own geometry, never by device model, idiom, orientation or
// `UIScreen.main`:
//
// | Where                          | Horizontal size class | Layout        |
// |--------------------------------|-----------------------|---------------|
// | Any iPhone, Duo outer display  | compact               | one column    |
// | Duo inner display, full screen | regular               | two columns   |
// | One half of Split View         | compact               | one column    |
//
// In two columns the split sits on the fold: the gap between the columns is
// the division region the system reports (flat or partly folded), so no text
// or control lands on the hinge. Where no fold is reported (below iOS 27.1,
// or a device without one) the gap is a normal gutter in the middle.

enum DuoLayout {
    enum Mode: Equatable {
        case singleColumn
        case twoColumns
    }

    /// Gap between the two columns when no fold is reported.
    static let gutter: CGFloat = 16

    /// One column in compact width (phones, the Duo outer display, a half of
    /// Split View), two in regular width (the Duo inner display).
    static func mode(for horizontalSizeClass: UserInterfaceSizeClass?) -> Mode {
        horizontalSizeClass == .regular ? .twoColumns : .singleColumn
    }

    /// Splits `length` into a leading part, a gap and a trailing part.
    ///
    /// - Parameters:
    ///   - length: the container's extent along the split axis.
    ///   - fold: the fold region's range along the same axis, in the
    ///     container's coordinates, or nil when there is no fold.
    ///   - minimumPart: the smallest part that still makes sense. A fold
    ///     that leaves less than this on either side is ignored, so a fold
    ///     at the very edge of a Split View half never squeezes a column.
    static func split(
        length: CGFloat,
        fold: ClosedRange<CGFloat>?,
        gutter: CGFloat = DuoLayout.gutter,
        minimumPart: CGFloat = 200
    ) -> Split {
        let length = max(0, length)
        if let fold {
            let start = max(0, fold.lowerBound)
            let end = min(length, fold.upperBound)
            if end > start, start >= minimumPart, length - end >= minimumPart {
                // Never narrower than the normal gutter: a thin hinge line
                // still needs breathing room on both sides.
                let extra = max(0, gutter - (end - start)) / 2
                return Split(
                    leading: start - extra,
                    gap: (end - start) + extra * 2,
                    trailing: length - end - extra
                )
            }
        }
        let part = max(0, (length - gutter) / 2)
        return Split(leading: part, gap: length - part * 2, trailing: part)
    }

    struct Split: Equatable {
        var leading: CGFloat
        var gap: CGFloat
        var trailing: CGFloat
    }

    /// Splits along the longer side: side by side when wide (book pose, inner
    /// landscape), stacked when tall (laptop pose, inner portrait).
    static func splitAxis(for size: CGSize) -> Axis {
        size.width >= size.height ? .horizontal : .vertical
    }
}

// MARK: - Fold lookup

extension GeometryProxy {
    /// The fold region's range along `axis`, in this proxy's local
    /// coordinates. Includes the fold while the device is flat (inactive), so
    /// the gap stays on the hinge in every open pose (Apple: pass
    /// `.includeInactive` for column decisions). Always nil below iOS 27.1,
    /// where only system components know where the fold is, and on devices
    /// without a fold.
    ///
    /// Also nil when the app is built with an SDK older than iOS 27.1 (the
    /// API does not exist there): the gap is then a centred gutter.
    func foldRange(along axis: Axis) -> ClosedRange<CGFloat>? {
        #if canImport(SwiftUI, _version: 8.0.85) // iOS 27.1 SDK
        guard #available(iOS 27.1, *) else { return nil }
        let regions = reservedRegions(kind: .division, options: .includeInactive)
        // A fold across the split axis divides it; one along it does not.
        let crossing = regions.map(\.frame).filter { frame in
            axis == .horizontal ? frame.height >= frame.width : frame.width >= frame.height
        }
        guard let frame = crossing.first else { return nil }
        return axis == .horizontal ? frame.minX...frame.maxX : frame.minY...frame.maxY
        #else
        return nil
        #endif
    }
}

// MARK: - Fold-aware split

/// Two views side by side (or stacked) with the gap on the fold.
///
/// Used for the Duo inner display. Each part is laid out on its own, so give
/// each its own `ScrollView` when its content can be long.
struct FoldAwareSplit<Leading: View, Trailing: View>: View {
    /// Nil splits along the container's longer side.
    var axis: Axis?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    init(
        axis: Axis? = .horizontal,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.axis = axis
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let axis = axis ?? DuoLayout.splitAxis(for: proxy.size)
            let length = axis == .horizontal ? proxy.size.width : proxy.size.height
            let split = DuoLayout.split(length: length, fold: proxy.foldRange(along: axis))
            if axis == .horizontal {
                HStack(spacing: 0) {
                    leading.frame(width: split.leading)
                    Color.clear.frame(width: split.gap).accessibilityHidden(true)
                    trailing.frame(width: split.trailing)
                }
            } else {
                VStack(spacing: 0) {
                    leading.frame(height: split.leading)
                    Color.clear.frame(height: split.gap).accessibilityHidden(true)
                    trailing.frame(height: split.trailing)
                }
            }
        }
    }
}

// MARK: - Accessibility identifiers for UI tests

enum DuoLayoutID {
    static let twoColumns = "duo.layout.twoColumns"
    static let singleColumn = "duo.layout.singleColumn"
}
