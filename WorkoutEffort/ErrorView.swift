//
//  ErrorView.swift
//  WorkoutEffort
//
//  Created by Hideko Ogawa on 2024/10/07.
//
import SwiftUI

struct ErrorView: View {
    @Binding var error: Error?

    var body: some View {
        if let error {
            VStack {
                Button("", systemImage: "xmark.circle.fill") {
                    self.error = nil
                }
                .frame(maxWidth: .infinity, alignment: .trailing)


                VStack(alignment: .leading, spacing: 5) {
                    Text("ERROR").fontWeight(.bold)
                    Text(error.localizedDescription)

                    let nsError = error as NSError
                    if let str = nsError.localizedFailureReason {
                        Text(str)
                    }
                    if let str = nsError.localizedRecoverySuggestion {
                        Text(str)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Domain: \(nsError.domain)")
                        Text("Code: \(nsError.code)")
                    }
                    .font(.footnote)
                }

            }
            .padding()
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.1))
        }
    }
}
