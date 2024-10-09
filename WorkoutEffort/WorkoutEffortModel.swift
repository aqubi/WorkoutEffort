//
//  WorkoutEffortModel.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/08.
//

import HealthKit

@Observable @MainActor class WorkoutEffortModel: Identifiable {

    let id = UUID()
    let workout: HKWorkout
    var effortSample: HKQuantitySample?

    var source: HKSource { return workout.sourceRevision.source }

    var startDate: Date { return workout.startDate }
    var endDate: Date { return workout.endDate }

    var dateString: String {
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = DateFormatter.dateFormat(fromTemplate: "d MMM y, HH:mm:ss", options: 0, locale: Locale.current)!
        return formatter.string(from: workout.startDate, to: workout.endDate)
    }

    var durationString: String {
        return workout.duration.timeString
    }

    var effortValue: Int? {
        if let value = effortSample?.quantity.doubleValue(for: .appleEffortScore()) {
            return Int(value)
        } else {
            return nil
        }
    }

    init(workout: HKWorkout, effortSample: HKQuantitySample? = nil) {
        self.workout = workout
        self.effortSample = effortSample
    }

    func valueString(_ typeId: HKQuantityTypeIdentifier) -> String? {
        return workout.valueString(typeId)
    }

    func reloadEffortSamples(_ store: HKHealthStore) async throws {
        self.effortSample = try await store.queryWorkoutEffortMostRelevant(workout: workout)
    }

    static var sample: WorkoutEffortModel {
        let workout = HKWorkout.sample
        let quantity = HKQuantity(unit: .appleEffortScore(), doubleValue: 2)
        return .init(workout: workout, effortSample: HKQuantitySample(type: .init(.workoutEffortScore), quantity: quantity, start: workout.startDate, end: workout.endDate))
    }
}

extension WorkoutEffortModel: Hashable {
    nonisolated static func == (lhs: WorkoutEffortModel, rhs: WorkoutEffortModel) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(workout)
        hasher.combine(effortSample)
    }
}
