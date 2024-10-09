//
//  EditWorkoutEffortView.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/02.
//

import SwiftUI
import HealthKit

struct EditWorkoutEffortView: View {
    let healthStore: HKHealthStore
    @State var workout: WorkoutEffortModel

    // Add Effort
    @State private var effort: Int
    @State private var effortType: HKQuantityType = .init(.workoutEffortScore)

    // Samples
    @State private var effortSamples:[HKQuantityType:[HKSample]] = [:]
    @State private var relationships:[HKWorkoutEffortRelationship] = []
    @State private var mostRelevantRelationsips:[HKWorkoutEffortRelationship] = []

    @State private var error: Error?

    @Environment(\.dismiss) private var dismiss
    private let effortTypes:[HKQuantityType] = [.init(.workoutEffortScore), .init(.estimatedWorkoutEffortScore)]

    init(healthStore: HKHealthStore, workout: WorkoutEffortModel) {
        self.healthStore = healthStore
        self.workout = workout

        var effortValue: Int = 1
        if let value = workout.effortSample?.quantity.doubleValue(for: .appleEffortScore()) {
            effortValue = Int(value)
        }
        self._effort = State(initialValue: effortValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section("New Effort") {
                        Picker("Effort Type", selection: $effortType) {
                            ForEach(effortTypes, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }

                        Picker("Workout Effort", selection: $effort) {
                            Text("0 Skipped").tag(0)
                            Text("1 Easy").tag(1)
                            Text("2 Easy").tag(2)
                            Text("3 Easy").tag(3)
                            Text("4 Moderate").tag(4)
                            Text("5 Moderate").tag(5)
                            Text("6 Moderate").tag(6)
                            Text("7 Hard").tag(7)
                            Text("8 Hard").tag(8)
                            Text("9 All Out").tag(9)
                            Text("10 All Out").tag(10)
                        }
                        .pickerStyle(.wheel)

                        Button("Add Related Effort", systemImage: "plus") {
                            relateEffortSample(effort, type: effortType)
                        }
                    }

                    let mostRelevants = mostRelevantUUIDs()
                    ForEach(relationships, id: \.self) { relationship in
                        Section("Workout Effort in Relationship") {
                            if let activity = relationship.activity {
                                LabeledContent("Activity", value: "\(activity.uuid.uuidString)")
                            }
                            if let samples = relationship.samples {
                                ForEach(samples, id: \.self) { sample in
                                    WorkoutEffortSampleView(sample: sample, isMostRelevant: mostRelevants.contains(sample.uuid.uuidString))
                                        .swipeActions {
                                            Button("Unrelate", systemImage: "personalhotspot.slash") {
                                                unrelatedEffortSample(sample, activity: relationship.activity)
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                    if relationships.isEmpty {
                        Section("Workout Effort in Relationship") {
                            EmtpyEffortSampleView()
                        }
                    }

                    ForEach(effortTypes, id: \.self) { type in
                        Section(type.displayName) {
                            if let samples = effortSamples[type], !samples.isEmpty {
                                ForEach(samples, id: \.self) { sample in
                                    WorkoutEffortSampleView(sample: sample, isMostRelevant: mostRelevants.contains(sample.uuid.uuidString))
                                        .swipeActions {
                                            Button("Delete", systemImage: "trash") {
                                                deleteEffortSample(sample)
                                            }
                                            .tint(.red)
                                        }
                                }
                            } else {
                                EmtpyEffortSampleView()
                            }
                        }
                    }
                }

                ErrorView(error: $error)
            }
            .navigationTitle("Edit Workout Effort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                Task {
                    try await loadEffortSamples()
                }
            }
        }
    }

    private func loadEffortSamples() async throws {
        let workout = self.workout.workout
        self.relationships = try await healthStore.queryWorkoutEffortRelationship(workout: workout, option: .default)
        self.mostRelevantRelationsips = try await healthStore.queryWorkoutEffortRelationship(workout: workout, option: .mostRelevant)

        let types: [HKQuantityType] = [.init(.workoutEffortScore), .init(.estimatedWorkoutEffortScore)]
        for type in types {
            let samples = try await healthStore.queryWorkoutEffortSamples(type, workout: workout)
            self.effortSamples[type] = samples
        }
    }

    private func mostRelevantUUIDs() -> [String] {
        var result:[String] = []
        for relation in mostRelevantRelationsips {
            guard let samples = relation.samples else { continue }
            result.append(contentsOf: samples.map{$0.uuid.uuidString})
        }
        return result
    }

    private func refreshData() async throws {
        try await loadEffortSamples()
        try await workout.reloadEffortSamples(healthStore)
    }

    //MARK: - Actions

    private func relateEffortSample(_ effort: Int, type: HKQuantityType) {
        Task {
            do {
                self.error = nil
                let quantity = HKQuantity(unit: .appleEffortScore(), doubleValue: Double(effort))
                let sample = HKQuantitySample(type: type, quantity: quantity, start: workout.startDate, end: workout.endDate)
                try await healthStore.relateWorkoutEffortSample(sample, with: workout.workout, activity: nil)
                try await refreshData()
            } catch {
                print(error)
                self.error = error
            }
        }
    }

    /// Unrelates a workout effort sample from a workout
    private func unrelatedEffortSample(_ sample: HKSample, activity: HKWorkoutActivity?) {
        Task {
            do {
                self.error = nil
                if try await healthStore.unrelateWorkoutEffortSample(sample, from: workout.workout, activity: activity) {
                    try await refreshData()
                }
            } catch {
                print(error)
                self.error = error
            }
        }
    }

    private func deleteEffortSample(_ sample: HKSample) {
        Task {
            do {
                self.error = nil
                try await healthStore.delete(sample)
                try await refreshData()
            } catch {
                print(error)
                self.error = error
            }
        }
    }
}

private struct WorkoutEffortSampleView: View {
    let sample: HKSample
    let isMostRelevant: Bool

    var body: some View {
        VStack(alignment: .leading) {
            if isMostRelevant {
                Text("Most Relevant".uppercased())
                    .captionEmphasis(.accent)
            }
            if let quantitySample = sample as? HKQuantitySample {
                let unit = HKUnit.appleEffortScore()
                if quantitySample.quantity.is(compatibleWith: unit) {
                    let value = quantitySample.quantity.doubleValue(for: unit)
                    LabeledContent(quantitySample.quantityType.displayName, value: "\(Int(value))")
                } else {
                    LabeledContent(quantitySample.quantityType.displayName, value: "\(quantitySample.quantity)")
                }
            }
            LabeledContent("Date", value: timeString(from: sample.startDate, to: sample.endDate))
            LabeledContent("Source", value: sample.sourceRevision.source.name)
            LabeledContent("UUID", value: sample.uuid.uuidString)
        }
        .font(.footnote)
    }

    private func timeString(from: Date, to: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = DateFormatter.dateFormat(fromTemplate: "d MMM y, HH:mm:ss", options: 0, locale: Locale.current)!
        return formatter.string(from: from, to: to)
    }
}

private struct EmtpyEffortSampleView: View {
    var body: some View {
        Text("EMPTY")
            .captionEmphasis(.secondary)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    EditWorkoutEffortView(healthStore: HKHealthStore(), workout: .sample)
}
