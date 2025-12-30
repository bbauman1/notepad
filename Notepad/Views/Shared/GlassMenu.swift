//
//  GlassMenu.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI

/// Shared glass menu container with consistent styling
struct GlassMenuContainer<Content: View>: View {
    let width: CGFloat
    let maxHeight: CGFloat?
    @ViewBuilder let content: Content

    init(width: CGFloat = 500, maxHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.width = width
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: width)
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 40, x: 0, y: 20)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 32)
            .padding(.top, 16)
    }
}

/// Shared background overlay for dismissing menus
struct GlassMenuOverlay: View {
    let isPresented: Binding<Bool>

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isPresented.wrappedValue = false
            }
    }
}

/// Row styling for menu items with keyboard selection
struct GlassMenuRowBackground: View {
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isSelected {
            Rectangle()
                .fill(.tint.quinary)
                .overlay {
                    Rectangle()
                        .strokeBorder(.tint.quaternary, lineWidth: 1)
                }
        }
    }
}
