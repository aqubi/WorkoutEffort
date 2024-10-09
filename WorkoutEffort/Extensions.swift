//
//  Extensions.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/02.
//
import HealthKit
import SwiftUI

extension TimeInterval {
    var timeString: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "00:00"
    }
}

extension HKQuantityType {
    var displayName: String {
        let id = HKQuantityTypeIdentifier(rawValue: self.identifier)
        switch id {
        case .activeEnergyBurned: return "Active Energy"
        case .basalEnergyBurned: return "Basal Energy"
        case .distanceWalkingRunning: return "Distance"
        case .heartRate: return "Heart Rate"
        case .estimatedWorkoutEffortScore: return "Estimated Workout Effort"
        case .workoutEffortScore: return "Workout Effort"
        default: return "?"
        }
    }
}

extension HKQuantityType {
    func valueString(_ quantity: HKQuantity) -> String {
        let id = HKQuantityTypeIdentifier(rawValue: self.identifier)
        switch id {
        case .activeEnergyBurned, .basalEnergyBurned:
            let unit = HKUnit.kilocalorie()
            let value = quantity.doubleValue(for: unit)
            let fractionLength: Int = value >= 1 ? 2 : 3
            return "\(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(unit.unitString)"
        case .distanceWalkingRunning:
            let unit = HKUnit.meterUnit(with: .kilo)
            let value = quantity.doubleValue(for: unit)
            let fractionLength: Int = value >= 1 ? 2 : 3
            return "\(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(unit.unitString)"
        case .heartRate:
            let value = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            return "\(Int(value).formatted(.number)) bpm"
        case .estimatedWorkoutEffortScore, .workoutEffortScore:
            let value = quantity.doubleValue(for: .appleEffortScore())
            return "\(Int(value).formatted(.number))"
        default:
            return "\(quantity)"
        }
    }
}

extension HKHealthStore {

    func requestAuthorization(_ types: Set<HKSampleType>) async throws {
        let status = try await self.statusForAuthorizationRequest(toShare: types, read: types)
        if status == .shouldRequest {
            try await self.requestAuthorization(toShare: types, read: types)
        }
    }

    func queryWorkouts(limit: Int = 50) async throws -> [HKWorkout] {
        let query = HKSampleQueryDescriptor(predicates: [.workout()], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: limit)
        let workouts = try await query.result(for: self)
        return workouts
    }

    func queryWorkoutEffortSamples(_ type: HKQuantityType, workout: HKWorkout) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let query = HKSampleQueryDescriptor(predicates: [.sample(type: type, predicate: predicate)], sortDescriptors: [], limit: 0)
        return try await query.result(for: self)
    }

    func queryWorkoutEffortRelationship(workout: HKWorkout, option: HKWorkoutEffortRelationshipQueryOptions) async throws -> [HKWorkoutEffortRelationship] {
        let predicate = HKQuery.predicateForObject(with: workout.uuid)
        let query = HKWorkoutEffortRelationshipQueryDescriptor(predicate: predicate, anchor: nil, option: option)
        let result = try await query.result(for: self)
        return result.relationships
    }

    func queryWorkoutEffortMostRelevant(workout: HKWorkout) async throws -> HKQuantitySample? {
        guard let relationship = try await queryWorkoutEffortRelationship(workout: workout, option: .mostRelevant).last else { return nil }
        guard let samples = relationship.samples else { return nil }
        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            if quantitySample.quantityType.is(compatibleWith: .appleEffortScore()) {
                return quantitySample
            }
        }
        return nil
    }

    func queryWorkoutEffortSampleValue(_ type: HKQuantityType, workout: HKWorkout) async throws -> Int? {
        let samples = try await queryWorkoutEffortSamples(type, workout: workout)
        if let sample = samples.last as? HKQuantitySample {
            return Int(sample.quantity.doubleValue(for: .appleEffortScore()))
        } else {
            return nil
        }
    }
}

extension HKWorkout {

    func valueString(_ typeId: HKQuantityTypeIdentifier) -> String? {
        let type = HKQuantityType(typeId)
        if let quantity = self.quantity(type) {
            return type.valueString(quantity)
        }
        return nil
    }

    func quantity(_ type: HKQuantityType) -> HKQuantity? {
        guard let statistics = self.statistics(for: type) else { return nil }
        if type.aggregationStyle == .cumulative {
             return statistics.sumQuantity()
        } else {
            if let quantity = statistics.mostRecentQuantity() {
                return quantity
            } else if let quantity = statistics.averageQuantity() {
                return quantity
            } else {
                return nil
            }
        }
    }

    static var sample: HKWorkout {
        let duration:TimeInterval = 310
        let date = Date()
        return HKWorkout(activityType: .walking, start: date.addingTimeInterval(-duration), end: date, duration: duration,
                         totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 12),
                         totalDistance: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 1.3), device: .local(), metadata: nil)
    }
}

extension Date {
    func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "d MMM y, HH:mm:ss", options: 0, locale: Locale.current)!
        return formatter.string(from: self)
    }
}

extension Text {
    func captionEmphasis<S>(_ content: S = .primary) -> some View where S : ShapeStyle {
        self
            .font(.caption2).fontWeight(.bold)
            .padding(2)
            .padding(.horizontal, 5)
            .blendMode(.destinationOut)
            .background(content)
            .clipShape(Capsule())
            .compositingGroup()
    }

    func captionEmphasis2<S>(_ content: S = .primary) -> some View where S : ShapeStyle {
        self
            .font(.caption2).fontWeight(.medium)
            .padding(2)
            .padding(.horizontal, 5)
            .foregroundStyle(content)
            .background {
                Capsule()
                    .stroke(content, lineWidth: 1)
            }

    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2)
        VStack {
            Text("Sample")
                .captionEmphasis(.secondary)
            Text("Sample")
                .captionEmphasis2(.secondary)
        }
    }
}
