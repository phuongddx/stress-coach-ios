import Foundation

// MARK: - Science Topic

/// The claim areas where the app states health information. Every on-screen
/// number carrying medical meaning maps to one topic, so an info control beside
/// that number can deep-link to the sources behind it (App Review Guideline
/// 1.4.1 — medical information requires citations the user can find easily).
enum ScienceTopic: String, CaseIterable, Identifiable, Hashable, Codable {
    case stressScore
    case biologicalAge
    case breathing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stressScore:   "Stress score"
        case .biologicalAge: "Biological age"
        case .breathing:     "Breathing exercises"
        }
    }

    /// Plain-language description of what the app computes for this topic.
    var summary: String {
        switch self {
        case .stressScore:
            "Your score weighs heart rate variability, heart rate, sleep, activity and recovery. HRV carries the largest weight because it is the signal most consistently linked to stress in the research."
        case .biologicalAge:
            "Biological age compares your HRV and resting heart rate with published age-group averages. It is a wellness estimate, not a clinical measurement of ageing."
        case .breathing:
            "Slow paced breathing is used because breathing near six breaths per minute produces the largest heart-rate oscillations in most people."
        }
    }

    /// Where the app's method departs from the cited research. Shown with the
    /// sources so the user can judge the numbers rather than trust them blindly.
    var limitation: String {
        switch self {
        case .stressScore:
            "Stress is not measured directly. The score is an estimate derived from heart and activity signals, which are also affected by illness, caffeine, alcohol, medication and exercise."
        case .biologicalAge:
            "The published HRV reference values come from 24-hour ECG recordings, while Apple Watch measures HRV in short windows. Values from different recording lengths are not directly comparable, so read the estimate as a trend for you rather than a clinical figure."
        case .breathing:
            "The strongest effects in the research come from breathing at about six breaths per minute. The app's patterns are slower, and one session shows a short-term change rather than a lasting one."
        }
    }
}

// MARK: - Science Citation

/// One peer-reviewed source backing a health claim the app makes.
struct ScienceCitation: Identifiable, Hashable {
    let id: String
    let topic: ScienceTopic
    /// What this source is cited for, in the app's own terms.
    let claim: String
    let authors: String
    let title: String
    let publication: String
    let url: URL

    var reference: String { "\(authors). \(title). \(publication)." }
}

// MARK: - Catalog

extension ScienceCitation {

    /// Every source behind the app's health claims.
    ///
    /// Keep this in step with the constants it justifies: the HRV and resting
    /// heart-rate norm tables in `BioAgeCalculator`, the factor weights in
    /// `FactorWeights`, and the breathing patterns in the Action tab.
    static let all: [ScienceCitation] = [
        ScienceCitation(
            id: "kim-2018-hrv-stress",
            topic: .stressScore,
            claim: "Why heart rate variability carries the largest weight in the score",
            authors: "Kim H-G, Cheon E-J, Bai D-S, Lee YH, Koo B-H",
            title: "Stress and Heart Rate Variability: A Meta-Analysis and Review of the Literature",
            publication: "Psychiatry Investigation, 2018;15(3):235-245",
            url: URL(string: "https://doi.org/10.30773/pi.2017.08.17")!
        ),
        ScienceCitation(
            id: "shaffer-2017-hrv-norms",
            topic: .stressScore,
            claim: "What HRV metrics mean, and why recording length changes the numbers",
            authors: "Shaffer F, Ginsberg JP",
            title: "An Overview of Heart Rate Variability Metrics and Norms",
            publication: "Frontiers in Public Health, 2017;5:258",
            url: URL(string: "https://doi.org/10.3389/fpubh.2017.00258")!
        ),
        ScienceCitation(
            id: "task-force-1996-hrv",
            topic: .stressScore,
            claim: "The measurement standard behind SDNN, the HRV value the app reads",
            authors: "Task Force of the European Society of Cardiology and the North American Society of Pacing and Electrophysiology",
            title: "Heart rate variability: Standards of measurement, physiological interpretation, and clinical use",
            publication: "Circulation, 1996;93(5):1043-1065",
            url: URL(string: "https://doi.org/10.1161/01.CIR.93.5.1043")!
        ),
        ScienceCitation(
            id: "umetani-1998-hrv-age",
            topic: .biologicalAge,
            claim: "The HRV-by-age reference values behind your biological age estimate",
            authors: "Umetani K, Singer DH, McCraty R, Atkinson M",
            title: "Twenty-Four Hour Time Domain Heart Rate Variability and Heart Rate: Relations to Age and Gender Over Nine Decades",
            publication: "Journal of the American College of Cardiology, 1998;31(3):593-601",
            url: URL(string: "https://doi.org/10.1016/S0735-1097(97)00554-8")!
        ),
        ScienceCitation(
            id: "quer-2020-resting-hr",
            topic: .biologicalAge,
            claim: "The resting heart-rate-by-age values, and why your own baseline matters more than the average",
            authors: "Quer G, Gouda P, Galarnyk M, Topol EJ, Steinhubl SR",
            title: "Inter- and intraindividual variability in daily resting heart rate and its associations with age, sex, sleep, BMI, and time of year: a longitudinal cohort study of 92,457 adults",
            publication: "PLOS ONE, 2020;15(2):e0227709",
            url: URL(string: "https://doi.org/10.1371/journal.pone.0227709")!
        ),
        ScienceCitation(
            id: "lehrer-2014-resonance-breathing",
            topic: .breathing,
            claim: "Why slow paced breathing raises heart rate variability",
            authors: "Lehrer PM, Gevirtz R",
            title: "Heart rate variability biofeedback: how and why does it work?",
            publication: "Frontiers in Psychology, 2014;5:756",
            url: URL(string: "https://doi.org/10.3389/fpsyg.2014.00756")!
        )
    ]

    static func citations(for topic: ScienceTopic) -> [ScienceCitation] {
        all.filter { $0.topic == topic }
    }
}
