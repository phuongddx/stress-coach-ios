import Foundation

@MainActor
@Observable
final class OnboardingSuccessViewModel {
    var personalBaseline: PersonalBaseline?

    private let repository: StressRepositoryProtocol

    init(repository: StressRepositoryProtocol) {
        self.repository = repository
        loadBaseline()
    }

    func loadBaseline() {
        Task {
            do {
                personalBaseline = try await repository.getBaseline()
            } catch {
                personalBaseline = nil
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
