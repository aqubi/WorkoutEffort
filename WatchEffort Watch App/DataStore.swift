//
//  DataStore.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/01.
//

import SwiftUI
import HealthKit

@Observable @MainActor class DataStore: NSObject {
    static let shared:DataStore = .init()
    let healthStore: HKHealthStore = .init()
    var path = NavigationPath()

    var builder: WorkoutBuilder?

    //MARK: - Actions

    private override init() {}
    
    func requestAuthorization() async throws {
        let source = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: WorkoutBuilder.workoutConfiguration())
        var types:Set<HKSampleType> = source.typesToCollect
        types.insert(.workoutType())
        try await healthStore.requestAuthorization(types)
    }

    func startWorkout() async throws {
        let builder = WorkoutBuilder()
        try await builder.startWorkout()
        self.builder = builder
    }

    func stopWorkout(isDiscard: Bool) async throws {
        guard let builder else { return }
        try await builder.stopWorkout(isDiscard: isDiscard)
        //self.builder = nil
    }
}


extension HKWorkoutSessionState {
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .running: return "Running"
        case .paused: return "Paused"
        case .ended: return "Ended"
        case .prepared: return "Prepared"
        case .stopped: return "Stopped"
        @unknown default: return "Unknown"
        }
    }
}
