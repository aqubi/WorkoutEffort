//
//  ContentView.swift
//  WatchEffort Watch App
//
//  Created by Hideko Ogawa on 2024/09/30.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State var store = DataStore.shared
    @State private var isSaveWorkout: Bool = false

    enum ViewType {
        case workouts
    }
    var body: some View {
        NavigationStack(path: $store.path) {
            List {
                let status: WorkoutBuilder.Status = store.builder?.status ?? .notStarted

                VStack(spacing: 12) {
                    HStack {
                        TimeView(elapsedTime: store.builder?.elapsedTime ?? 0)
                        Spacer()
                        switch status {
                        case .notStarted, .finished:
                            Button { startWorkout() }
                            label: { Image(systemName: "play.fill") }
                                .buttonStyle(ActionButtonStyle())
                                .foregroundStyle(Color.accent)
                        case .loading:
                            ProgressView()
                                .frame(width: 44, height: 44)
                        case .working:
                            Button { stopWorkout() }
                            label: { Image(systemName: "stop.fill") }
                                .buttonStyle(ActionButtonStyle())
                                .foregroundStyle(Color.red)
                        }
                    }

                    if let builder = store.builder {
                        TypeToCollectionView(builder: builder)
                    }
                }
                .listRowBackground(Color.clear)

                Section ("Options"){
                    if status != .loading {
                        Toggle(isOn: $isSaveWorkout) {
                            VStack(alignment: .leading) {
                                Text("Save?")
                                Text(isSaveWorkout ? "End and Save" : "End and Discard")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption2)
                        }
                        .tint(.accentColor)
                    }

                    Button("Saved Workouts") {
                        store.path.append(ViewType.workouts)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationDestination(for: Self.ViewType.self, destination: { value in
                switch (value) {
                case .workouts:
                    WorkoutListView(healthStore: store.healthStore, path: $store.path)
                }
            })
        }
        .task {
            await setup()
        }
    }

    private func setup() async {
        do {
            try await store.requestAuthorization()
        } catch {
            print(error)
        }
    }

    private func startWorkout() {
        Task {
            do {
                try await store.startWorkout()
            } catch {
                print(error)
            }
        }
    }

    private func stopWorkout() {
        Task {
            do {
                try await store.stopWorkout(isDiscard: !isSaveWorkout)
            } catch {
                print(error)
            }
        }
    }
}

private struct TimeView: View {
    var elapsedTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "figure.walk")
                Text("WALKING")
            }
            .font(.caption2).fontWeight(.bold)

            Text(elapsedTime.timeString)
                .font(.system(size: 23))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospaced()
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height:44)
            .background { Circle().opacity(0.3) }
    }
}


private struct TypeToCollectionView: View {
    var builder: WorkoutBuilder

    var body: some View {
        VStack {
            ForEach(builder.typesToCollect, id: \.self) { type in
                LabeledContent {
                    Text(builder.typeValues[type] ?? "--")
                } label: {
                    Text(type.displayName)
                        .font(.system(size: 11))
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
