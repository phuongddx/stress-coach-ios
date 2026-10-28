import Foundation

extension HealthKitServiceProtocol {
    /// Whole years since the Health-app date of birth, or nil when the user has
    /// not set one. Callers must not substitute an assumed age.
    func chronologicalAge(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let components = dateOfBirthComponents,
              let dateOfBirth = calendar.date(from: components),
              let years = calendar.dateComponents([.year], from: dateOfBirth, to: now).year,
              years > 0 else {
            return nil
        }
        return years
    }
}
