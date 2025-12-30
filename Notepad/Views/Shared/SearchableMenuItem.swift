//
//  SearchableMenuItem.swift
//  Notepad
//
//  Protocol for items that can be displayed in a searchable menu.
//

import SwiftUI

protocol SearchableMenuItem: Identifiable where ID == AnyHashable {
    /// Primary display text
    var displayTitle: String { get }

    /// Optional subtitle or secondary text
    var subtitle: String? { get }

    /// Optional icon name (SF Symbol)
    var icon: String? { get }

    /// Whether this item should be styled as destructive
    var isDestructive: Bool { get }
}

// Default implementations
extension SearchableMenuItem {
    var subtitle: String? { nil }
    var icon: String? { nil }
    var isDestructive: Bool { false }
}
