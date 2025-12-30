//
//  NoteSubscriptionService.swift
//  Notepad
//
//  Manages note list subscriptions with auto-create and navigation logic.
//

import Foundation
import ConvexMobile

@MainActor
class NoteSubscriptionService: ObservableObject {
    private let convexService: ConvexService
    @Published var notes: [Note] = []
    @Published private(set) var subscriptionUpdateCount = 0

    init(convexService: ConvexService) {
        self.convexService = convexService
    }

    /// Subscribe to the notes list and handle updates
    func subscribe(
        onNewNoteCreated: ((String) -> Void)? = nil,
        onAutoCreateFirstNote: (() -> Void)? = nil
    ) async {
        var isCreatingNote = false
        subscriptionUpdateCount = 0

        for await notesList: [Note] in convexService.shared
            .subscribe(to: "notes:list")
            .replaceError(with: [])
            .values
        {
            let previousCount = self.notes.count

            // Sort by most recently updated
            self.notes = notesList.sorted { $0.updatedTime > $1.updatedTime }

            // Track subscription updates
            subscriptionUpdateCount += 1

            // If we just created a note and the list grew, notify callback
            if isCreatingNote && self.notes.count > previousCount, let firstNote = self.notes.first {
                isCreatingNote = false
                onNewNoteCreated?(firstNote._id)
            }
            // Auto-create first note if no notes exist
            // Only after receiving at least 2 updates to ensure data has stabilized
            else if subscriptionUpdateCount >= 2 && self.notes.isEmpty && !isCreatingNote {
                isCreatingNote = true
                onAutoCreateFirstNote?()
            }
        }
    }

    /// Reset subscription state (call when re-subscribing)
    func reset() {
        subscriptionUpdateCount = 0
        notes = []
    }
}
