//
//  SearchableMenu.swift
//  Notepad
//
//  Reusable searchable menu with keyboard navigation.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SearchableMenu<Item: SearchableMenuItem, RowContent: View>: View {
    @Binding var isPresented: Bool
    let items: [Item]
    let searchPlaceholder: String
    let closeShortcut: String // "k" for Cmd+K or "p" for Cmd+P
    let filterPredicate: (Item, String) -> Bool
    let onSelect: (Item) -> Void
    let onDelete: ((Item) -> Void)? // Optional delete callback
    @ViewBuilder let rowContent: (Item, Bool, Bool) -> RowContent // Added isCommandHeld parameter

    @State private var selectedIndex: Int = 0
    @State private var searchText: String = ""
    @State private var isCommandHeld: Bool = false
    @State private var eventMonitor: Any?
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: Item?
    @FocusState private var isMenuFocused: Bool
    @FocusState private var isSearchFocused: Bool

    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { filterPredicate($0, searchText) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                GlassMenuOverlay(isPresented: $isPresented)

                GlassMenuContainer(width: 500) {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField(searchPlaceholder, text: $searchText)
                                .textFieldStyle(.plain)
                                .focused($isSearchFocused)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .onChange(of: searchText) { oldValue, newValue in
                            selectedIndex = 0
                        }

                        Divider()
                            .background(.white.opacity(0.1))

                        // Items list with auto-scroll
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                        rowContent(item, index == selectedIndex, isCommandHeld)
                                            .id(item.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                executeAction(at: index)
                                            }

                                        if index < filteredItems.count - 1 {
                                            Divider()
                                                .background(.white.opacity(0.1))
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: min(400, max(200, geometry.size.height - 120)))
                            .onChange(of: selectedIndex) { oldValue, newValue in
                                if selectedIndex < filteredItems.count {
                                    proxy.scrollTo(filteredItems[selectedIndex].id, anchor: nil)
                                }
                            }
                        }
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($isMenuFocused)
                .onKeyPress(.upArrow) {
                    selectedIndex = max(0, selectedIndex - 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
                    return .handled
                }
                .onKeyPress(.return) {
                    // If Command is held and delete is available, show confirmation
                    if isCommandHeld, onDelete != nil, selectedIndex < filteredItems.count {
                        itemToDelete = filteredItems[selectedIndex]
                        showingDeleteConfirmation = true
                        return .handled
                    } else {
                        // Normal behavior: navigate to note
                        executeAction(at: selectedIndex)
                        return .handled
                    }
                }
                .onKeyPress(.escape) {
                    isPresented = false
                    return .handled
                }
                .onKeyPress { press in
                    // Handle close shortcut (Cmd+K or Cmd+P)
                    if press.characters == closeShortcut && press.modifiers.contains(.command) {
                        isPresented = false
                        return .handled
                    }
                    return .ignored
                }
            }
            .onChange(of: isPresented) { oldValue, newValue in
                if newValue {
                    // Longer delay to ensure view is fully rendered, especially when switching from another menu
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isSearchFocused = true
                        isMenuFocused = true
                    }
                    // Start monitoring modifier flags
                    startMonitoringModifiers()
                } else {
                    // Stop monitoring when menu closes
                    stopMonitoringModifiers()
                }
            }
            .onAppear {
                isSearchFocused = true
                isMenuFocused = true
                startMonitoringModifiers()
            }
            .onDisappear {
                stopMonitoringModifiers()
            }
            .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                    .keyboardShortcut(.cancelAction)
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete, let onDelete = onDelete {
                        onDelete(item)
                    }
                    itemToDelete = nil
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func executeAction(at index: Int) {
        guard index >= 0 && index < filteredItems.count else { return }
        let item = filteredItems[index]
        isPresented = false

        // Delay action slightly to allow menu to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onSelect(item)
        }
    }

    #if os(macOS)
    private func startMonitoringModifiers() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandHeld = event.modifierFlags.contains(.command)
            return event
        }
    }

    private func stopMonitoringModifiers() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isCommandHeld = false
    }
    #else
    private func startMonitoringModifiers() {}
    private func stopMonitoringModifiers() {}
    #endif
}
