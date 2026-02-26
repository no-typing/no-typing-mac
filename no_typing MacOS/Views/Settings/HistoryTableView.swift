import SwiftUI

struct HistoryTableView: View {
    @ObservedObject var historyManager = TranscriptionHistoryManager.shared
    
    // Filtering & Search
    @State private var searchText = ""
    @State private var selectedDateRange: DateRangeFilter = .today
    
    // Selection for Bulk Delete
    @State private var selectedItems = Set<TranscriptionHistoryItem.ID>()
    @State private var showingDeleteConfirmation = false
    
    // Pagination
    @State private var currentPage = 0
    private let itemsPerPage = 50
    
    enum DateRangeFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Computed Properties
    
    private var filteredItems: [TranscriptionHistoryItem] {
        var items = historyManager.transcriptionHistory
        
        // Apply Date Filter
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedDateRange {
        case .today:
            items = items.filter { calendar.isDateInToday($0.timestamp) }
        case .last7Days:
            if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                items = items.filter { $0.timestamp >= sevenDaysAgo }
            }
        case .last30Days:
            if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) {
                items = items.filter { $0.timestamp >= thirtyDaysAgo }
            }
        case .allTime:
            break
        }
        
        // Apply Search Filter
        if !searchText.isEmpty {
            items = items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        
        return items
    }
    
    private var paginatedItems: [TranscriptionHistoryItem] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredItems.count)
        
        guard startIndex < endIndex else { return [] }
        return Array(filteredItems[startIndex..<endIndex])
    }
    
    private var totalPages: Int {
        return max(1, Int(ceil(Double(filteredItems.count) / Double(itemsPerPage))))
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Toolbar (Search, Filter, Delete)
            HStack(spacing: 16) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ThemeColors.secondaryText)
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .onChange(of: searchText) {
                            currentPage = 0 // Reset pagination on search
                            selectedItems.removeAll()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ThemeColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // Date Filter String
                Picker("", selection: $selectedDateRange) {
                    ForEach(DateRangeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: selectedDateRange) {
                    currentPage = 0
                    selectedItems.removeAll()
                }
                
                Spacer()
                
                // Bulk Actions
                if !selectedItems.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: copySelected) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy (\(selectedItems.count))")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Delete (\(selectedItems.count))")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 12)
            // Native SwiftUI Table-like list using Selection
            if paginatedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(ThemeColors.secondaryText.opacity(0.5))
                    Text(filteredItems.isEmpty && !historyManager.transcriptionHistory.isEmpty ? "No matches found" : "No transcriptions yet")
                        .font(.system(size: 14))
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                List(selection: $selectedItems) {
                    ForEach(paginatedItems) { item in
                        HistoryTableRow(item: item)
                            .tag(item.id)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // Removes default macOS list background
                .background(Color.clear)
            }
            
            // Pagination Footer
            if totalPages > 1 {
                Divider().padding(.top, 8)
                
                HStack {
                    Text("Showing \(filteredItems.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { currentPage = max(0, currentPage - 1) }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentPage == 0)
                        
                        Text("Page \(currentPage + 1) of \(totalPages)")
                            .font(.system(size: 12))
                        
                        Button(action: { currentPage = min(totalPages - 1, currentPage + 1) }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 25/255, green: 30/255, blue: 40/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .alert("Delete Selected Items", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteSelected)
        } message: {
            Text("Are you sure you want to delete \(selectedItems.count) transcription\(selectedItems.count == 1 ? "" : "s")? This action cannot be undone.")
        }
    }
    
    private func deleteSelected() {
        withAnimation {
            historyManager.deleteTranscriptions(withIds: selectedItems)
            selectedItems.removeAll()
            
            // Adjust pagination if we deleted the last items on a page
            if paginatedItems.isEmpty && currentPage > 0 {
                currentPage -= 1
            }
        }
    }
    
    private func copySelected() {
        let itemsToCopy = historyManager.transcriptionHistory.filter { selectedItems.contains($0.id) }
        let textToCopy = itemsToCopy.map { $0.text }.joined(separator: "\n\n")
        
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        #endif
        
        withAnimation {
            selectedItems.removeAll()
        }
    }
}

// MARK: - Row Component

struct HistoryTableRow: View {
    let item: TranscriptionHistoryItem
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Text Column (expanding vertically if needed)
            Text(item.text)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            
            // Date Column
            Text(item.formattedFullDate)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.secondaryText)
                .frame(width: 170, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
