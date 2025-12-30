//
//  AutoSaveService.swift
//  Notepad
//
//  Manages auto-save functionality with debouncing to prevent excessive saves.
//

import Foundation
import Combine

@MainActor
class AutoSaveService: ObservableObject {
    private let convexService: ConvexService
    private var saveDebouncer = PassthroughSubject<(noteId: String, content: String), Never>()
    private var cancellables = Set<AnyCancellable>()

    init(convexService: ConvexService) {
        self.convexService = convexService
        setupDebouncer()
    }

    private func setupDebouncer() {
        saveDebouncer
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] update in
                self?.performSave(noteId: update.noteId, content: update.content)
            }
            .store(in: &cancellables)
    }

    /// Schedule a save operation (will be debounced)
    func scheduleSave(noteId: String, content: String) {
        saveDebouncer.send((noteId: noteId, content: content))
    }

    /// Immediately save without debouncing
    func saveImmediately(noteId: String, content: String) {
        performSave(noteId: noteId, content: content)
    }

    private func performSave(noteId: String, content: String) {
        Task {
            do {
                try await convexService.shared.mutation(
                    "notes:update",
                    with: ["id": noteId, "content": content]
                )
            } catch {
                Logger.sync.error("Error saving note: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        cancellables.removeAll()
    }
}
