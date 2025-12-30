//
//  MacNotesView.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

#if os(macOS)
import SwiftUI
import ConvexMobile
import Combine

struct MacNotesView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var convexService: ConvexService

    @State private var autoSaveService: AutoSaveService?
    @State private var currentNoteId: String?
    @State private var content: String = ""
    @State private var showingNotePicker = false
    @State private var showingActionMenu = false
    @State private var notes: [Note] = []
    @State private var isLoadingNote = false
    @State private var loadNoteTask: Task<Void, Never>?
    @State private var isCreatingNote = false
    @FocusState private var isEditorFocused: Bool
    @State private var showingDeleteConfirmation = false
    @State private var hasLoadedCurrentNote = false
    @State private var lastEditTimestamp: Date?
    @State private var subscriptionUpdateCount = 0
    private var currentNoteTitle: String {
        guard let noteId = currentNoteId,
              let note = notes.first(where: { $0._id == noteId }) else {
            return ""
        }
        let title = note.title == "Untitled Note" ? "" : note.title
        return title.count > 20 ? String(title.prefix(20)) + "…" : title
    }

    private var actionMenuItems: [ActionMenuItem] {
        var items: [ActionMenuItem] = []

        // New Note (Cmd+N)
        items.append(ActionMenuItem(
            title: "New Note",
            icon: "plus",
            shortcut: "⌘N",
            action: createNewNote
        ))

        // Browse Notes (Cmd+P)
        items.append(ActionMenuItem(
            title: "Browse Notes",
            icon: "doc.text.magnifyingglass",
            shortcut: "⌘P",
            action: { showingNotePicker = true }
        ))

        // Actions that require a current note
        if currentNoteId != nil {
            items.append(ActionMenuItem(
                title: "Duplicate Note",
                icon: "doc.on.doc",
                shortcut: "⌘D",
                action: duplicateCurrentNote
            ))

            items.append(ActionMenuItem(
                title: "Copy Note",
                icon: "doc.on.clipboard",
                shortcut: "⌘⇧C",
                action: copyCurrentNote
            ))

            items.append(ActionMenuItem(
                title: "Export Note",
                icon: "square.and.arrow.up",
                shortcut: "⌘E",
                action: exportCurrentNote
            ))

            items.append(ActionMenuItem(
                title: "Delete Note",
                icon: "trash",
                destructive: true,
                shortcut: "⌘⇧D",
                action: deleteCurrentNote
            ))
        }

        return items
    }

    var body: some View {
        NoteEditor(content: $content, placeholder: "Start typing your note...", focusOnAppear: content.isEmpty, externalFocus: $isEditorFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: content) { oldValue, newValue in
                if !isLoadingNote, let noteId = currentNoteId {
                    lastEditTimestamp = Date()
                    autoSaveService?.scheduleSave(noteId: noteId, content: newValue)
                }
            }
        .containerBackground(.thinMaterial, for: .window)
        .toolbar {
            MacNotesToolbar(
                currentNoteTitle: currentNoteTitle,
                showingActionMenu: $showingActionMenu,
                showingNotePicker: $showingNotePicker,
                onCreateNote: createNewNote
            )
        }
        .navigationTitle(currentNoteTitle)
        .macNotesMenuHandler(
            showingNotePicker: $showingNotePicker,
            showingActionMenu: $showingActionMenu,
            refocusEditor: { isEditorFocused = true }
        )
        .macNotesKeyboardShortcuts(
            showingActionMenu: showingActionMenu,
            showingNotePicker: showingNotePicker,
            onDuplicate: duplicateCurrentNote,
            onCopy: copyCurrentNote,
            onExport: exportCurrentNote,
            onDelete: deleteCurrentNote
        )
        .overlay {
            if showingNotePicker {
                NotePickerView(
                    isPresented: $showingNotePicker,
                    notes: notes,
                    currentNoteId: currentNoteId,
                    onSelectNote: selectNote,
                    onDeleteNote: deleteNoteById
                )
            }
        }
        .overlay {
            if showingActionMenu {
                ActionMenu(isPresented: $showingActionMenu, items: actionMenuItems)
            }
        }
        .task(id: convexService.authVersion) {
            Logger.sync.info("Starting subscription (authVersion: \(convexService.authVersion))")
            // Reset update counter when subscription restarts
            subscriptionUpdateCount = 0
            await subscribeToNotes()
        }
        .onChange(of: currentNoteId) { oldNoteId, newNoteId in
            // Cancel previous load task
            loadNoteTask?.cancel()

            // Reset the loaded flag and edit timestamp for the new note
            hasLoadedCurrentNote = false
            lastEditTimestamp = nil

            if let noteId = newNoteId {
                loadNoteTask = Task {
                    await loadNote(id: noteId)
                }
            }
        }
        .onAppear {
            // Initialize services
            if autoSaveService == nil {
                autoSaveService = AutoSaveService(convexService: convexService)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Focus the editor when window becomes key (e.g., from Cmd+Shift+W)
            // Only if we have a note loaded and menus aren't showing
            if currentNoteId != nil && !showingActionMenu && !showingNotePicker {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SignOutRequested"))) { _ in
            signOut()
        }
        .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
                .keyboardShortcut(.cancelAction)
            Button("Delete", role: .destructive) {
                performDelete()
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func subscribeToNotes() async {
        for await notesList: [Note] in convexService.shared
            .subscribe(to: "notes:list")
            .replaceError(with: [])
            .values
        {
            let previousCount = self.notes.count
            // Sort notes by most recently updated (descending)
            self.notes = notesList.sorted { $0.updatedTime > $1.updatedTime }

            // Track subscription updates
            subscriptionUpdateCount += 1

            // If we just created a note and the list grew, switch to the first note (newest)
            if isCreatingNote && self.notes.count > previousCount, let firstNote = self.notes.first {
                isCreatingNote = false
                currentNoteId = firstNote._id
                // Focus the editor after a short delay to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = true
                }
            }
            // Auto-select first note if none selected
            else if currentNoteId == nil, let firstNote = self.notes.first {
                currentNoteId = firstNote._id
            }
            // Auto-create first note if no notes exist
            // Only after receiving at least 2 updates to ensure data has stabilized
            else if subscriptionUpdateCount >= 2 && self.notes.isEmpty && !isCreatingNote {
                createNewNote()
            }
        }
    }

    private func loadNote(id: String) async {
        Logger.sync.info("Starting loadNote for id: \(id)")
        for await note: Note? in convexService.shared
            .subscribe(to: "notes:get", with: ["id": id])
            .replaceError(with: nil)
            .values
        {
            // Only update if we're still supposed to be viewing this note,
            // the content has actually changed, and either:
            // - This is the initial load for this note, OR
            // - The user hasn't typed recently (within 2.5 seconds)
            let isActivelyTyping = lastEditTimestamp.map { Date().timeIntervalSince($0) < 2.5 } ?? false
            let shouldUpdate = note != nil &&
                              currentNoteId == id &&
                              note!.content != self.content &&
                              (!hasLoadedCurrentNote || !isActivelyTyping)

            if shouldUpdate {
                Logger.sync.info("Loading note content: \(note!.content.debugDescription)")
                Logger.sync.info("Current content: \(self.content.debugDescription)")
                // Set loading flag to prevent save debouncer from triggering
                isLoadingNote = true
                self.content = note!.content
                hasLoadedCurrentNote = true
                Logger.sync.info("Content updated, waiting 100ms")
                // Small delay to ensure the content update propagates before re-enabling saves
                try? await Task.sleep(for: .milliseconds(100))
                isLoadingNote = false
                Logger.sync.info("Loading complete")
            } else if note != nil {
                Logger.sync.info("Skipping update - content same, note ID mismatch, or editor focused")
            } else {
                // Note was deleted on another device
                Logger.sync.info("Note \(id) was deleted on another device")
                await MainActor.run {
                    handleDeletedNote(deletedNoteId: id)
                }
                break
            }

            // Check if task was cancelled (user switched notes)
            if Task.isCancelled {
                Logger.sync.info("Load task cancelled")
                break
            }
        }
    }

    private func handleDeletedNote(deletedNoteId: String) {
        // Only handle if this is still the current note
        guard currentNoteId == deletedNoteId else { return }

        // Find another note to switch to
        let otherNotes = notes.filter { $0._id != deletedNoteId }

        if let nextNote = otherNotes.first {
            // Switch to the first available note
            Logger.sync.info("Switching to note: \(nextNote._id)")
            currentNoteId = nextNote._id
        } else {
            // No other notes exist, create a new one
            Logger.sync.info("No notes available, creating new note")
            createNewNote()
        }
    }

    private func selectNote(_ noteId: String) {
        currentNoteId = noteId
        // onChange will handle loading the note

        // Focus the editor after a short delay to ensure view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditorFocused = true
        }
    }

    private func createNewNote() {
        Task {
            do {
                isCreatingNote = true
                try await convexService.createNote()
                // Navigation will happen automatically when the subscription updates
            } catch {
                Logger.sync.error("Error creating note: \(error.localizedDescription)")
                isCreatingNote = false
            }
        }
    }


    private func deleteCurrentNote() {
        showingDeleteConfirmation = true
    }

    private func performDelete() {
        guard let noteId = currentNoteId else { return }

        Task {
            do {
                // Find the index of the current note
                if let currentIndex = notes.firstIndex(where: { $0._id == noteId }) {
                    // Select another note before deleting
                    let nextNote: Note? = if currentIndex < notes.count - 1 {
                        notes[currentIndex + 1]
                    } else if currentIndex > 0 {
                        notes[currentIndex - 1]
                    } else {
                        nil
                    }

                    // Delete the note
                    try await convexService.deleteNote(id: noteId)

                    // Update selection
                    await MainActor.run {
                        currentNoteId = nextNote?._id
                    }
                }
            } catch {
                Logger.sync.error("Error deleting note: \(error.localizedDescription)")
            }
        }
    }

    private func deleteNoteById(_ noteId: String) {
        Task {
            do {
                // Find the index of the note to delete
                if let currentIndex = notes.firstIndex(where: { $0._id == noteId }) {
                    // If deleting the current note, select another note first
                    if noteId == currentNoteId {
                        let nextNote: Note? = if currentIndex < notes.count - 1 {
                            notes[currentIndex + 1]
                        } else if currentIndex > 0 {
                            notes[currentIndex - 1]
                        } else {
                            nil
                        }

                        await MainActor.run {
                            currentNoteId = nextNote?._id
                        }
                    }

                    // Delete the note
                    try await convexService.deleteNote(id: noteId)
                }
            } catch {
                Logger.sync.error("Error deleting note: \(error.localizedDescription)")
            }
        }
    }

    private func duplicateCurrentNote() {
        Task {
            do {
                // Create a new note with the current content
                try await convexService.duplicateNote(content: content)

                // The subscription will update the notes list
                // The new note will appear at the top (sorted by updatedTime)
                // and will be automatically selected
            } catch {
                Logger.sync.error("Error duplicating note: \(error.localizedDescription)")
            }
        }
    }

    private func copyCurrentNote() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func signOut() {
        Task {
            await authService.signOut()
        }
    }

    private func exportCurrentNote() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Note.txt"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    Logger.ui.error("Error exporting note: \(error.localizedDescription)")
                }
            }
        }
    }

}

#endif
