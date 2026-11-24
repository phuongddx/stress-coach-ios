import SwiftData
import SwiftUI

struct HistoryTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryTimelineViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let viewModel {
                    filterChipRow(viewModel)

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }

                    summaryTiles

                    if viewModel.dayGroups.isEmpty && !viewModel.isLoading {
                        V2Card {
                            V2StateView(
                                systemImage: "clock",
                                title: "No readings yet",
                                message: "Readings appear here as your Apple Watch records HRV through the day.",
                                actionTitle: "Refresh"
                            ) {
                                Task { await viewModel.loadInitial() }
                            }
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
        .background(Color.V2.bg.ignoresSafeArea())
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
        V2Chip(title: filter.title, isSelected: filter == viewModel.selectedFilter) {
            HapticManager.shared.buttonPress()
            viewModel.selectFilter(filter)
        }
        .frame(minHeight: V2Metrics.minTouchTarget)
    }

    // MARK: - Summary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summaryTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            summaryTile(title: "7-day average", value: viewModel?.summary?.sevenDayAverage)
            summaryTile(title: "Best", value: viewModel?.summary?.best)
            summaryTile(title: "Peak", value: viewModel?.summary?.peak)
        }
    }

    private func summaryTile(title: String, value: Int?) -> some View {
        let category = value.map { StressResult.category(for: Double($0)) }
        let displayValue = value.map(String.init) ?? "—"

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.v2Number(.title2))
                    .foregroundStyle(category?.color ?? Color.V2.ink3)
                if let category {
                    V2TierBadge(category: category, compact: true, font: .footnote)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(displayValue) stress score")
    }

    // MARK: - Timeline

    private func dayGroup(
        _ group: HistoryDayGroup,
        viewModel: HistoryTimelineViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayTitle(group.date))
                    .v2Eyebrow()
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(group.entries.count) \(group.entries.count == 1 ? "reading" : "readings")")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, measurement in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.V2.line)
                            .frame(height: 0.5)
                            .padding(.leading, V2Metrics.margin)
                    }
                    NavigationLink(value: viewModel.route(for: measurement)) {
                        HistoryTimelineEntryCard(measurement: measurement)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous))
            .v2CardBackground()
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
                        .tint(Color.V2.accent)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                }
                Text("Load earlier")
            }
        }
        .buttonStyle(.v2(.secondary))
        .disabled(viewModel.isLoading)
    }

    private func errorCard(_ message: String) -> some View {
        V2ErrorCard(title: "Couldn't load history", message: message)
            .accessibilityElement(children: .combine)
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                V2Skeleton(width: 60, height: 32, cornerRadius: 16)
                V2Skeleton(width: 80, height: 32, cornerRadius: 16)
                V2Skeleton(width: 60, height: 32, cornerRadius: 16)
            }
            SkeletonBlock(height: 74)
            V2Skeleton(width: 90, height: 14)
            SkeletonBlock(height: 64)
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
    .background(Color.V2.bg)
}
