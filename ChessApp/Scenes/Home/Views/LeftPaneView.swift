//
//  LeftPaneView.swift
//  ChessApp
//

import SwiftUI

struct LeftPaneView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onBeginTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Left Pane")
                .font(.title)
                .foregroundColor(.white)

            Button("Begin") {
                onBeginTapped()
            }
            .buttonStyle(.borderedProminent)

            if isLoading {
                ProgressView("Processing...")
                    .foregroundColor(.white)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(
            Color.black.opacity(0.2)
        )
    }
}

#Preview {
    LeftPaneView(
        isLoading: false,
        errorMessage: nil,
        onBeginTapped: {}
    )
}
