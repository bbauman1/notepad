//
//  LoginView.swift
//  Notepad
//
//  Created by Claude on 12/28/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            // Simple top-to-bottom gradient using accent color
            LinearGradient(
                colors: [.accentColor, .accentColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // Centered message
                Spacer()

                Text("Sign up to start taking notes")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Error message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }

                // Apple Sign In button at bottom
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        authService.configureAppleSignInRequest(request)
                    },
                    onCompletion: { result in
                        Task {
                            await authService.handleAppleSignInCompletion(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .containerBackground(.thinMaterial, for: .window)
        #else
        .background(.ultraThinMaterial)
        #endif
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
