//
//  NoteDetailView.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI
import ConvexMobile
import Combine

#if os(iOS)
struct NoteDetailView: View {
    let noteId: String

    @EnvironmentObject var convexService: ConvexService
    @State private var autoSaveService: AutoSaveService?
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var showingFind = false
    @State private var showingDeleteConfirmation = false
    @State private var lastEditTimestamp: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NoteEditor(content: $content, focusOnAppear: true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(item: content) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Menu {
                        Button {
                            showingFind = true
                        } label: {
                            Label("Find in Note", systemImage: "magnifyingglass")
                        }

                        Button {
                            copyNote()
                        } label: {
                            Label("Copy Note", systemImage: "doc.on.clipboard")
                        }

                        ShareLink(item: content) {
                            Label("Share Note", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .findNavigator(isPresented: $showingFind)
            .findDisabled(false)
            .task {
                await loadNote()
            }
            .onChange(of: content) { _, newValue in
                if !isLoading {
                    lastEditTimestamp = Date()
                    autoSaveService?.scheduleSave(noteId: noteId, content: newValue)
                }
            }
            .onAppear {
                // Initialize services
                if autoSaveService == nil {
                    autoSaveService = AutoSaveService(convexService: convexService)
                }
            }
            .onDisappear {
                // Save immediately when navigating away to catch any pending changes
                if !isLoading {
                    autoSaveService?.saveImmediately(noteId: noteId, content: content)
                }
            }
            .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteNote()
                }
            } message: {
                Text("This action cannot be undone.")
            }
    }

    private func loadNote() async {
        for await note: Note? in convexService.shared
            .subscribe(to: "notes:get", with: ["id": noteId])
            .replaceError(with: nil)
            .values
        {
            if let note = note {
                // Check if user has typed recently (within 2.5 seconds)
                let isActivelyTyping = lastEditTimestamp.map { Date().timeIntervalSince($0) < 2.5 } ?? false

                // Update content if it has changed and user isn't actively typing
                if note.content != self.content && (isLoading || !isActivelyTyping) {
                    // Set loading flag to prevent save debouncer from triggering
                    isLoading = true
                    self.content = note.content
                    // Small delay to ensure the content update propagates before re-enabling saves
                    try? await Task.sleep(for: .milliseconds(100))
                }
                // Always set isLoading to false after first load, even if content matches
                // This is important for new empty notes
                isLoading = false
            } else {
                // Note was deleted on another device
                Logger.sync.info("Note \(noteId) was deleted on another device")
                await MainActor.run {
                    dismiss()
                }
                break
            }
        }
    }

    private func copyNote() {
        UIPasteboard.general.string = content
    }

    private func deleteNote() {
        Task {
            do {
                try await convexService.deleteNote(id: noteId)
                // Dismiss the view after successful deletion
                await MainActor.run {
                    dismiss()
                }
            } catch {
                Logger.sync.error("Error deleting note: \(error.localizedDescription)")
            }
        }
    }

}
#endif
