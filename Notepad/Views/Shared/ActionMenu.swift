//
//  ActionMenu.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI

struct ActionMenuItem: SearchableMenuItem {
    private let uuid = UUID()
    let title: String
    let icon: String?
    let destructive: Bool
    let shortcut: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, destructive: Bool = false, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.destructive = destructive
        self.shortcut = shortcut
        self.action = action
    }

    // Identifiable conformance
    var id: AnyHashable { AnyHashable(uuid) }

    // SearchableMenuItem conformance
    var displayTitle: String { title }
    var subtitle: String? { shortcut }
    var isDestructive: Bool { destructive }
}

struct ActionMenu: View {
    @Binding var isPresented: Bool
    let items: [ActionMenuItem]

    var body: some View {
        SearchableMenu(
            isPresented: $isPresented,
            items: items,
            searchPlaceholder: "Search actions...",
            closeShortcut: "k",
            filterPredicate: { item, searchText in
                item.title.localizedCaseInsensitiveContains(searchText)
            },
            onSelect: { item in
                item.action()
            },
            onDelete: nil,
            rowContent: { item, isSelected, _ in
                ActionMenuRow(
                    item: item,
                    isSelected: isSelected,
                    isFirst: false,
                    isLast: false
                )
            }
        )
    }
}

struct ActionMenuRow: View {
    let item: ActionMenuItem
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(item.destructive ? .red : .primary)
            }

            Text(item.title)
                .foregroundColor(item.destructive ? .red : .primary)

            Spacer()

            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
    }
}
