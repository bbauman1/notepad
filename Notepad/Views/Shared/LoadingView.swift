//
//  LoadingView.swift
//  Notepad
//
//  Created by Claude on 12/28/25.
//

import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var authService: AuthService
    let shouldRefreshSession: Bool

    init(shouldRefreshSession: Bool = false) {
        self.shouldRefreshSession = shouldRefreshSession
    }

    var body: some View {
        VStack {
            ProgressView()
                .controlSize(.extraLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .containerBackground(.thinMaterial, for: .window)
        #else
        .background(.ultraThinMaterial)
        #endif
        .task {
            // Only refresh session if explicitly requested (initial load)
            // Don't refresh if we're just waiting for Convex authentication
            if shouldRefreshSession {
                await authService.refreshSession()
            }
        }
    }
}

#Preview {
    LoadingView()
        .environmentObject(AuthService())
}
