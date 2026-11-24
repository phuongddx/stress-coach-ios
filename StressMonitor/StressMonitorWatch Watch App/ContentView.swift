import SwiftUI

/// Root watch UI: HIG-compliant list-based navigation.
///
/// Replaces the 6-page swipe `TabView` (which violated Apple HIG's
/// 2–4 page limit for page-based navigation) with a root
/// `NavigationStack` and a list menu.  Every screen is one tap away;
/// the Digital Crown scrolls naturally; and users always know where
/// they are.
///
/// The canvas is the V2 true-black watch background; each
/// screen composes its own background on top of this base.
struct ContentView: View {
    @State private var viewModel = WatchStressViewModel()

    var body: some View {
        NavigationStack {
            WatchMenuView(viewModel: viewModel)
        }
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif
