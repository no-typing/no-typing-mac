import SwiftUI

struct SearchableLanguagePicker: View {
    @Binding var selection: String
    let languages: [TranscriptionLanguage]
    
    @State private var searchText = ""
    @State private var isShowingPopover = false
    
    var selectedLanguageName: String {
        languages.first(where: { $0.code.uppercased() == selection.uppercased() })?.name ?? selection
    }
    
    var filteredLanguages: [TranscriptionLanguage] {
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { 
                $0.name.lowercased().contains(searchText.lowercased()) || 
                $0.code.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        Button(action: {
            isShowingPopover.toggle()
        }) {
            HStack {
                Text(selectedLanguageName)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search languages...", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 8)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05))
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Language List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLanguages) { lang in
                            Button(action: {
                                selection = lang.code
                                isShowingPopover = false
                                searchText = ""
                            }) {
                                HStack {
                                    Text(lang.name)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(lang.code)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    if selection.uppercased() == lang.code.uppercased() {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(ThemeColors.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selection.uppercased() == lang.code.uppercased() ? Color.white.opacity(0.1) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .background(Color.white.opacity(0.05))
                        }
                    }
                }
                .frame(minWidth: 250, maxHeight: 400)
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        }
    }
}
