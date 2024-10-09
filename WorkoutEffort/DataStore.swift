//
//  DataStore.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/02.
//

import HealthKit
import SwiftUI

@Observable @MainActor class DataStore: NSObject {
    static let shared:DataStore = .init()
    let healthStore: HKHealthStore = .init()
    var path = NavigationPath()
}
