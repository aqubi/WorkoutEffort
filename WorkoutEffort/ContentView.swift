//
//  ContentView.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/09/30.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State var store = DataStore.shared

    var body: some View {
        NavigationStack(path: $store.path) {
            WorkoutListView(healthStore: store.healthStore, path: $store.path)
        }
    }
}

#Preview {
    ContentView()
}
