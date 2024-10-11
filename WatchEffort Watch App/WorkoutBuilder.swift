//
//  WorkoutBuilder.swift
//  WatchEffort Watch App
//
//  Created by Hideko Ogawa on 2024/10/01.
//

import Foundation
import HealthKit

@Observable @MainActor class WorkoutBuilder: NSObject {
    private(set) var builder: HKLiveWorkoutBuilder?
    private(set) var session: HKWorkoutSession?
    private(set) var sessionState: HKWorkoutSessionState = .notStarted

    enum Status {
        case notStarted
        case loading
        case working
        case finished
    }
    private(set) var status: Status = .notStarted

    private(set) var typesToCollect: [HKQuantityType] = []
    private(set) var typeValues: [HKQuantityType:String] = [:]
    private(set) var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var endDate: Date?

    static func walkingConfiguration() -> HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor
        return config
    }

    func startWorkout() async throws {
        reset()
        let healthStore = DataStore.shared.healthStore
        self.status = .loading
        let date = Date()

        let config = Self.walkingConfiguration()
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        session.delegate = self
        self.session = session

        let builder = session.associatedWorkoutBuilder()
        builder.shouldCollectWorkoutEvents = true
        builder.delegate = self

        let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)
        builder.dataSource = dataSource
        self.typesToCollect = dataSource.typesToCollect.sorted { $0.identifier < $1.identifier }
        self.builder = builder

        session.startActivity(with: date)
        await waitToStartSession()
        self.status = .working

        try await builder.beginCollection(at: Date())

        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task {
                await MainActor.run {
                    self.updateTime()
                }
            }
        }
    }

    func stopWorkout(isDiscard: Bool) async throws {
        guard let builder, let session else { return }
        self.status = .loading
        let endDate = Date()
        self.endDate = endDate

        session.stopActivity(with: endDate)
        await waitToStopSession(endDate)
        try await builder.endCollection(at: endDate)

        if isDiscard {
            builder.discardWorkout()
        } else {
            let _ = try await builder.finishWorkout()
        }
        finished()
        try? await Task.sleep(nanoseconds: 10 * 100_000_000) //1 sec
        reloadAllStatisticsValue()
        self.status = .finished
    }

    private func finished() {
        timer?.invalidate()
        self.timer = nil
        self.endDate = nil
        self.session = nil
    }

    private func reset() {
        finished()
        self.typeValues.removeAll()
        self.elapsedTime = 0
    }

    //MARK: - Privates

    private func waitToStartSession() async {
        guard let session = builder?.workoutSession else { return }
        let start = Date()
        var waitTime:Float = 5
        while session.state == .notStarted {
            try? await Task.sleep(nanoseconds: 2 * 100_000_000) //0.2 sec
            waitTime -= 0.2
            if waitTime < 0 { break }
            #if DEBUG
            print("- Wait to start session", Date().timeIntervalSince1970 - start.timeIntervalSince1970)
            #endif
        }
    }

    private func waitToStopSession(_ date: Date) async {
        guard let session else { return }
        if session.state == .stopped || session.state == .ended { return }
        let start = Date()
        var waitTime:Float = 5
        while true {
            try? await Task.sleep(nanoseconds: 2 * 100_000_000) //0.2 sec
            if session.state == .stopped || session.state == .ended { break }
            waitTime -= 0.2
            if waitTime < 0 { break }
            #if DEBUG
            print("- Wait to stop session", Date().timeIntervalSince1970 - start.timeIntervalSince1970)
            #endif
        }
    }

    @objc private func updateTime() {
        guard let builder else { return }
        if let date = self.endDate {
            self.elapsedTime = builder.elapsedTime(at: date)
        } else {
            self.elapsedTime = builder.elapsedTime
        }
    }

    private func reloadAllStatisticsValue() {
        guard let builder else { return }
        for item in builder.allStatistics {
            let quantityType = item.key
            if let quantity = builder.currentQuantity(for: quantityType) {
                self.typeValues[quantityType] = quantityType.valueString(quantity)
            }
        }
    }
}

extension WorkoutBuilder: @preconcurrency HKWorkoutSessionDelegate {

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("didChangeTo [\(fromState.displayName)] -> [\(toState.displayName)] at \(date.formatted())")
        self.sessionState = toState
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        print("didFailWithError \(error)")
    }
}

extension WorkoutBuilder: @preconcurrency HKLiveWorkoutBuilderDelegate {

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        //print("didCollectDataOf \(collectedTypes)")
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            if let quantity = workoutBuilder.currentQuantity(for: quantityType) {
                self.typeValues[quantityType] = quantityType.valueString(quantity)
            } else {
                print("quanity is nil type=\(quantityType.displayName)")
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("workoutBuilderDidCollectEvent", workoutBuilder.workoutEvents, workoutBuilder.metadata)
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didBegin workoutActivity: HKWorkoutActivity) {
        print("workoutBuilder didBegin")
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didEnd workoutActivity: HKWorkoutActivity) {
        print("workoutBuilder didEnd")
    }
}


extension HKLiveWorkoutBuilder {
    func currentQuantity(for type: HKQuantityType) -> HKQuantity? {
        guard let statistics = self.statistics(for: type) else { return nil }
        if type.aggregationStyle == .cumulative {
            return statistics.sumQuantity()
        } else {
            return statistics.mostRecentQuantity()
        }
    }
}



