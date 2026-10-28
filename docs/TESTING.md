# Testing

How to run, write, and organize tests for StressMonitor.

---

## Overview

The project uses **Swift Testing** and **XCTest** together. Test files live in `StressMonitor/StressMonitorTests/` (bundle ID: `stress.ai.com.StressMonitorTests`) — not the orphaned root-level `StressMonitorTests/`, which is outside the Xcode project and never builds (see `AGENTS.md` → "Orphaned code").

Coverage spans dozens of suites across the algorithm, repository, sync, LLM, StoreKit, and ViewModel layers — see `AGENTS.md` for the current build/test setup rather than a fixed file list here.

---

## Running Tests

**Canonical invocation:** the full `xcodebuild test` command — project, scheme, destination, and every flag CI runs — is documented once, in `AGENTS.md` under "Build & test". That block mirrors `.github/workflows/_test.yml` flag-for-flag; this doc does not duplicate it.

- **From Xcode:** select the **StressMonitor** scheme, press `⌘U` to run all tests, or use the Test Navigator (`⌘6`) for individual tests.
- **Single class / single method:** append `-only-testing:StressMonitorTests/<Suite>` (or `/<Suite>/<method>`) to the AGENTS.md command — examples are listed there.
- **Local helper:** `python3 scripts/run-tests.py` auto-detects (or boots) a simulator and runs the suite.

---

## Writing Tests

### Naming Convention

- Test methods: `test[Condition]` or `test[Method]_[Condition]`
- Examples: `testNormalStress`, `testComputeScoreAtBaseline`

### Floating Point Comparisons

Use `XCTAssertEqual` with `accuracy` for floating point values:

```swift
func testScoreAtBaseline() {
    let score = MorningReadinessService.computeScore(morningHRV: 60, baseline: 60)
    XCTAssertEqual(score, 50, accuracy: 1, "Score at baseline should be ~50")
}
```

### Test Structure

```swift
import XCTest
@testable import StressMonitor

final class MyServiceTests: XCTestCase {
    var service: MyService!

    override func setUp() {
        super.setUp()
        service = MyService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testNormalCase() async throws {
        let result = try await service.calculate(input: 50)
        XCTAssertEqual(result.level, 0, accuracy: 10)
    }
}
```

### Mocking Services

Use the protocol-based injection pattern. All services have protocols (e.g., `HealthKitServiceProtocol`, `StressAlgorithmServiceProtocol`, `StoreKitServiceProtocol`). Inject mock implementations in tests:

```swift
let vm = StressViewModel(
    healthKit: MockHealthKitService(),
    algorithm: MockStressAlgorithm()
)
```

The project includes `MockServices.swift` and `MockStoreKitService.swift` for this purpose.

---

## CI Testing

`.github/workflows/ci.yml` → `_test.yml` runs, on every PR: SwiftLint (advisory) + iOS/watchOS/widget builds, plus the full `StressMonitorTests` suite in the `test` job — the same invocation documented in `AGENTS.md`. CI does not skip test execution.

---

## Test Coverage Gaps

The following areas need dedicated tests (part of blocker B3):

- `MultiFactorStressCalculator` — weight normalization, graceful degradation
- Individual stress factors (`HRVStressFactor`, `HeartRateStressFactor`, etc.)
- `StressRepository` — CRUD, batch operations, sync queries
- `CloudKitSyncEngine` — sync orchestration, conflict resolution
- `SupabaseLLMService` — SSE parsing, context building
- `StoreKitService` — product fetching, transaction monitoring
- ViewModels — state transitions, error handling

---

## Related Docs

- [DEVELOPMENT.md](./DEVELOPMENT.md) — Coding conventions and mock patterns
- [CONFIGURATION.md](./CONFIGURATION.md) — CI workflow details
