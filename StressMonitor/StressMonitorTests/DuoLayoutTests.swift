import CoreGraphics
import SwiftUI
import Testing
@testable import StressMonitor

/// The iPhone Duo layout switch: one column in compact width (phones, the
/// outer display, a Split View half), two in regular width (the inner
/// display), with the gap between the columns on the fold.
@Suite("Duo layout")
struct DuoLayoutTests {

    @Test("regular width uses two columns; compact and unknown use one")
    func testMode_FollowsHorizontalSizeClass() {
        #expect(DuoLayout.mode(for: .regular) == .twoColumns)
        #expect(DuoLayout.mode(for: .compact) == .singleColumn)
        #expect(DuoLayout.mode(for: nil) == .singleColumn)
    }

    @Test("without a fold the columns are equal with a gutter in the middle")
    func testSplit_WithoutFold_CentersGutter() {
        let split = DuoLayout.split(length: 1000, fold: nil, gutter: 16)
        #expect(split == DuoLayout.Split(leading: 492, gap: 16, trailing: 492))
    }

    @Test("a fold becomes the gap, so nothing sits on the hinge")
    func testSplit_WithWideFold_GapIsFold() {
        let split = DuoLayout.split(length: 1000, fold: 480...520, gutter: 16)
        #expect(split == DuoLayout.Split(leading: 480, gap: 40, trailing: 480))
    }

    @Test("an off-centre fold still sets the split")
    func testSplit_OffCentreFold_FollowsFold() {
        let split = DuoLayout.split(length: 1000, fold: 590...610, gutter: 16)
        #expect(split == DuoLayout.Split(leading: 590, gap: 20, trailing: 390))
    }

    @Test("a thin hinge is widened to the gutter on both sides")
    func testSplit_ThinFold_WidenedToGutter() {
        let split = DuoLayout.split(length: 1000, fold: 499...501, gutter: 16)
        #expect(split == DuoLayout.Split(leading: 492, gap: 16, trailing: 492))
    }

    @Test("a fold near an edge is ignored so no column is squeezed")
    func testSplit_FoldNearEdge_Ignored() {
        let split = DuoLayout.split(length: 1000, fold: 100...120, gutter: 16, minimumPart: 200)
        #expect(split == DuoLayout.Split(leading: 492, gap: 16, trailing: 492))
    }

    @Test("a fold outside the container is ignored")
    func testSplit_FoldOutside_Ignored() {
        let split = DuoLayout.split(length: 400, fold: 600...640, gutter: 16, minimumPart: 100)
        #expect(split == DuoLayout.Split(leading: 192, gap: 16, trailing: 192))
    }

    @Test("parts always add up to the length, and never go negative")
    func testSplit_PartsAddUp() {
        for length in [0, 10, 320, 1000] as [CGFloat] {
            for fold in [nil, 300...330, 0...5] as [ClosedRange<CGFloat>?] {
                let split = DuoLayout.split(length: length, fold: fold)
                #expect(split.leading >= 0 && split.gap >= 0 && split.trailing >= 0)
                #expect(abs(split.leading + split.gap + split.trailing - length) < 0.001)
            }
        }
    }

    @Test("splits side by side when wide (book), stacked when tall (laptop, inner portrait)")
    func testSplitAxis_FollowsLongerSide() {
        #expect(DuoLayout.splitAxis(for: CGSize(width: 1100, height: 780)) == .horizontal)
        #expect(DuoLayout.splitAxis(for: CGSize(width: 780, height: 1100)) == .vertical)
    }
}
