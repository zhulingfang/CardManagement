import SwiftUI
import CoreData

extension Color {
    static let michiganBlue = Color(red: 0/255, green: 39/255, blue: 76/255)
    static let michiganLightBlue = Color(red: 0/255, green: 60/255, blue: 116/255)
}

// Settings class to manage app-wide settings
class AppSettings: ObservableObject {
    @Published var tradeInCashRatio: Decimal {
        didSet {
            UserDefaults.standard.set(NSDecimalNumber(decimal: tradeInCashRatio).doubleValue, forKey: "tradeInCashRatio")
        }
    }
    
    @Published var defaultCurrency: String {
        didSet {
            UserDefaults.standard.set(defaultCurrency, forKey: "defaultCurrency")
        }
    }
    
    @Published var maxCardTitleLength: Int {
        didSet {
            UserDefaults.standard.set(maxCardTitleLength, forKey: "maxCardTitleLength")
        }
    }
    
    @Published var markCardUnavailableWhenSold: Bool {
        didSet {
            UserDefaults.standard.set(markCardUnavailableWhenSold, forKey: "markCardUnavailableWhenSold")
        }
    }
    
    init() {
        // Load saved settings or use defaults
        self.tradeInCashRatio = Decimal(UserDefaults.standard.double(forKey: "tradeInCashRatio") != 0 ?
                                      UserDefaults.standard.double(forKey: "tradeInCashRatio") : 0.90)
        self.defaultCurrency = UserDefaults.standard.string(forKey: "defaultCurrency") ?? "USD"
        self.maxCardTitleLength = UserDefaults.standard.integer(forKey: "maxCardTitleLength") != 0 ?
                                 UserDefaults.standard.integer(forKey: "maxCardTitleLength") : 50
        self.markCardUnavailableWhenSold = UserDefaults.standard.object(forKey: "markCardUnavailableWhenSold") as? Bool ?? true
    }
}

// Global settings instance
var appSettings = AppSettings()

@available(iOS 16.0, *)
struct ContentView: View {
    @State private var path = NavigationPath()
    @Environment(\.managedObjectContext) var moc
    @StateObject private var settings = appSettings
    @State private var items: [Card] = []
    @State private var transactions: [Transaction] = []
    @State private var cashBalances: [CashBalance] = []
    @State private var profits: [Profit] = []
    @State private var cashFlows: [CashFlow] = []
    @State private var transactionCount: Int = 0
    @State private var cashFlowCount: Int = 0
    @State private var lastCashBalance: CashBalance?
    @State private var lastProfit: Profit?
    
    @State private var selectedItem: Card?
    @State private var selectedSoldCard: Card?
    @State private var selectedTransaction: Transaction?
    @State private var showingDetailedInstructions = false
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = SortOption.titleAsc
    
    @State private var showFullScreenPhoto = false
    @State private var selectedPhotoData: Data?
    
    enum SortOption: String, CaseIterable {
        case titleAsc = "Title Alphabet from A to Z"
        case titleDesc = "Title Alphabet from Z to A"
        case dateAddedMostRecent = "Date Added Most Recent"
        case dateAddedOldest = "Date Added Oldest"
        case currentValueHighest = "Current Value Highest"
        case currentValueLowest = "Current Value Lowest"
    }
    
    private var availableCards: [Card] {
        items.filter { $0.available == true }
    }
    
    private var soldCards: [Card] {
        items.filter { $0.available == false }
    }
    
    private var lastCashBalanceValue: NSDecimalNumber {
        lastCashBalance?.balance ?? NSDecimalNumber.zero
    }
    
    private var lastProfitBalanceValue: NSDecimalNumber {
        lastProfit?.total ?? NSDecimalNumber.zero
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 5) {
                ZStack {
                    // Centered title (ignoring the icon)
                    Text("Card Management")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.michiganLightBlue)
                    
                    // Icon positioned to the left
                    HStack {
                        Image("card-tracker-app-icon")
                            .resizable()
                            .scaledToFit()
                            .padding(.leading, UIScreen.main.bounds.width * 0.05)
                            .frame(width: 60, height: 60)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 5) {
                    List {
                        // Available Cards Section
                        NavigationLink {
                            availableCardsView
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Available Cards: \(availableCards.count)")
                                Text("Total Value: \(totalAvailableCardsValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        
                        // Previously Owned Cards Section
                        NavigationLink("Previously Owned Cards: \(soldCards.count)") {
                            soldCardsView
                        }
                        .padding(8)
                        
                        // Transactions Section
                        NavigationLink("Card Transactions: \(transactionCount)") {
                            transactionsView
                        }
                        .padding(8)
                        
                        // Other Cash flow Section
                        NavigationLink("Other Cash Flow: \(cashFlowCount)") {
                            cashFlowView
                        }
                        .padding(8)
                        
                        // Cash Balance Section
                        NavigationLink {
                            cashBalanceView
                        } label: {
                            Text("Cash Balance: ") + Text("\(lastCashBalanceValue, formatter: currencyFormatter(for: settings.defaultCurrency))").foregroundColor(.red)
                        }
                        .padding(8)
                        
                        // Total Profit Section
                        NavigationLink("Total Profit: \(lastProfitBalanceValue, formatter: currencyFormatter(for: settings.defaultCurrency))") {
                            profitView
                        }
                        .padding(8)
                        
                        // Settings Section
                        NavigationLink("Settings") {
                            settingsView
                        }
                        .padding(8)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To add a new card transaction, go to Available Cards to add the new cards, then choose the cards when adding the new transaction. Cash balance and Profit will be automatically updated when transaction is added or updated.")
                            .font(.subheadline)
                            .foregroundColor(.michiganLightBlue)
                        
                        Button("See more instructions") {
                            showingDetailedInstructions = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                        .sheet(isPresented: $showingDetailedInstructions) {
                            DetailedInstructionsView()
                        }
                    }
                    .padding()
                    .border(Color.blue, width: 2)
                    
                    Text("@ Owned by cycl0necardz")
                        .padding()
                        .font(.footnote)
                }
            }
            .navigationBarHidden(true) // Hide the default navigation bar
            .navigationDestination(for: String.self) { value in
                switch value {
                case "addCard":
                    AddItemView()
                case "adjustCashBalance":
                    AdjustCashBalanceView()
                case "adjustProfit":
                    AdjustProfitView()
                case "addTransaction":
                    AddTransactionView()
                case "addCashFlow":
                    AddCashFlowView()
                default:
                    Text("Unknown destination")
                }
            }
            .onAppear {
                fetchCards()
                fetchCounts()
                fetchLatestBalances()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)) { _ in
                // Refresh when data changes
                fetchCards()
                fetchCounts()
                fetchLatestBalances()
            }
        }
        .environmentObject(settings)
    }
    
    private func fetchCards() {
        let fetchRequest = NSFetchRequest<Card>(entityName: "Card")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Card.dateAdded, ascending: false)]
        
        // Fetch Card EXCEPT photoData
        fetchRequest.propertiesToFetch = [
            "id", "title", "available", "currentValue", "dateAdded",
            "dateSold", "note", "paid", "sold",
            "timestamp", "tradeInValue", "tradeOutValue"
        ]
        
        do {
            items = try moc.fetch(fetchRequest)
        } catch {
            print("Error fetching cards: \(error)")
        }
    }
    
    private var totalAvailableCardsValue: NSDecimalNumber {
        let total = availableCards.reduce(Decimal.zero) { total, card in
            let currentValue = card.currentValue as Decimal? ?? Decimal.zero
            return total + currentValue
        }
        return total as NSDecimalNumber
    }
    
    private func fetchCounts() {
        // Fetch transaction count only
        let transactionRequest = NSFetchRequest<Transaction>(entityName: "Transaction")
        do {
            transactionCount = try moc.count(for: transactionRequest)
        } catch {
            print("Error counting transactions: \(error)")
            transactionCount = 0
        }
        
        // Fetch cash flow count only
        let cashFlowRequest = NSFetchRequest<CashFlow>(entityName: "CashFlow")
        do {
            cashFlowCount = try moc.count(for: cashFlowRequest)
        } catch {
            print("Error counting cash flows: \(error)")
            cashFlowCount = 0
        }
    }
    
    private func fetchLatestBalances() {
        // Fetch only the latest cash balance
        let cashBalanceRequest = NSFetchRequest<CashBalance>(entityName: "CashBalance")
        cashBalanceRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CashBalance.pk, ascending: false)]
        cashBalanceRequest.fetchLimit = 1
        
        do {
            lastCashBalance = try moc.fetch(cashBalanceRequest).first
        } catch {
            print("Error fetching last cash balance: \(error)")
            lastCashBalance = nil
        }
        
        // Fetch only the latest profit
        let profitRequest = NSFetchRequest<Profit>(entityName: "Profit")
        profitRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Profit.timestamp, ascending: false)]
        profitRequest.fetchLimit = 1
        
        do {
            lastProfit = try moc.fetch(profitRequest).first
        } catch {
            print("Error fetching last profit: \(error)")
            lastProfit = nil
        }
    }
}

// MARK: - View Components
@available(iOS 16.0, *)
extension ContentView {
    private func filteredAndSortedCards(cards: [Card]) -> [Card] {
        let filtered = cards.filter { card in
            searchText.isEmpty || (card.title?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        switch sortOption {
        case .titleAsc:
            return filtered.sorted { card1, card2 in
                let title1 = card1.title ?? ""
                let title2 = card2.title ?? ""
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
            }
        case .titleDesc:
            return filtered.sorted { card1, card2 in
                let title1 = card1.title ?? ""
                let title2 = card2.title ?? ""
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedDescending
            }
        case .dateAddedMostRecent:
            return filtered.sorted { card1, card2 in
                // Handle null dates by putting them at the end
                guard let date1 = card1.dateAdded else { return false }
                guard let date2 = card2.dateAdded else { return true }
                return date1 > date2 // Most recent first
            }
        case .currentValueHighest:
            return filtered.sorted { card1, card2 in
                // Handle null values by treating them as 0
                let value1 = card1.currentValue as Decimal? ?? 0
                let value2 = card2.currentValue as Decimal? ?? 0
                return value1 > value2 // Highest value first
            }
        case .dateAddedOldest:
            return filtered.sorted { card1, card2 in
                // Handle null dates by putting them at the end
                guard let date1 = card1.dateAdded else { return false }
                guard let date2 = card2.dateAdded else { return true }
                return date1 < date2 // Most recent first
            }
        case .currentValueLowest:
            return filtered.sorted { card1, card2 in
                // Handle null values by treating them as 0
                let value1 = card1.currentValue as Decimal? ?? 0
                let value2 = card2.currentValue as Decimal? ?? 0
                return value1 < value2 // Highest value first
            }
        }
    }

    private var availableCardsView: some View {
        VStack(spacing: 0) {
            // Search and Sort Controls
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search cards...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Sort By Menu
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Cards List
            List {
                ForEach(filteredAndSortedCards(cards: availableCards)) { item in
                    NavigationLink {
                        cardDetailView(for: item)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Edit") {
                                        selectedItem = item
                                    }
                                    .sheet(item: $selectedItem) { item in
                                        EditCardView(selectedCard: item)
                                    }
                                }
                            }
                    } label: {
                        cardRowLabel(for: item)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .onAppear {
                searchText = ""
            }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Card") {
                    path.append("addCard")
                }
            }
        }
    }
    
    private var cashBalanceView: some View {
        List {
            ForEach(cashBalances) { item in
                NavigationLink {
                    cashBalanceDetailView(for: item)
                } label: {
                    if let dateTime = item.dateTime {
                        Text("Balance:").fontWeight(.bold) + Text("\(item.balance ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))") + Text(" on \(dateTime, style: .date)").font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Balance:").fontWeight(.bold) + Text("\(item.balance ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))")
                    }
                }
            }
        }
        .onAppear {
            fetchCashBalances()
        }
    }
    private func fetchCashBalances() {
        let fetchRequest = NSFetchRequest<CashBalance>(entityName: "CashBalance")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CashBalance.pk, ascending: false)]
        
        do {
            cashBalances = try moc.fetch(fetchRequest)
        } catch {
            print("Error fetching cash balances: \(error)")
        }
    }
    
    private var cashFlowView: some View {
        List {
            ForEach(cashFlows) { item in
                NavigationLink {
                    cashFlowDetailView(for: item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let dateTime = item.dateTime {
                            Text("Change: ").fontWeight(.bold) + Text("\(item.change ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))") + Text(" on \(dateTime, style: .date)").font(.subheadline)
                                .foregroundColor(.secondary)
                            if let note = item.note, !note.isEmpty {
                                Text("Description: \(note)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Change: ").fontWeight(.bold) + Text("\(item.change ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))")
                            if let note = item.note, !note.isEmpty {
                                Text("Description: \(note)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Cash Flow") {
                    path.append("addCashFlow")
                }
            }
        }
        .onAppear {
            fetchCashFlows()
        }
    }
    private func fetchCashFlows() {
        let fetchRequest = NSFetchRequest<CashFlow>(entityName: "CashFlow")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CashFlow.dateTime, ascending: false)]
        
        do {
            cashFlows = try moc.fetch(fetchRequest)
        } catch {
            print("Error fetching cash flows: \(error)")
        }
    }
    
    private var soldCardsView: some View {
        VStack(spacing: 0) {
            // Search and Sort Controls
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search cards...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Sort By Menu
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Cards List
            List {
                ForEach(filteredAndSortedCards(cards: soldCards)) { item in
                    NavigationLink {
                        soldCardDetailView(for: item)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Edit") {
                                        selectedSoldCard = item
                                    }
                                    .sheet(item: $selectedSoldCard) { item in
                                        EditCardView(selectedCard: item)
                                    }
                                }
                            }
                    } label: {
                        cardRowLabel(for: item)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .onAppear{
            searchText = ""
        }
    }
    
    private var profitView: some View {
        List {
            ForEach(profits) { item in
                NavigationLink {
                    profitDetailView(for: item)
                } label: {
                    if let dateTime = item.timestamp {
                        Text("Total:").fontWeight(.bold) + Text(" \(item.total ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))") + Text(" on \(dateTime, style: .date)").font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Total:").fontWeight(.bold) + Text(" \(item.total ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))")
                    }
                }
            }
        }
        .onAppear {
            fetchProfits()
        }
    }
    private func fetchProfits() {
        let fetchRequest = NSFetchRequest<Profit>(entityName: "Profit")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Profit.timestamp, ascending: false)]
        
        do {
            profits = try moc.fetch(fetchRequest)
        } catch {
            print("Error fetching cash flows: \(error)")
        }
    }
    
    private var transactionsView: some View {
        List {
            ForEach(transactions) { item in
                NavigationLink {
                    transactionDetailView(for: item)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Edit") {
                                    selectedTransaction = item
                                }
                                .sheet(item: $selectedTransaction) { item in
                                    EditTransactionView(selectedTransaction: item)
                                }
                            }
                        }
                } label: {
                    transactionRowLabel(for: item)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Transaction") {
                    path.append("addTransaction")
                }
            }
        }
        .onAppear {
            fetchTransactions()
        }
    }
    private func fetchTransactions() {
        let fetchRequest = NSFetchRequest<Transaction>(entityName: "Transaction")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.dateTime, ascending: false)]
        
        // Exclude photoData - list all Transaction properties EXCEPT photoData
        fetchRequest.propertiesToFetch = [
            "pk", "dateTime", "platform", "cashIn", "cashOut",
            "cardsIn", "cardsOut", "profit", "feesAndShipping", "platformId"
            // Add any other Transaction properties you have, but NOT "photoData"
        ]
        
        do {
            transactions = try moc.fetch(fetchRequest)
        } catch {
            print("Error fetching transactions: \(error)")
        }
    }
    private var settingsView: some View {
        SettingsView()
            .environmentObject(settings)
    }
}

//Detail Views
@available(iOS 16.0, *)
extension ContentView {
    private func cardDetailView(for item: Card) -> some View {
        List {
            //Text(item.title ?? "Unknown Card").bold()
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            Text("Available:").fontWeight(.bold) + Text(" \(item.available ? "Yes" : "No")")
            
            // Photo Section with Full-Screen View
            if let photoData = item.photoData,
               let image = UIImage(data: photoData) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Photo:")
                        .fontWeight(.bold)
                    
                    ZoomableImageView(image: image)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Pinch to zoom, drag to pan, double tap to reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if let currentValue = item.currentValue {
                Text("Current value:").fontWeight(.bold) + Text(" \(currentValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let tradeInValue = item.tradeInValue {
                Text("Trade in value:").fontWeight(.bold) + Text(" \(tradeInValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let tradeOutValue = item.tradeOutValue {
                Text("Trade out value:").fontWeight(.bold) + Text(" \(tradeOutValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let paid = item.paid {
                Text("Paid:").fontWeight(.bold) + Text(" \(paid, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let sold = item.sold {
                Text("Sold for:").fontWeight(.bold) + Text(" \(sold, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let dateAdded = item.dateAdded {
                Text("Added on:").fontWeight(.bold) + Text(" \(dateAdded, style: .date)")
            }
            if let dateSold = item.dateSold {
                Text("Sold on:").fontWeight(.bold) + Text(" \(dateSold, style: .date)")
            }
        }
        .navigationTitle(item.title ?? "Card Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func soldCardDetailView(for item: Card) -> some View {
        List {
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            Text("Available:").fontWeight(.bold) + Text(" \(item.available ? "Yes" : "No")")
            // Photo Section with Full-Screen View
            if let photoData = item.photoData,
               let image = UIImage(data: photoData) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Photo:")
                        .fontWeight(.bold)
                    
                    ZoomableImageView(image: image)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Pinch to zoom, drag to pan, double tap to reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            if let currentValue = item.currentValue {
                Text("Current value:").fontWeight(.bold) + Text(" \(currentValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let tradeInValue = item.tradeInValue {
                Text("Trade in value:").fontWeight(.bold) + Text(" \(tradeInValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let tradeOutValue = item.tradeOutValue {
                Text("Trade out value:").fontWeight(.bold) + Text(" \(tradeOutValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let paid = item.paid {
                Text("Paid:").fontWeight(.bold) + Text(" \(paid, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let sold = item.sold {
                Text("Sold for:").fontWeight(.bold) + Text(" \(sold, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let dateAdded = item.dateAdded {
                Text("Added on:").fontWeight(.bold) + Text(" \(dateAdded, style: .date)")
            }
            if let dateSold = item.dateSold {
                Text("Sold on:").fontWeight(.bold) + Text(" \(dateSold, style: .date)")
            }
        }
        .navigationTitle(item.title ?? "Sold Card Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func cashBalanceDetailView(for item: CashBalance) -> some View {
        List {
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            if let balance = item.balance {
                Text("Balance:").fontWeight(.bold) + Text(" \(balance, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let change = item.change {
                Text("Changed by:").fontWeight(.bold) + Text(" \(change, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let dateTime = item.dateTime {
                Text("Created on:").fontWeight(.bold) + Text(" \(dateTime, style: .date)")
            }
        }
        .navigationTitle("Cash Balance Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func cashFlowDetailView(for item: CashFlow) -> some View {
        List {
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            if let change = item.change {
                Text("Changed by:").fontWeight(.bold) + Text(" \(change, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let dateTime = item.dateTime {
                Text("Created on:").fontWeight(.bold) + Text(" \(dateTime, style: .date)")
            }
        }
        .navigationTitle("Cash Flow Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func profitDetailView(for item: Profit) -> some View {
        List {
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            if let total = item.total {
                Text("Total profit:").fontWeight(.bold) + Text(" \(total, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let change = item.change {
                Text("Changed by:").fontWeight(.bold) + Text(" \(change, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            if let timestamp = item.timestamp {
                Text("Updated on:").fontWeight(.bold) + Text(" \(timestamp, style: .date)")
            }
        }
        .navigationTitle("Profit Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func transactionDetailView(for item: Transaction) -> some View {
        List {
            if let dateTime = item.dateTime {
                Text("Trade date:").fontWeight(.bold) + Text(" \(dateTime, style: .date)")
            }
            
            if let platform = item.platform, let platformId = item.platformId {
                Text("Platform:").fontWeight(.bold) + Text(" \(platform)")
                Text("Platform ID:").fontWeight(.bold) + Text(" \(platformId)")
            }
            
            // Photo Section
            if let photoData = item.photoData,
               let image = UIImage(data: photoData) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transaction Photo:")
                        .fontWeight(.bold)
                    
                    ZoomableImageView(image: image)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Pinch to zoom, drag to pan, double tap to reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if let cardsIn = item.cardsIn, !cardsIn.isEmpty {
                Text("Cards traded in:").fontWeight(.bold) + Text(" \(cardsIn)")
            }
            
            if let cardsOut = item.cardsOut, !cardsOut.isEmpty {
                Text("Cards traded out:").fontWeight(.bold) + Text(" \(cardsOut)")
            }
            
            if let cashIn = item.cashIn {
                Text("Cash received:").fontWeight(.bold) + Text(" \(cashIn, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            
            if let cashOut = item.cashOut {
                Text("Cash paid:").fontWeight(.bold) + Text(" \(cashOut, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            
            if let fees = item.feesAndShipping {
                Text("Total fees and shippings:").fontWeight(.bold) + Text(" \(fees, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
            
            if let profit = item.profit {
                Text("Profit:").fontWeight(.bold) + Text(" \(profit, formatter: currencyFormatter(for: settings.defaultCurrency))")
            }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    struct ZoomableImageView: View {
        let image: UIImage
        @State private var scale: CGFloat = 1.0
        @State private var lastScale: CGFloat = 1.0
        @State private var offset: CGSize = .zero
        @State private var lastOffset: CGSize = .zero
        
        var body: some View {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale,
                               height: geometry.size.height * scale)
                        .offset(offset)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 0.5), 4.0) // Limit zoom between 0.5x and 4x
                                }
                                .onEnded { value in
                                    lastScale = 1.0
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { value in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to reset
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                }
                .clipped()
            }
        }
    }
}

@available(iOS 16.0, *)
extension ContentView {
    
    private func cardRowLabel(for item: Card) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title ?? "Unknown Card")
                .font(.headline)
            if let currentValue = item.currentValue {
                Text("Current value:") + Text(" \(currentValue, formatter: currencyFormatter(for: settings.defaultCurrency))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func transactionRowLabel(for item: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let dateTime = item.dateTime {
                Text("Trade on").fontWeight(.bold) + Text(" \(dateTime, style: .date)")
                    //.font(.headline)
            }
            if let platformId = item.platformId, !platformId.isEmpty {
                Text("With: \(platformId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let cardsIn = item.cardsIn, !cardsIn.isEmpty {
                Text("Cards traded in: \(cardsIn)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let cardsOut = item.cardsOut, !cardsOut.isEmpty {
                Text("Cards traded out: \(cardsOut)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

public func currencyFormatter(for currencyCode: String) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode
    formatter.locale = Locale.current
    return formatter
}

// Fallback formatter for compatibility
public let itemFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    return formatter
}()

public let percentFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    return formatter
}()
