import SwiftUI
import CoreData

private struct ObservedCardView<Content: View>: View {
    @ObservedObject var card: Card
    let content: (Card) -> Content
    
    var body: some View {
        content(card)
    }
}

private struct StoredPhotoThumbnail: View {
    let assetIdentifier: String?
    let legacyData: Data?

    @State private var image: UIImage?

    var body: some View {
        if assetIdentifier != nil || legacyData != nil {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemFill))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Attached photo")
            .task(id: photoLoadIdentifier) {
                await loadImage()
            }
        }
    }

    private var photoLoadIdentifier: String {
        assetIdentifier ?? "legacy-\(legacyData?.count ?? 0)"
    }

    private func loadImage() async {
        if let assetIdentifier {
            image = try? await PhotoLibraryStore.image(for: assetIdentifier)
        } else if let legacyData {
            image = UIImage(data: legacyData)
        } else {
            image = nil
        }
    }
}

private struct StoredPhotoDetailView: View {
    let title: LocalizedStringResource
    let assetIdentifier: String?
    let legacyData: Data?

    @State private var image: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        if assetIdentifier != nil || legacyData != nil {
            Group {
                if let image {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .fontWeight(.bold)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel(title)
                    }
                    .padding(.vertical, 8)
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Spacer()
                        ProgressView("Loading photo…")
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
            .task(id: photoLoadIdentifier) {
                await loadImage()
            }
        }
    }

    private var photoLoadIdentifier: String {
        assetIdentifier ?? "legacy-\(legacyData?.count ?? 0)"
    }

    private func loadImage() async {
        errorMessage = nil
        if let assetIdentifier {
            do {
                image = try await PhotoLibraryStore.image(for: assetIdentifier)
            } catch {
                image = legacyData.flatMap(UIImage.init(data:))
                if image == nil {
                    errorMessage = error.localizedDescription
                }
            }
        } else if let legacyData {
            image = UIImage(data: legacyData)
        } else {
            image = nil
        }
    }
}

private struct DashboardMetricCard: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)

            Spacer(minLength: 0)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ModernListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct ListEmptyState: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

private extension View {
    func modernListRow() -> some View {
        modifier(ModernListRow())
    }

    func modernListStyle() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }
}

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
                                        UserDefaults.standard.double(forKey: "tradeInCashRatio") : 1.00)
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
    private enum AppTab: Hashable {
        case overview
        case cards
        case transactions
        case settings
    }

    @State private var selectedTab: AppTab = .overview
    @State private var overviewPath = NavigationPath()
    @State private var cardsPath = NavigationPath()
    @State private var transactionsPath = NavigationPath()
    @Environment(\.managedObjectContext) var moc
    @StateObject private var settings = appSettings
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Card.dateAdded, ascending: false)],
        predicate: NSPredicate(format: "available == YES"),
        animation: .default
    )
    private var availableCards: FetchedResults<Card>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Card.dateAdded, ascending: false)],
        predicate: NSPredicate(format: "available == NO"),
        animation: .default
    )
    private var soldCards: FetchedResults<Card>
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
    
    private var lastCashBalanceValue: NSDecimalNumber {
        lastCashBalance?.balance ?? NSDecimalNumber.zero
    }
    
    private var lastProfitBalanceValue: NSDecimalNumber {
        lastProfit?.total ?? NSDecimalNumber.zero
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $overviewPath) {
                overviewDashboard
                    .navigationDestination(for: String.self) { value in
                        overviewDestination(for: value)
                    }
            }
            .tabItem {
                Label("Overview", systemImage: "chart.bar.fill")
            }
            .tag(AppTab.overview)

            NavigationStack(path: $cardsPath) {
                availableCardsView
                    .navigationTitle("Cards")
                    .navigationDestination(for: String.self) { value in
                        if value == "addCard" {
                            AddItemView()
                        }
                    }
            }
            .tabItem {
                Label("Cards", systemImage: "rectangle.stack.fill")
            }
            .tag(AppTab.cards)

            NavigationStack(path: $transactionsPath) {
                transactionsView
                    .navigationTitle("Transactions")
                    .navigationDestination(for: String.self) { value in
                        if value == "addTransaction" {
                            AddTransactionView()
                        }
                    }
            }
            .tabItem {
                Label("Transactions", systemImage: "arrow.left.arrow.right")
            }
            .tag(AppTab.transactions)

            NavigationStack {
                settingsView
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(.michiganLightBlue)
        .onAppear { refreshData() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSManagedObjectContextDidSave,
                object: moc
            )
        ) { _ in
            refreshData()
        }
        .environmentObject(settings)
    }
    
    private func refreshData() {
        fetchTransactions()
        fetchCashBalances()
        fetchCashFlows()
        fetchProfits()
        fetchCounts()
        fetchLatestBalances()
    }
    
    private var totalAvailableCardsValue: NSDecimalNumber {
        let total = availableCards.reduce(Decimal.zero) { total, card in
            let currentValue = card.currentValue as Decimal? ?? Decimal.zero
            return total + currentValue
        }
        return total as NSDecimalNumber
    }

    private var overviewDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image("card-management-v2-launch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card Management")
                            .font(.title2.weight(.bold))
                        Text("Your collection at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    Button { selectedTab = .cards } label: {
                        DashboardMetricCard(
                            title: "Available Cards",
                            value: availableCards.count.formatted(),
                            systemImage: "rectangle.stack.fill",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    Button { selectedTab = .cards } label: {
                        DashboardMetricCard(
                            title: "Inventory Value",
                            value: formattedCurrency(totalAvailableCardsValue),
                            systemImage: "dollarsign.circle.fill",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: "cashBalance") {
                        DashboardMetricCard(
                            title: "Cash Balance",
                            value: formattedCurrency(lastCashBalanceValue),
                            systemImage: "banknote.fill",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: "profit") {
                        DashboardMetricCard(
                            title: "Total Profit",
                            value: formattedCurrency(lastProfitBalanceValue),
                            systemImage: "chart.line.uptrend.xyaxis",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("More")
                        .font(.headline)

                    VStack(spacing: 0) {
                        Button { selectedTab = .transactions } label: {
                            dashboardLinkLabel(
                                title: "Transactions",
                                detail: "\(transactionCount) transactions",
                                systemImage: "arrow.left.arrow.right.circle.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 44)

                        NavigationLink(value: "soldCards") {
                            dashboardLinkLabel(
                                title: "Previously Owned Cards",
                                detail: "\(soldCards.count) cards",
                                systemImage: "archivebox.fill"
                            )
                        }

                        Divider().padding(.leading, 44)

                        NavigationLink(value: "cashFlow") {
                            dashboardLinkLabel(
                                title: "Other Cash Flow",
                                detail: "\(cashFlowCount) entries",
                                systemImage: "arrow.up.arrow.down.circle.fill"
                            )
                        }
                    }
                    .padding(.horizontal)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    showingDetailedInstructions = true
                } label: {
                    Label("Help & Instructions", systemImage: "questionmark.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingDetailedInstructions) {
                    DetailedInstructionsView()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Overview")
    }

    private func dashboardLinkLabel(
        title: LocalizedStringResource,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(Color.michiganLightBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }

    private func formattedCurrency(_ value: NSDecimalNumber) -> String {
        currencyFormatter(for: settings.defaultCurrency).string(from: value) ?? value.stringValue
    }

    @ViewBuilder
    private func overviewDestination(for value: String) -> some View {
        switch value {
        case "cashBalance":
            cashBalanceView.navigationTitle("Cash Balance")
        case "profit":
            profitView.navigationTitle("Profit")
        case "soldCards":
            soldCardsView.navigationTitle("Previously Owned")
        case "cashFlow":
            cashFlowView.navigationTitle("Other Cash Flow")
        case "addCashFlow":
            AddCashFlowView()
        default:
            Text("Unknown destination")
        }
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
        List {
            let cards = filteredAndSortedCards(cards: Array(availableCards))
            if cards.isEmpty {
                ListEmptyState(title: searchText.isEmpty ? "No Cards Yet" : "No Matching Cards", message: searchText.isEmpty ? "Add your first card to start tracking your collection." : "Try a different card name or clear the search.", systemImage: searchText.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass")
            } else {
                ForEach(cards) { item in
                    NavigationLink {
                        ObservedCardView(card: item) { card in
                            cardDetailView(for: card)
                        }
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
                        ObservedCardView(card: item) { card in
                            cardRowLabel(for: card)
                        }
                    }
                    .modernListRow()
                }
            }
        }
        .modernListStyle()
        .searchable(text: $searchText, prompt: "Search cards")
        .onAppear {
            searchText = ""
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    cardsPath.append("addCard")
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }
        }
    }
    
    private var cashBalanceView: some View {
        List {
            if cashBalances.isEmpty {
                ListEmptyState(title: "No Balance History", message: "Balance snapshots will appear here as your cash changes.", systemImage: "banknote")
            }
            ForEach(cashBalances) { item in
                NavigationLink {
                    cashBalanceDetailView(for: item)
                } label: {
                    cashBalanceRowLabel(for: item)
                }
                .modernListRow()
            }
        }
        .modernListStyle()
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
            if cashFlows.isEmpty {
                ListEmptyState(title: "No Cash Flow Yet", message: "Record money in or out to see your history here.", systemImage: "arrow.up.arrow.down.circle")
            }
            ForEach(cashFlows) { item in
                NavigationLink {
                    cashFlowDetailView(for: item)
                } label: {
                    cashFlowRowLabel(for: item)
                }
                .modernListRow()
            }
        }
        .modernListStyle()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Cash Flow") {
                    overviewPath.append("addCashFlow")
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
        List {
            let cards = filteredAndSortedCards(cards: Array(soldCards))
            if cards.isEmpty {
                ListEmptyState(title: searchText.isEmpty ? "No Sold Cards" : "No Matching Cards", message: searchText.isEmpty ? "Cards you sell will be collected here." : "Try a different card name or clear the search.", systemImage: searchText.isEmpty ? "checkmark.seal" : "magnifyingglass")
            } else {
                ForEach(cards) { item in
                    NavigationLink {
                        ObservedCardView(card: item) { card in
                            soldCardDetailView(for: card)
                        }
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
                        ObservedCardView(card: item) { card in
                            cardRowLabel(for: card)
                        }
                    }
                    .modernListRow()
                }
            }
        }
        .modernListStyle()
        .searchable(text: $searchText, prompt: "Search sold cards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .onAppear {
            searchText = ""
        }
    }
    
    private var profitView: some View {
        List {
            if profits.isEmpty {
                ListEmptyState(title: "No Profit History", message: "Profit snapshots will appear after your transactions are recorded.", systemImage: "chart.line.uptrend.xyaxis")
            }
            ForEach(profits) { item in
                NavigationLink {
                    profitDetailView(for: item)
                } label: {
                    profitRowLabel(for: item)
                }
                .modernListRow()
            }
        }
        .modernListStyle()
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
            if transactions.isEmpty {
                ListEmptyState(title: "No Transactions Yet", message: "Add a purchase, sale, or trade to start your history.", systemImage: "arrow.left.arrow.right.circle")
            }
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
                .modernListRow()
            }
        }
        .modernListStyle()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Transaction") {
                    transactionsPath.append("addTransaction")
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
        
        // Keep image bytes deferred while fetching the lightweight photo reference.
        fetchRequest.propertiesToFetch = [
            "pk", "dateTime", "platform", "cashIn", "cashOut",
            "cardsIn", "cardsOut", "profit", "feesAndShipping", "platformId",
            "photoAssetIdentifier"
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
            StoredPhotoDetailView(
                title: "Card Photo",
                assetIdentifier: item.photoAssetIdentifier,
                legacyData: item.photoData
            )
        }
        .navigationTitle(item.title ?? "Card Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func soldCardDetailView(for item: Card) -> some View {
        List {
            Text("Description:").fontWeight(.bold) + Text(" \(item.note ?? "No description")")
            Text("Available:").fontWeight(.bold) + Text(" \(item.available ? "Yes" : "No")")
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
            StoredPhotoDetailView(
                title: "Card Photo",
                assetIdentifier: item.photoAssetIdentifier,
                legacyData: item.photoData
            )
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
            StoredPhotoDetailView(
                title: "Transaction Photo",
                assetIdentifier: item.photoAssetIdentifier,
                legacyData: item.photoData
            )
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
    
    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private func cardRowLabel(for item: Card) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title ?? "Unknown Card")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let currentValue = item.currentValue {
                    Text(currentValue, formatter: currencyFormatter(for: settings.defaultCurrency))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.tint)
                }
                Text(item.available ? "Available" : "Sold")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.available ? Color.green : Color.secondary)
            }
            Spacer(minLength: 8)
            StoredPhotoThumbnail(
                assetIdentifier: item.photoAssetIdentifier,
                legacyData: item.photoData
            )
        }
    }
    
    private func transactionRowLabel(for item: Transaction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                if let dateTime = item.dateTime {
                    Text(dateTime, style: .date)
                        .font(.headline.weight(.semibold))
                }
                if let platformId = item.platformId, !platformId.isEmpty {
                    Label(platformId, systemImage: "person.crop.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let cardsIn = item.cardsIn, !cardsIn.isEmpty {
                    Label(cardsIn, systemImage: "arrow.down.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let cardsOut = item.cardsOut, !cardsOut.isEmpty {
                    Label(cardsOut, systemImage: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            StoredPhotoThumbnail(
                assetIdentifier: item.photoAssetIdentifier,
                legacyData: item.photoData
            )
        }
    }

    private func cashBalanceRowLabel(for item: CashBalance) -> some View {
        return HStack(spacing: 14) {
            Image(systemName: "banknote.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(item.balance ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))
                    .font(.title3.weight(.bold))
                if let dateTime = item.dateTime {
                    Text(dateTime, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cashFlowRowLabel(for item: CashFlow) -> some View {
        let change = item.change ?? NSDecimalNumber.zero
        let isPositive = change.compare(NSDecimalNumber.zero) != .orderedAscending
        return HStack(spacing: 14) {
            Image(systemName: isPositive ? "arrow.down.left" : "arrow.up.right")
                .font(.headline)
                .foregroundStyle(isPositive ? Color.green : Color.red)
                .frame(width: 44, height: 44)
                .background((isPositive ? Color.green : Color.red).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(change, formatter: currencyFormatter(for: settings.defaultCurrency))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isPositive ? Color.green : Color.red)
                if let note = item.note, !note.isEmpty {
                    Text(note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if let dateTime = item.dateTime {
                    Text(dateTime, style: .date).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func profitRowLabel(for item: Profit) -> some View {
        let change = item.change ?? NSDecimalNumber.zero
        let comparison = change.compare(NSDecimalNumber.zero)
        let changeColor: Color = comparison == .orderedDescending ? .green : comparison == .orderedAscending ? .red : .secondary
        let formattedChange = currencyFormatter(for: settings.defaultCurrency).string(from: change) ?? change.stringValue
        let signedChange = comparison == .orderedDescending ? "+\(formattedChange)" : formattedChange

        return HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(item.total ?? NSDecimalNumber.zero, formatter: currencyFormatter(for: settings.defaultCurrency))
                    .font(.title3.weight(.bold))
                Text("Change: \(signedChange)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(changeColor)
                if let timestamp = item.timestamp {
                    Text(timestamp, style: .date).font(.subheadline).foregroundStyle(.secondary)
                }
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
