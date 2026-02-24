import SwiftUI
import CoreData
import UniformTypeIdentifiers

// Settings View
@available(iOS 16.0, *)
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.managedObjectContext) private var viewContext
    @State private var tradeInRatioText: String = ""
    @State private var showingResetAlert = false
    @State private var showingBackupExporter = false
    @State private var backupDocument: BackupDocument?
    @State private var showingBackupAlert = false
    @State private var backupAlertMessage = ""
    @State private var showingRestoreImporter = false
    @State private var showingRestoreConfirmation = false
    @State private var includePhotosInBackup = false
    
    var body: some View {
        Form {
            Section(header: Text("Trading Settings")) {
                //ratio setting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trade-In Cash Ratio (between 0.01 and 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("", text: $tradeInRatioText)
                        .keyboardType(.decimalPad)
                        .onChange(of: tradeInRatioText) { newValue in
                            tradeInRatioText = formatRatioInput(newValue)
                            if let decimal = Decimal(string: tradeInRatioText) {
                                settings.tradeInCashRatio = decimal
                            }
                        }
                    
                    Text("Current ratio: \(settings.tradeInCashRatio as NSDecimalNumber, formatter: percentFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("This ratio is used when calculating a transaction profit, trade-in values count as \(settings.tradeInCashRatio as NSDecimalNumber, formatter: percentFormatter) as cash value")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                
                //auto-mark setting
                Picker("Automatically mark traded cards as unavailable", selection: $settings.markCardUnavailableWhenSold) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .font(.subheadline)
                .fontWeight(.bold)
                Text("This flag is used when a transaction is added or updated, the selected traded out cards will be automatically updated to not available")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("Display Settings")) {
                Picker("Default Currency", selection: $settings.defaultCurrency) {
                    Text("US Dollar (USD)").tag("USD")
                    Text("Euro (EUR)").tag("EUR")
                    Text("British Pound (GBP)").tag("GBP")
                    Text("Japanese Yen (JPY)").tag("JPY")
                    Text("Canadian Dollar (CAD)").tag("CAD")
                    Text("Chinese Yan (CNY)").tag("CNY")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Card Title Length")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Stepper("\(settings.maxCardTitleLength) characters",
                           value: $settings.maxCardTitleLength,
                           in: 10...50,
                           step: 5)
                    
                    Text("Current limit: \(settings.maxCardTitleLength) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Backup & Restore")) {
                Button(action: {
                    includePhotosInBackup = true
                    createBackup(includePhotos: true)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export App Data (with Photos)")
                    }
                }
                
                Button(action: {
                    includePhotosInBackup = false
                    createBackup(includePhotos: false)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Export App Data (without Photos)")
                    }
                }
                
                Text("Export all your cards, transactions, and settings to a JSON file")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {
                    showingRestoreConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Restore from Backup")
                    }
                }
                .foregroundColor(.orange)
                
                Text("Import data from a previously exported backup file. This will replace all current data.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("App Information")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0.3")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tradeInRatioText = String(describing: settings.tradeInCashRatio)
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: generateBackupFilename()
        ) { result in
            switch result {
            case .success(let url):
                backupAlertMessage = "Backup saved successfully to:\n\(url.lastPathComponent)"
                showingBackupAlert = true
            case .failure(let error):
                backupAlertMessage = "Failed to save backup: \(error.localizedDescription)"
                showingBackupAlert = true
            }
        }
        .fileImporter(
            isPresented: $showingRestoreImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                restoreFromBackup(url: url)
            case .failure(let error):
                backupAlertMessage = "Failed to import backup: \(error.localizedDescription)"
                showingBackupAlert = true
            }
        }
        .alert("Backup Status", isPresented: $showingBackupAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupAlertMessage)
        }
        .confirmationDialog("Restore from Backup?", isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingRestoreImporter = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace ALL current data with the data from the backup file. This action cannot be undone.")
        }
    }
    
    private func formatRatioInput(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == "." }
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            return components[0] + "." + components[1]
        }
        
        if components.count == 2 && components[1].count > 3 {
            return components[0] + "." + String(components[1].prefix(3))
        }
        return filtered
    }
        
    private func generateBackupFilename() -> String {
        let appName = "CardMgmt"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let photoSuffix = includePhotosInBackup ? "" : "-NoPhotos"
        return "\(appName)\(photoSuffix)-\(dateString).json"
    }
    
    private func createBackup(includePhotos: Bool) {
        var backupData: [String: Any] = [:]
        var skippedItems: [String: Int] = [:]
        
        // Export Settings
        backupData["settings"] = [
            "tradeInCashRatio": String(describing: settings.tradeInCashRatio),
            "markCardUnavailableWhenSold": settings.markCardUnavailableWhenSold,
            "defaultCurrency": settings.defaultCurrency,
            "maxCardTitleLength": settings.maxCardTitleLength
        ]
        
        // Export Cards
        let cardsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Card")
        if let cards = try? viewContext.fetch(cardsFetch) as? [NSManagedObject] {
            var validCards: [[String: Any]] = []
            var skipped = 0
            
            for card in cards {
                var cardDict: [String: Any] = [:]
                for attribute in card.entity.attributesByName.keys {
                    // Skip photoData if not including photos
                    if attribute == "photoData" && !includePhotos {
                        continue
                    }
                    if let value = card.value(forKey: attribute) {
                        if let serialized = convertToSerializable(value) {
                            cardDict[attribute] = serialized
                        }
                    }
                }
                
                // Only add if we got some valid data
                if !cardDict.isEmpty {
                    validCards.append(cardDict)
                } else {
                    skipped += 1
                    print("Skipped corrupted card")
                }
            }
            
            backupData["cards"] = validCards
            if skipped > 0 {
                skippedItems["cards"] = skipped
            }
        }
        
        // Export Transactions
        let transactionsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Transaction")
        if let transactions = try? viewContext.fetch(transactionsFetch) as? [NSManagedObject] {
            var validTransactions: [[String: Any]] = []
            var skipped = 0
            
            for transaction in transactions {
                var transactionDict: [String: Any] = [:]
                for attribute in transaction.entity.attributesByName.keys {
                    if let value = transaction.value(forKey: attribute) {
                        if let serialized = convertToSerializable(value) {
                            transactionDict[attribute] = serialized
                        }
                    }
                }
                
                if !transactionDict.isEmpty {
                    validTransactions.append(transactionDict)
                } else {
                    skipped += 1
                    print("Skipped corrupted transaction")
                }
            }
            
            backupData["transactions"] = validTransactions
            if skipped > 0 {
                skippedItems["transactions"] = skipped
            }
        }
        
        // Export CashBalances
        let cashBalanceFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CashBalance")
        if let cashBalances = try? viewContext.fetch(cashBalanceFetch) as? [NSManagedObject] {
            var validBalances: [[String: Any]] = []
            var skipped = 0
            
            for cashBalance in cashBalances {
                var balanceDict: [String: Any] = [:]
                for attribute in cashBalance.entity.attributesByName.keys {
                    if let value = cashBalance.value(forKey: attribute) {
                        if let serialized = convertToSerializable(value) {
                            balanceDict[attribute] = serialized
                        }
                    }
                }
                
                if !balanceDict.isEmpty {
                    validBalances.append(balanceDict)
                } else {
                    skipped += 1
                }
            }
            
            backupData["cashBalances"] = validBalances
            if skipped > 0 {
                skippedItems["cashBalances"] = skipped
            }
        }
        
        // Export Profits
        let profitsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Profit")
        if let profits = try? viewContext.fetch(profitsFetch) as? [NSManagedObject] {
            var validProfits: [[String: Any]] = []
            var skipped = 0
            
            for profit in profits {
                var profitDict: [String: Any] = [:]
                for attribute in profit.entity.attributesByName.keys {
                    if let value = profit.value(forKey: attribute) {
                        if let serialized = convertToSerializable(value) {
                            profitDict[attribute] = serialized
                        }
                    }
                }
                
                if !profitDict.isEmpty {
                    validProfits.append(profitDict)
                } else {
                    skipped += 1
                }
            }
            
            backupData["profits"] = validProfits
            if skipped > 0 {
                skippedItems["profits"] = skipped
            }
        }
        
        // Export CashFlows
        let cashFlowsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CashFlow")
        if let cashFlows = try? viewContext.fetch(cashFlowsFetch) as? [NSManagedObject] {
            var validCashFlows: [[String: Any]] = []
            var skipped = 0
            
            for cashFlow in cashFlows {
                var cashFlowDict: [String: Any] = [:]
                for attribute in cashFlow.entity.attributesByName.keys {
                    if let value = cashFlow.value(forKey: attribute) {
                        if let serialized = convertToSerializable(value) {
                            cashFlowDict[attribute] = serialized
                        }
                    }
                }
                
                if !cashFlowDict.isEmpty {
                    validCashFlows.append(cashFlowDict)
                } else {
                    skipped += 1
                }
            }
            
            backupData["cashFlows"] = validCashFlows
            if skipped > 0 {
                skippedItems["cashFlows"] = skipped
            }
        }
        
        // Add metadata
        backupData["metadata"] = [
            "version": "2.0.3",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "deviceName": UIDevice.current.name,
            "includesPhotos": includePhotos
        ]
        
        // Convert to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                backupDocument = BackupDocument(text: jsonString)
                showingBackupExporter = true
                
                // Show warning if items were skipped
                if !skippedItems.isEmpty {
                    var warningMessage = "Backup created successfully, but some items were skipped due to corruption:\n"
                    for (entity, count) in skippedItems {
                        warningMessage += "\n\(entity): \(count) item(s)"
                    }
                    backupAlertMessage = warningMessage
                    showingBackupAlert = true
                }
            } else {
                throw NSError(domain: "BackupError", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to string"])
            }
        } catch {
            backupAlertMessage = "Failed to create backup: \(error.localizedDescription)"
            showingBackupAlert = true
            print("Backup error: \(error)")
        }
    }
    
    private func convertToSerializable(_ value: Any) -> Any? {
        // Skip NSNull
        if value is NSNull {
            return nil
        }
        
        // Handle dates
        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }
        
        // Handle decimals
        if let decimal = value as? Decimal {
            return String(describing: decimal)
        }
        if let nsDecimal = value as? NSDecimalNumber {
            return String(describing: nsDecimal)
        }
        
        // Handle binary data
        if let data = value as? Data {
            return data.base64EncodedString()
        }
        
        // Handle UUID
        if let uuid = value as? UUID {
            return uuid.uuidString
        }
        
        // Skip Core Data relationships (NSSet, NSOrderedSet)
        if value is NSSet || value is NSOrderedSet {
            return nil
        }
        
        // Handle managed objects (skip to avoid circular references)
        if value is NSManagedObject {
            return nil
        }
        
        // Handle primitive types (String, Int, Bool, Double, etc.)
        // These are already JSON-serializable
        if value is String || value is Int || value is Bool || value is Double || value is Float {
            return value
        }
        
        // If we don't know the type, skip it to be safe
        print("Warning: Skipping unknown type: \(type(of: value))")
        return nil
    }
    
    private func restoreFromBackup(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            backupAlertMessage = "Unable to access the selected file"
            showingBackupAlert = true
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "BackupRestore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backup file format"])
            }
            
            // Clear existing data
            try clearAllData()
            
            // Restore Settings
            if let settingsDict = json["settings"] as? [String: Any] {
                if let ratioString = settingsDict["tradeInCashRatio"] as? String,
                   let ratio = Decimal(string: ratioString) {
                    settings.tradeInCashRatio = ratio
                }
                if let markUnavailable = settingsDict["markCardUnavailableWhenSold"] as? Bool {
                    settings.markCardUnavailableWhenSold = markUnavailable
                }
                if let currency = settingsDict["defaultCurrency"] as? String {
                    settings.defaultCurrency = currency
                }
                if let titleLength = settingsDict["maxCardTitleLength"] as? Int {
                    settings.maxCardTitleLength = titleLength
                }
            }
            
            // Restore Cards
            if let cardsArray = json["cards"] as? [[String: Any]] {
                for cardDict in cardsArray {
                    let card = NSEntityDescription.insertNewObject(forEntityName: "Card", into: viewContext)
                    for (key, value) in cardDict {
                        setValue(value, forKey: key, on: card)
                    }
                }
            }
            
            // Restore Transactions
            if let transactionsArray = json["transactions"] as? [[String: Any]] {
                for transactionDict in transactionsArray {
                    let transaction = NSEntityDescription.insertNewObject(forEntityName: "Transaction", into: viewContext)
                    for (key, value) in transactionDict {
                        setValue(value, forKey: key, on: transaction)
                    }
                }
            }
            
            // Restore CashBalances
            if let cashBalancesArray = json["cashBalances"] as? [[String: Any]] {
                for cashBalanceDict in cashBalancesArray {
                    let cashBalance = NSEntityDescription.insertNewObject(forEntityName: "CashBalance", into: viewContext)
                    for (key, value) in cashBalanceDict {
                        setValue(value, forKey: key, on: cashBalance)
                    }
                }
            }
            
            // Restore Profits
            if let profitsArray = json["profits"] as? [[String: Any]] {
                for profitDict in profitsArray {
                    let profit = NSEntityDescription.insertNewObject(forEntityName: "Profit", into: viewContext)
                    for (key, value) in profitDict {
                        setValue(value, forKey: key, on: profit)
                    }
                }
            }
            
            // Restore CashFlows
            if let cashFlowsArray = json["cashFlows"] as? [[String: Any]] {
                for cashFlowDict in cashFlowsArray {
                    let cashFlow = NSEntityDescription.insertNewObject(forEntityName: "CashFlow", into: viewContext)
                    for (key, value) in cashFlowDict {
                        setValue(value, forKey: key, on: cashFlow)
                    }
                }
            }
            
            // Save context
            try viewContext.save()
            
            // Update UI
            tradeInRatioText = String(describing: settings.tradeInCashRatio)
            
            backupAlertMessage = "Backup restored successfully! All data has been imported."
            showingBackupAlert = true
            
        } catch {
            backupAlertMessage = "Failed to restore backup: \(error.localizedDescription)"
            showingBackupAlert = true
            print("Restore error: \(error)")
        }
    }
    
    private func clearAllData() throws {
        // Clear Cards
        let cardsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Card")
        let cardsDelete = NSBatchDeleteRequest(fetchRequest: cardsFetch)
        try viewContext.execute(cardsDelete)
        
        // Clear Transactions
        let transactionsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Transaction")
        let transactionsDelete = NSBatchDeleteRequest(fetchRequest: transactionsFetch)
        try viewContext.execute(transactionsDelete)
        
        // Clear CashBalances
        let cashBalancesFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CashBalance")
        let cashBalancesDelete = NSBatchDeleteRequest(fetchRequest: cashBalancesFetch)
        try viewContext.execute(cashBalancesDelete)
        
        // Clear Profits
        let profitsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Profit")
        let profitsDelete = NSBatchDeleteRequest(fetchRequest: profitsFetch)
        try viewContext.execute(profitsDelete)
        
        // Clear CashFlows
        let cashFlowsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CashFlow")
        let cashFlowsDelete = NSBatchDeleteRequest(fetchRequest: cashFlowsFetch)
        try viewContext.execute(cashFlowsDelete)
        
        try viewContext.save()
        viewContext.reset()
    }
    
    private func setValue(_ value: Any, forKey key: String, on object: NSManagedObject) {
        guard let attributeType = object.entity.attributesByName[key]?.attributeType else { return }
        
        switch attributeType {
        case .dateAttributeType:
            if let dateString = value as? String,
               let date = ISO8601DateFormatter().date(from: dateString) {
                object.setValue(date, forKey: key)
            }
        case .decimalAttributeType:
            if let decimalString = value as? String,
               let decimal = Decimal(string: decimalString) {
                object.setValue(NSDecimalNumber(decimal: decimal), forKey: key)
            }
        case .binaryDataAttributeType:
            if let base64String = value as? String,
               let data = Data(base64Encoded: base64String) {
                object.setValue(data, forKey: key)
            }
        case .UUIDAttributeType:
            if let uuidString = value as? String,
               let uuid = UUID(uuidString: uuidString) {
                object.setValue(uuid, forKey: key)
            }
        default:
            object.setValue(value, forKey: key)
        }
    }
}

// Document type for file export
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
