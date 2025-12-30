//
//  MacNotesKeyboardShortcuts.swift
//  Notepad
//
//  Hidden keyboard shortcuts for MacNotesView.
//

#if os(macOS)
import SwiftUI

struct MacNotesKeyboardShortcuts: ViewModifier {
    let showingActionMenu: Bool
    let showingNotePicker: Bool
    let onDuplicate: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if !showingActionMenu && !showingNotePicker {
                        // Note actions
                        Button("") { onDuplicate() }
                            .keyboardShortcut("d", modifiers: .command)
                            .hidden()
                        Button("") { onCopy() }
                            .keyboardShortcut("c", modifiers: [.command, .shift])
                            .hidden()
                        Button("") { onExport() }
                            .keyboardShortcut("e", modifiers: .command)
                            .hidden()
                        Button("") { onDelete() }
                            .keyboardShortcut("d", modifiers: [.command, .shift])
                            .hidden()
                    }
                }
            )
    }
}

extension View {
    func macNotesKeyboardShortcuts(
        showingActionMenu: Bool,
        showingNotePicker: Bool,
        onDuplicate: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(MacNotesKeyboardShortcuts(
            showingActionMenu: showingActionMenu,
            showingNotePicker: showingNotePicker,
            onDuplicate: onDuplicate,
            onCopy: onCopy,
            onExport: onExport,
            onDelete: onDelete
        ))
    }
}
#endif
