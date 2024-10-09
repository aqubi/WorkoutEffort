//
//  WorkoutDetailView.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/02.
//

import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    let healthStore: HKHealthStore
    @State var workout: WorkoutEffortModel
    @State private var showEditEffort: Bool = false

    var body: some View {
        List {
            Section {
                LabeledContent("Duration", value: workout.durationString)
                LabeledContent("Date", value: workout.dateString)
                LabeledContent("Source", value: workout.source.name)
            }

            Section("Workout Effort") {
                if let effortSample = workout.effortSample, let value = workout.effortValue {
                    LabeledContent(effortSample.quantityType.displayName, value: value.formatted())
                }
                Button {
                    showEditEffort = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            Section {
                if let str = workout.valueString(.activeEnergyBurned) {
                    LabeledContent("Active Energy Burned", value: str)
                }
                if let str = workout.valueString(.basalEnergyBurned) {
                    LabeledContent("Basal Energy Burned", value: str)
                }
                if let str = workout.valueString(.distanceWalkingRunning) {
                    LabeledContent("Distance", value: str)
                }
                if let str = workout.valueString(.heartRate) {
                    LabeledContent("Heart Rate", value: str)
                }
            }

//            Section {
//                Button {
//                    showEditEffort = true
//                } label: {
//                    Label("Edit Workout Effort", systemImage: "pencil")
//                }
//            }
        }
        .navigationTitle("Workout Detail")
        .sheet(isPresented: $showEditEffort) {
            EditWorkoutEffortView(healthStore: healthStore, workout: workout)
        }
    }
}


#Preview {
    WorkoutDetailView(healthStore: HKHealthStore(), workout: .sample)
}
