import SwiftData
import SwiftUI

struct HistoryTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryTimelineViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let viewModel {
                    filterChipRow(viewModel)

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }

                    summaryTiles

                    if viewModel.dayGroups.isEmpty && !viewModel.isLoading {
                        NoDataCard(dataType: .timeline) {
                            Task { await viewModel.loadInitial() }
                        }
                    } else {
                        ForEach(viewModel.dayGroups) { group in
                            dayGroup(group, viewModel: viewModel)
                        }
                    }

                    if viewModel.canLoadMore {
                        loadEarlierButton(viewModel)
                    }
                } else {
                    loadingSkeleton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Stress History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            let loadedViewModel = HistoryTimelineViewModel(
                repository: StressRepository(modelContext: modelContext)
            )
            viewModel = loadedViewModel
            await loadedViewModel.loadInitial()
        }
    }

    // MARK: - Filters

    private func filterChipRow(_ viewModel: HistoryTimelineViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    filterChip(filter, viewModel: viewModel)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func filterChip(
        _ filter: HistoryFilter,
        viewModel: HistoryTimelineViewModel
    ) -> some View {
        let isActive = filter == viewModel.selectedFilter

        return Button {
            HapticManager.shared.buttonPress()
            viewModel.selectFilter(filter)
        } label: {
            Text(filter.title)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .foregroundStyle(
                    isActive
                        ? Color.white
                        : Color.Wellness.adaptiveSecondaryText
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isActive
                        ? AnyShapeStyle(Color.primaryBlue)
                        : AnyShapeStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.08))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
    }

    // MARK: - Summary

    private var summaryTiles: some View {
        HStack(alignment: .top, spacing: 10) {
            summaryTile(title: "avg · 7d", value: viewModel?.summary?.sevenDayAverage)
            summaryTile(title: "best", value: viewModel?.summary?.best)
            summaryTile(title: "peak", value: viewModel?.summary?.peak)
        }
    }

    private func summaryTile(title: String, value: Int?) -> some View {
        let valueColor = value.map {
            Color.stressColor(for: StressResult.category(for: Double($0)))
        } ?? Color.Wellness.adaptiveSecondaryText
        let displayValue = value.map(String.init) ?? "—"

        return VStack(alignment: .leading, spacing: 4) {
            Text(displayValue)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(valueColor)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(displayValue) stress score")
    }

    // MARK: - Timeline

    private func dayGroup(
        _ group: HistoryDayGroup,
        viewModel: HistoryTimelineViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayTitle(group.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Spacer()

                Text("\(group.entries.count) \(group.entries.count == 1 ? "reading" : "readings")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }

            ForEach(group.entries) { measurement in
                NavigationLink(value: viewModel.route(for: measurement)) {
                    HistoryTimelineEntryCard(measurement: measurement)
                }
                .buttonStyle(.plain)
                .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
            }
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        if date == startOfToday {
            return "Today"
        }
        if date == calendar.date(byAdding: .day, value: -1, to: startOfToday) {
            return "Yesterday"
        }

        return date.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
    }

    // MARK: - Footer and states

    private func loadEarlierButton(_ viewModel: HistoryTimelineViewModel) -> some View {
        Button {
            HapticManager.shared.buttonPress()
            Task { await viewModel.loadEarlier() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                }
                Text("Load earlier")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.stressColor(for: .high))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 10) {
            SkeletonBlock(height: 40)
            SkeletonBlock(height: 74)
            SkeletonBlock(height: 64)
            SkeletonBlock(height: 64)
        }
    }
}

#Preview("Stress History") {
    NavigationStack {
        HistoryTimelineView()
    }
    .modelContainer(
        for: StressMeasurement.self,
        inMemory: true
    )
    .background(HomeCharacterDesignTokens.homeBackground)
}
