//
//  NotePickerView.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

#if os(macOS)
import SwiftUI

// Wrapper to make Note conform to SearchableMenuItem
struct NoteMenuItem: SearchableMenuItem {
    let note: Note
    let isCurrentNote: Bool

    var id: AnyHashable { AnyHashable(note._id) }
    var displayTitle: String { note.title }
    var subtitle: String? { relativeTimeString(from: note.updatedTime) }
    var icon: String? { isCurrentNote ? "checkmark" : nil }

    private func relativeTimeString(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date, to: now)

        if calendar.isDateInToday(date) {
            if let minutes = components.minute, minutes < 1 {
                return "Updated <1m ago"
            } else if let minutes = components.minute, minutes < 60 {
                return "Updated \(minutes)m ago"
            } else if let hours = components.hour {
                return "Updated \(hours)h ago"
            }
        }

        if calendar.isDateInYesterday(date) {
            return "Updated yesterday"
        }

        if let days = components.day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Updated on \(formatter.string(from: date))"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Updated \(formatter.string(from: date))"
    }
}

struct NotePickerView: View {
    @Binding var isPresented: Bool
    let notes: [Note]
    let currentNoteId: String?
    let onSelectNote: (String) -> Void
    let onDeleteNote: (String) -> Void

    var menuItems: [NoteMenuItem] {
        // Sort by most recently updated
        let sortedNotes = notes.sorted { $0.updatedTime > $1.updatedTime }
        return sortedNotes.map { note in
            NoteMenuItem(note: note, isCurrentNote: note._id == currentNoteId)
        }
    }

    var body: some View {
        SearchableMenu(
            isPresented: $isPresented,
            items: menuItems,
            searchPlaceholder: "Search notes...",
            closeShortcut: "p",
            filterPredicate: { item, searchText in
                item.note.title.localizedCaseInsensitiveContains(searchText) ||
                item.note.content.localizedCaseInsensitiveContains(searchText)
            },
            onSelect: { item in
                onSelectNote(item.note._id)
            },
            onDelete: { item in
                onDeleteNote(item.note._id)
            },
            rowContent: { item, isSelected, isCommandHeld in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.body)
                            .lineLimit(1)

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if isSelected && isCommandHeld {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    } else if item.isCurrentNote {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            }
        )
    }
}
#endif
