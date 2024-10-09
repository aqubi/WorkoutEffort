//
//  WorkoutListView.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/02.
//

import SwiftUI
import HealthKit

struct WorkoutListView: View {
    let healthStore: HKHealthStore
    @Binding var path: NavigationPath

    @State private var workouts: [WorkoutEffortModel] = []
    @State private var error: Error?
    @State private var loading: Bool = false

    var body: some View {
        VStack (spacing: 0) {
            List {
                ForEach(workouts) { workout in
                    Button {
                        path.append(workout)
                    } label: {
                        HStack(spacing: 10) {
                            Text(workout.effortValue?.formatted() ?? "-")
                                .font(.title2).fontWeight(.bold)
                                .padding(10)
                                .blendMode(.destinationOut)
                                .background(typeColor(workout.effortSample?.quantityType))
                                .clipShape(Circle())
                                .compositingGroup()

                            VStack(alignment: .leading) {
                                Text(workout.durationString)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(workout.dateString)
                                    Text(workout.source.name)
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(Color.primary)
                        }
                    }
                }
            }
            .refreshable {
                reloadData()
            }

            ErrorView(error: $error)
        }
        .navigationTitle("Workouts")
        .onAppear() { reloadData() }
        .navigationDestination(for: WorkoutEffortModel.self, destination: { workout in
            WorkoutDetailView(healthStore: healthStore, workout: workout)
        })
    }

    private func reloadData() {
        Task {
            self.loading = true
            let start = Date().timeIntervalSince1970
            do {
                try await requestAuthorization()
                var results:[WorkoutEffortModel] = []
                let workouts = try await healthStore.queryWorkouts()
                for workout in workouts {
                    let model = WorkoutEffortModel(workout: workout)
                    results.append(model)
                }
                self.workouts = results

                for workout in results {
                    try await workout.reloadEffortSamples(healthStore)
                }
            } catch {
                print(error)
                self.error = error
            }
            if Date().timeIntervalSince1970 - start < 0.3 {
                try? await Task.sleep(nanoseconds: 3 * 100_000_000) //0.3 sec
            }
            self.loading = false
        }
    }

    private func requestAuthorization() async throws {
        let typeIds:[HKQuantityTypeIdentifier] = [.activeEnergyBurned, .basalEnergyBurned, .distanceWalkingRunning, .heartRate, .estimatedWorkoutEffortScore, .workoutEffortScore]
        let types = typeIds.map { HKQuantityType($0)}
        try await healthStore.requestAuthorization(Set(types))
    }

    private func typeColor(_ type: HKQuantityType?) -> Color {
        if type?.identifier == HKQuantityTypeIdentifier.workoutEffortScore.rawValue {
            return .accentColor
        } else if type?.identifier == HKQuantityTypeIdentifier.estimatedWorkoutEffortScore.rawValue  {
            return .accentColor.opacity(0.6)
        } else {
            return .secondary.opacity(0.4)
        }
    }
}

