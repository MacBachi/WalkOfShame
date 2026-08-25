import Foundation
import FTMSKit

#if canImport(HealthKit)
import HealthKit

/// Schreibt eine Trainingseinheit nach Apple Health.
///
/// Die Samples werden **laufend** angehängt, nicht erst am Ende — bricht die App
/// mitten im Workout ab, ist alles bis dahin bereits im Builder.
///
/// Workout-Typ ist per Default `.walking`: das Gerät kann laut `0x2AD4` maximal
/// 6,00 km/h, ist also ein Walking Pad. `.running` wäre eine Schönfärberei, die
/// Health bei der Kalorienschätzung in die Irre führt.
@MainActor
public final class HealthKitSchreiber {

    private let store = HKHealthStore()
    private var builder: HKWorkoutBuilder?
    private let aktivitaet: HKWorkoutActivityType

    public private(set) var laeuft = false

    public init(aktivitaet: HKWorkoutActivityType = .walking) {
        self.aktivitaet = aktivitaet
    }

    public static var verfuegbar: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var zuSchreibendeTypen: Set<HKSampleType> {
        [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKObjectType.workoutType()
        ]
    }

    /// Fragt die Schreibrechte an. Health zeigt den Dialog nur einmal; danach
    /// muss der Nutzer in der Health-App nachjustieren.
    public func frageBerechtigungAn() async throws {
        guard Self.verfuegbar else { throw HealthFehler.nichtVerfuegbar }
        try await store.requestAuthorization(toShare: zuSchreibendeTypen, read: [])
    }

    /// Startet die Aufzeichnung.
    public func starte(beginn: Date = Date()) async throws {
        guard Self.verfuegbar else { throw HealthFehler.nichtVerfuegbar }
        guard builder == nil else { return }

        let konfiguration = HKWorkoutConfiguration()
        konfiguration.activityType = aktivitaet
        konfiguration.locationType = .indoor

        let neuer = HKWorkoutBuilder(healthStore: store, configuration: konfiguration, device: .local())
        try await neuer.beginCollection(at: beginn)
        builder = neuer
        laeuft = true
    }

    /// Hängt einen Zuwachs als Samples an. Leere Zuwächse werden übersprungen —
    /// HealthKit mag keine Nullsamples.
    public func fuegeHinzu(_ zuwachs: Zuwachs) async throws {
        guard let builder, !zuwachs.istLeer else { return }
        guard zuwachs.bis > zuwachs.von else { return }

        var samples: [HKSample] = []

        if zuwachs.distanzMeter > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: zuwachs.distanzMeter),
                start: zuwachs.von, end: zuwachs.bis
            ))
        }
        if zuwachs.energieKcal > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: zuwachs.energieKcal),
                start: zuwachs.von, end: zuwachs.bis
            ))
        }
        if let bpm = zuwachs.herzfrequenz {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()),
                                     doubleValue: Double(bpm)),
                start: zuwachs.von, end: zuwachs.bis
            ))
        }

        guard !samples.isEmpty else { return }
        try await builder.addSamples(samples)
    }

    /// Schließt das Workout ab und schreibt es nach Health.
    @discardableResult
    public func beende(ende: Date = Date()) async throws -> HKWorkout? {
        guard let builder else { return nil }
        try await builder.endCollection(at: ende)
        let workout = try await builder.finishWorkout()
        self.builder = nil
        laeuft = false
        return workout
    }

    /// Bricht ab, ohne zu schreiben (z. B. Sitzung verworfen).
    public func verwirf() {
        builder?.discardWorkout()
        builder = nil
        laeuft = false
    }

    public enum HealthFehler: Error, CustomStringConvertible {
        case nichtVerfuegbar

        public var description: String {
            "HealthKit ist auf diesem Gerät nicht verfügbar."
        }
    }
}
#endif
