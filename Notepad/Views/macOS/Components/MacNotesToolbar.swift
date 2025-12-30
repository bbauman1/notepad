//
//  MacNotesToolbar.swift
//  Notepad
//
//  Toolbar content for MacNotesView.
//

#if os(macOS)
import SwiftUI

struct MacNotesToolbar: ToolbarContent {
    let currentNoteTitle: String
    @Binding var showingActionMenu: Bool
    @Binding var showingNotePicker: Bool
    let onCreateNote: () -> Void

    var body: some ToolbarContent {
        ToolbarSpacer()

        ToolbarItem(placement: .principal) {
            Text(currentNoteTitle)
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer()

        ToolbarItemGroup {
            Button {
                showingActionMenu.toggle()
            } label: {
                Image(systemName: "command")
            }
            .keyboardShortcut("k", modifiers: .command)
            .help("Actions (⌘K)")

            Button {
                showingNotePicker.toggle()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .keyboardShortcut("p", modifiers: .command)
            .help("Browse Notes (⌘P)")

            Button {
                onCreateNote()
            } label: {
                Image(systemName: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("New Note (⌘N)")
        }
    }
}
#endif
