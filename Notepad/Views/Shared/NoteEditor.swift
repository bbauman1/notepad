//
//  NoteEditor.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI

struct NoteEditor: View {
    @Binding var content: String
    var placeholder: String = "Start typing..."
    var focusOnAppear: Bool = false
    var externalFocus: FocusState<Bool>.Binding?

    @FocusState private var internalFocus: Bool

    private var isFocused: FocusState<Bool>.Binding {
        externalFocus ?? $internalFocus
    }

    var body: some View {
        #if os(iOS)
        TextEditor(text: $content)
            .font(.body)
            .scrollContentBackground(.hidden)
            .contentMargins(.all, 16, for: .scrollContent)
            .focused(isFocused)
            .overlay(alignment: .topLeading) {
                if content.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if focusOnAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused.wrappedValue = true
                    }
                }
            }
        #elseif os(macOS)
        TextEditor(text: $content)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .focused(isFocused)
            .overlay(alignment: .topLeading) {
                if content.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if focusOnAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused.wrappedValue = true
                    }
                }
            }
        #endif
    }
}
