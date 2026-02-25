import SwiftUI
import AppKit

struct TranscriptionHistoryView: View {
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @State private var copiedItemId: UUID?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Activity Insights
                Text("Words Counted")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 2)
                
                HStack(spacing: 12) {
                    InsightCard(
                        title: "Today",
                        value: "\(historyManager.wordsToday)",
                        subtitle: historyManager.timeSavedToday,
                        iconColors: [.yellow, .orange]
                    )
                    
                    InsightCard(
                        title: "This Week",
                        value: "\(historyManager.wordsThisWeek)",
                        subtitle: historyManager.timeSavedThisWeek,
                        iconColors: [.blue, .cyan]
                    )
                    
                    InsightCard(
                        title: "All Time",
                        value: "\(historyManager.wordsAllTime)",
                        subtitle: historyManager.timeSavedAllTime,
                        iconColors: [.purple, .pink]
                    )
                }
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.bottom, 8)
                
                // New robust History Table
                HistoryTableView()
                    .frame(minHeight: 400) // Give the table room to breathe
            }
            .padding(16)
        }
        .frame(maxHeight: 700) // Maximum height before scrolling
        // removed background and cornerRadius as parent handles card styling
    }
}