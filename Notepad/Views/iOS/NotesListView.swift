//
//  NotesListView.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI
import ConvexMobile

#if os(iOS)
struct NotesListView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var convexService: ConvexService
    @State private var notes: [Note] = []
    @State private var navigationPath = NavigationPath()
    @State private var isCreatingNote = false
    @State private var searchText = ""
    @State private var noteToDelete: IndexSet?
    @State private var showingDeleteConfirmation = false
    @State private var subscriptionUpdateCount = 0
    @State private var filteredNotes: [Note] = []

    private var mainContent: some View {
        Group {
            if filteredNotes.isEmpty && !searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different search term")
                }
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(value: note._id) {
                            NoteRowView(note: note)
                        }
                    }
                    .onDelete { offsets in
                        noteToDelete = offsets
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "gearshape")
            }
        }
        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                createNewNote()
            } label: {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .searchable(text: $searchText, prompt: "Search notes")
                .toolbar { toolbarContent }
                .navigationDestination(for: String.self) { noteId in
                    NoteDetailView(noteId: noteId)
                }
                .navigationTitle("Notes")
                .toolbarTitleDisplayMode(.inlineLarge)
            .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let offsets = noteToDelete {
                        deleteNotes(at: offsets)
                        noteToDelete = nil
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .task(id: convexService.authVersion) {
                // Reset update counter when subscription restarts
                subscriptionUpdateCount = 0
                await subscribeToNotes()
            }
            .onAppear {
                updateFilteredNotes(notes: notes, searchText: searchText)
            }
            .onChange(of: notes) { _, newNotes in
                updateFilteredNotes(notes: newNotes, searchText: searchText)
            }
            .onChange(of: searchText) { _, newSearchText in
                updateFilteredNotes(notes: notes, searchText: newSearchText)
            }
        }
    }

    private func subscribeToNotes() async {
        for await notesList: [Note] in convexService.shared
            .subscribe(to: "notes:list")
            .replaceError(with: [])
            .values
        {
            let previousCount = self.notes.count
            self.notes = notesList

            // Track subscription updates
            subscriptionUpdateCount += 1

            // If we just created a note and the list grew, navigate to the first note (newest)
            if isCreatingNote && notesList.count > previousCount, let firstNote = notesList.first {
                isCreatingNote = false
                navigationPath.append(firstNote._id)
            }
            // Auto-create first note if no notes exist
            // Only after receiving at least 2 updates to ensure data has stabilized
            else if subscriptionUpdateCount >= 2 && notesList.isEmpty && !isCreatingNote {
                createNewNote()
            }
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

    private func deleteNotes(at offsets: IndexSet) {
        Task {
            do {
                for index in offsets {
                    let noteId = filteredNotes[index]._id
                    try await convexService.deleteNote(id: noteId)
                }
            } catch {
                Logger.sync.error("Error deleting note: \(error.localizedDescription)")
            }
        }
    }

    private func updateFilteredNotes(notes: [Note], searchText: String) {
        let filtered = if searchText.isEmpty {
            notes
        } else {
            notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Sort by most recently updated
        filteredNotes = filtered.sorted { $0.updatedTime > $1.updatedTime }
    }
}
#endif
