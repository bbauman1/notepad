//
//  MacNotesMenuHandler.swift
//  Notepad
//
//  Handles menu focus coordination and editor refocusing.
//

#if os(macOS)
import SwiftUI

struct MacNotesMenuHandler: ViewModifier {
    @Binding var showingNotePicker: Bool
    @Binding var showingActionMenu: Bool
    let refocusEditor: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: showingNotePicker) { oldValue, isShowing in
                if isShowing && showingActionMenu {
                    // Close action menu and wait before showing picker
                    showingActionMenu = false
                    showingNotePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingNotePicker = true
                    }
                } else if !isShowing && oldValue && !showingActionMenu {
                    // Menu was just closed and not switching to another menu - refocus editor
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !showingActionMenu && !showingNotePicker {
                            refocusEditor()
                        }
                    }
                }
            }
            .onChange(of: showingActionMenu) { oldValue, isShowing in
                if isShowing && showingNotePicker {
                    // Close note picker and wait before showing action menu
                    showingNotePicker = false
                    showingActionMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingActionMenu = true
                    }
                } else if !isShowing && oldValue && !showingNotePicker {
                    // Menu was just closed and not switching to another menu - refocus editor
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !showingActionMenu && !showingNotePicker {
                            refocusEditor()
                        }
                    }
                }
            }
    }
}

extension View {
    func macNotesMenuHandler(
        showingNotePicker: Binding<Bool>,
        showingActionMenu: Binding<Bool>,
        refocusEditor: @escaping () -> Void
    ) -> some View {
        modifier(MacNotesMenuHandler(
            showingNotePicker: showingNotePicker,
            showingActionMenu: showingActionMenu,
            refocusEditor: refocusEditor
        ))
    }
}
#endif
