import SwiftUI
import CoreData
import PhotosUI
import UIKit
import AVFoundation
import Photos

@available(iOS 16.0, *)
struct EditTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    
    var selectedTransaction: Transaction
    
    init(selectedTransaction: Transaction) {
        self.selectedTransaction = selectedTransaction
        
        let titles = getTitlesFromTitleString(selectedTransaction.cardsOut!)
        let request: NSFetchRequest<Card> = Card.fetchRequest()
        let predicate1 = NSPredicate(format: "title IN %@", titles)
        let predicate2 = NSPredicate(format: "available == %@", NSNumber(value:true))
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate1, predicate2])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Card.timestamp, ascending: false)]
        request.propertiesToFetch = [
            "id", "title", "available", "currentValue", "dateAdded",
            "dateSold", "note", "paid", "sold",
            "timestamp", "tradeInValue", "tradeOutValue"
        ]
        _existingCards = FetchRequest<Card>(fetchRequest: request)
        
        let request1: NSFetchRequest<Profit> = Profit.fetchRequest()
        request1.fetchLimit = 1;
        request1.sortDescriptors = [NSSortDescriptor(keyPath: \Profit.timestamp, ascending: false)]
        _profits = FetchRequest<Profit>(fetchRequest: request1)
        
        let request2: NSFetchRequest<CashBalance> = CashBalance.fetchRequest()
        request2.fetchLimit = 1;
        request2.sortDescriptors = [NSSortDescriptor(keyPath: \CashBalance.pk, ascending: false)]
        _cashBalances = FetchRequest<CashBalance>(fetchRequest: request2)
        
        let request3: NSFetchRequest<Profit> = Profit.fetchRequest()
        request3.predicate = NSPredicate(format: "transactionPk == %@", selectedTransaction.pk! as CVarArg)
        request3.sortDescriptors = []
        _transactionProfit = FetchRequest<Profit>(fetchRequest: request3)
        
        let request4: NSFetchRequest<CashBalance> = CashBalance.fetchRequest()
        request4.predicate = NSPredicate(format: "transactionPk == %@", selectedTransaction.pk! as CVarArg)
        request4.sortDescriptors = []
        _transactionCashBalance = FetchRequest<CashBalance>(fetchRequest: request4)
        
        let request5: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request5.predicate = NSPredicate(format: "pk == %@", selectedTransaction.pk! as CVarArg)
        request5.sortDescriptors = []
        _existingTransaction = FetchRequest<Transaction>(fetchRequest: request5)
        
        platform = selectedTransaction.platform ?? defaultPlatform
        platformId = selectedTransaction.platformId ?? defaultPlatformId
        cashInText = selectedTransaction.cashIn?.description ?? defaultCashInText
        cashOutText = selectedTransaction.cashOut?.description ?? defaultCashOutText
        feesAndShippingText = selectedTransaction.feesAndShipping?.description ?? defaultFeesAndShippingText
        dateTime = selectedTransaction.dateTime ?? defaultDateTime
        tradeInCards = defaultTradeInCards
        tradeOutCards = defaultTradeOutCards
    }
    
    @FetchRequest
    private var cashBalances: FetchedResults<CashBalance>
    
    @FetchRequest
    private var existingCards: FetchedResults<Card>
    
    @FetchRequest
    private var profits: FetchedResults<Profit>
    
    @FetchRequest
    private var transactionCashBalance: FetchedResults<CashBalance>
    
    @FetchRequest
    private var transactionProfit: FetchedResults<Profit>
    
    @FetchRequest
    private var existingTransaction: FetchedResults<Transaction>
    
    @State private var platform: String = ""
    @State private var platformId: String = ""
    @State private var cashInText = ""
    @State private var cashOutText = ""
    @State private var feesAndShippingText = ""
    @State private var dateTime: Date
    @State private var tradeInCards: Set<Card>
    @State private var tradeOutCards: Set<Card>
    
    private var defaultPlatform: String = ""
    private var defaultPlatformId: String = ""
    private var defaultCashInText = "0.00"
    private var defaultCashOutText = "0.00"
    private var defaultFeesAndShippingText = "0.00"
    private var defaultDateTime: Date = Date.distantPast
    private var defaultTradeInCards: Set<Card> = []
    private var defaultTradeOutCards: Set<Card> = []
    
    @State private var oldTradeOutList: Set<Card> = []
    @State private var isDateTimeChanged = false
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var transactionImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showPhotoPermissionAlert = false
    @State private var showCameraPermissionAlert = false
    
    var body: some View {
        VStack{
            Form {
                Section("When trade happened"){
                    DatePicker("When", selection: $dateTime, displayedComponents: [.date])
                        .onChange(of: dateTime) { newValue in
                            if newValue != Date.distantPast {
                                isDateTimeChanged = true
                            } else {
                                isDateTimeChanged = false
                            }
                        }
                }
                // Photo Section
                Section("Transaction Photo") {
                    if let transactionImage = transactionImage {
                        Image(uiImage: transactionImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Button("Remove Photo") {
                            self.transactionImage = nil
                            selectedPhoto = nil
                        }
                        .foregroundColor(.red)
                    }
                    HStack{
                        Button(action: { checkPhotoPermission() }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photo")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .sheet(isPresented: $showPhotoLibrary) {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images,
                                photoLibrary: .shared()) {
                                    Text("Select a photo")
                                }
                                .presentationDetents([.large])
                        }
                            
                        Button(action: { checkCameraPermission() }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Camera")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                Section("Cards traded in") {
                    MultiSelectDropdown(
                        placeholder: "Select cards...",
                        items: existingCards,
                        selectedValues: $tradeInCards
                    )
                }
                Section("Cards traded out") {
                    MultiSelectDropdown(
                        placeholder: "Select cards...",
                        items: existingCards,
                        selectedValues: $tradeOutCards
                    )
                }
                Section("Cash received") {
                    TextField("Cash in", text: $cashInText).keyboardType(.decimalPad)
                }
                Section("Cash spent") {
                    TextField("Cash out", text: $cashOutText).keyboardType(.decimalPad)
                }
                Section("Fees and shipping cost") {
                    TextField("cost", text: $feesAndShippingText).keyboardType(.decimalPad)
                }
                Section(header: Text("This trade happened at")) {
                    TextField("Platform name", text: $platform)
                }
                Section(header: Text("You trade with")) {
                    TextField("PlatformId", text: $platformId)
                }
            }
            .padding()
            .navigationTitle(Text("Edit"))
            HStack {
                Button(action: {dismiss()}) {
                    Text("Cancel")
                }.foregroundColor(.red)
                    .buttonStyle(BorderlessButtonStyle())
                Spacer()
                Button(action: {updateTransaction()}) {
                    Text("Save")
                }.foregroundColor(.blue)
                    .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 1, x: 0, y: -1)
        }.onAppear{
            loadPhotoData()
            tradeInCards = getCardsFromTitleString(selectedTransaction.cardsIn!, from: existingCards)
            tradeOutCards = getCardsFromTitleString(selectedTransaction.cardsOut!, from: existingCards)
            oldTradeOutList = tradeOutCards
        }
        .onChange(of: selectedPhoto) { newValue in
            Task {
                await loadSelectedPhoto()
                showCamera = false
                showPhotoLibrary = false
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let resizedImage = image.resizedToMaxDimension(800) {
                    transactionImage = resizedImage
                }
                showCamera = false
            }
        }
        .alert("Photo Library Access", isPresented: $showPhotoPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo library access in Settings to select photos.")
        }
        .alert("Camera Access", isPresented: $showCameraPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to take photos.")
        }
    }
    
    private func loadPhotoData() {
        // This triggers the fault and loads the photoData from Core Data
        // Access the property to force it to load from the database
        if let imageData = selectedTransaction.photoData {
            transactionImage = UIImage(data: imageData)
        }
    }
    
    private func loadSelectedPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Resize image to max 800px dimension to save space
                transactionImage = image.resizedToMaxDimension(800)
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    private func checkCameraPermission() {
        CameraPermissionManager.checkCameraPermission(
            onAuthorized: {
                showCamera = true
            },
            onDenied: {
                showCameraPermissionAlert = true
            }
        )
    }
    
    private func checkPhotoPermission() {
        CameraPermissionManager.checkPhotoLibraryPermission(
            onAuthorized: {
                showPhotoLibrary = true
            },
            onDenied: {
                showPhotoPermissionAlert = true
            }
        )
    }
    
    private func updateTransaction() {
        withAnimation {
            // Get the existing transaction
            guard let existingItem = existingTransaction.first else { return }
            
            // Update dateTime
            if !isDateTimeChanged && existingItem.dateTime == nil {
                // Do nothing
            } else {
                existingItem.dateTime = dateTime
            }
            
            // Handle cash in changes
            var cashInChanged = Decimal.zero
            let cashIn = Decimal(string: cashInText) ?? Decimal.zero
            
            if cashInText == defaultCashInText && existingItem.cashIn == nil {
                // Do nothing
            } else if cashIn > 0 {
                let oldCashIn = existingItem.cashIn as Decimal? ?? Decimal.zero
                cashInChanged = cashIn - oldCashIn
                existingItem.cashIn = cashIn as NSDecimalNumber
            }
            
            // Handle cash out changes
            var cashOutChanged = Decimal.zero
            let cashOut = Decimal(string: cashOutText) ?? Decimal.zero
            
            if cashOutText == defaultCashOutText && existingItem.cashOut == nil {
                // Do nothing
            } else if cashOut > 0 {
                let oldCashOut = existingItem.cashOut as Decimal? ?? Decimal.zero
                cashOutChanged = cashOut - oldCashOut
                existingItem.cashOut = cashOut as NSDecimalNumber
            }
            
            // Handle fees and shipping changes
            var feesAndShippingChanged = Decimal.zero
            let feesAndShipping = Decimal(string: feesAndShippingText) ?? Decimal.zero
            
            if feesAndShippingText == defaultFeesAndShippingText && existingItem.feesAndShipping == nil {
                // Do nothing
            } else if feesAndShipping > 0 {
                let oldFeesAndShipping = existingItem.feesAndShipping as Decimal? ?? Decimal.zero
                feesAndShippingChanged = feesAndShipping - oldFeesAndShipping
                existingItem.feesAndShipping = feesAndShipping as NSDecimalNumber
            }
            
            // Update platform
            if platform == defaultPlatform && existingItem.platform == nil {
                // Do nothing
            } else if !platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existingItem.platform = platform
            }
            
            // Update platform ID
            if platformId == defaultPlatformId && existingItem.platformId == nil {
                // Do nothing
            } else if !platformId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existingItem.platformId = platformId
            }
            
            // Update cards
            existingItem.cardsIn = tradeInCards.compactMap { $0.title }.joined(separator: ", ")
            existingItem.cardsOut = tradeOutCards.compactMap { $0.title }.joined(separator: ", ")
            
            // Calculate profit
            let cardsInValue = calculateTotalTradeInValueAndCashValue(cards: tradeInCards, settings: settings)
            let cardsOutValue = calculateTotalTradeInValueAndCashValue(cards: tradeOutCards, settings: settings)
            let profitValue = cardsInValue - cardsOutValue + cashIn - cashOut - feesAndShipping
            
            let oldProfit = existingItem.profit as Decimal? ?? Decimal.zero
            let profitChanged = profitValue - oldProfit
            existingItem.profit = profitValue as NSDecimalNumber
            
            // Update transaction image
            if let image = transactionImage {
                existingItem.photoData = image.jpegData(compressionQuality: 0.03)
            } else {
                existingItem.photoData = nil
            }
            
            let nowDateTime = Date()
            
            // Add profit entry with changed value
            if profitChanged != Decimal.zero {
                let newProfit = Profit(context: viewContext)
                newProfit.pk = UUID()
                newProfit.timestamp = nowDateTime
                newProfit.change = profitChanged as NSDecimalNumber
                
                if profits.isEmpty {
                    newProfit.total = profitValue as NSDecimalNumber
                } else {
                    let lastProfitTotal = profits.last?.total as Decimal? ?? Decimal.zero
                    newProfit.total = (lastProfitTotal + profitChanged) as NSDecimalNumber
                }
                newProfit.transactionPk = existingItem.pk
                newProfit.note = "Created by Edit Card Transaction"
            }
            
            // Adjust cash balance with updated values
            let change = cashInChanged - cashOutChanged - feesAndShippingChanged
            if change != Decimal.zero {
                let newCashBalance = CashBalance(context: viewContext)
                newCashBalance.change = change as NSDecimalNumber
                
                if cashBalances.isEmpty {
                    newCashBalance.pk = 1
                    newCashBalance.balance = change as NSDecimalNumber
                } else {
                    let lastBalance = cashBalances.last?.balance as Decimal? ?? Decimal.zero
                    newCashBalance.pk = (cashBalances.last?.pk ?? 0) + 1
                    newCashBalance.balance = (lastBalance + change) as NSDecimalNumber
                }
                newCashBalance.transactionPk = existingItem.pk
                newCashBalance.dateTime = nowDateTime
                newCashBalance.note = "Created by Edit Transaction"
            }
            
            if settings.markCardUnavailableWhenSold {
                let cardsNoLongerTradeOut = oldTradeOutList.subtracting(tradeOutCards)
                cardsNoLongerTradeOut.forEach { card in
                    if !card.available {
                        card.available = true
                    }
                }
                let newTradedOutCards = tradeOutCards.subtracting(oldTradeOutList)
                newTradedOutCards.forEach { card in
                    if card.available {
                        card.available = false
                    }
                }
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

class MultiSelectViewModel: ObservableObject {
    @Published var items: [Card] = []
    @Published var selectedItems: Set<Card> = []
    @Published var isExpanded: Bool = false
    
    var selecteTitles: String {
        selectedItems.map{$0.title!}.joined(separator: ",")
    }
}

func getTitlesFromTitleString(_ titleString: String) -> [String] {
    return titleString.split(separator: ",")
        .map{$0.trimmingCharacters(in: .whitespaces)}
}

func getCardsFromTitleString(_ titleString: String, from fetchedCards: FetchedResults<Card>) -> Set<Card> {
    let titles = getTitlesFromTitleString(titleString)
    let matchingCards = fetchedCards.filter { card in
        guard let cardTitle = card.title else {return false}
        return titles.contains(cardTitle)
    }
    return Set(matchingCards)
}

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func resizedToMaxDimension(_ maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        return resized(to: newSize)
    }
}



@available(iOS 16.0, *)
struct AddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    
    init() {
        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.predicate = NSPredicate(format: "available == %@", NSNumber(value:true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Card.timestamp, ascending: false)]
        request.propertiesToFetch = [
            "id", "title", "available", "currentValue", "dateAdded",
            "dateSold", "note", "paid", "sold",
            "timestamp", "tradeInValue", "tradeOutValue"
        ]
        _existingCards = FetchRequest<Card>(fetchRequest: request)
        
        let request1: NSFetchRequest<Profit> = Profit.fetchRequest()
        request1.fetchLimit = 1;
        request1.sortDescriptors = [NSSortDescriptor(keyPath: \Profit.timestamp, ascending: false)]
        _profits = FetchRequest<Profit>(fetchRequest: request1)
        
        let request2: NSFetchRequest<CashBalance> = CashBalance.fetchRequest()
        request2.fetchLimit = 1;
        request2.sortDescriptors = [NSSortDescriptor(keyPath: \CashBalance.pk, ascending: false)]
        _cashBalances = FetchRequest<CashBalance>(fetchRequest: request2)
    }
    
    @FetchRequest
    private var cashBalances: FetchedResults<CashBalance>
    
    @FetchRequest
    private var existingCards: FetchedResults<Card>
    
    @FetchRequest
    private var profits: FetchedResults<Profit>
    
    @State private var platform: String = ""
    @State private var platformId: String = ""
    @State private var cashInText = "0.00"
    @State private var cashOutText = "0.00"
    @State private var feesAndShippingText = "0.00"
    @State private var dateTime: Date = Date()
    @State private var tradeInCards: Set<Card> = []
    @State private var tradeOutCards: Set<Card> = []
    
    // Photo-related properties
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var transactionImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showPhotoPermissionAlert = false
    @State private var showCameraPermissionAlert = false
    
    @available(iOS 16.0, *)
    var body: some View {
        VStack{
            Form {
                Section("When trade happened"){
                    DatePicker("When", selection: $dateTime, displayedComponents: [.date])
                }
                
                Section("Cards traded in") {
                    MultiSelectDropdown(
                        placeholder: "Select cards...",
                        items: existingCards,
                        selectedValues: $tradeInCards
                    )
                }
                Section("Cards traded out") {
                    MultiSelectDropdown(
                        placeholder: "Select cards...",
                        items: existingCards,
                        selectedValues: $tradeOutCards
                    )
                }
                Section("Cash received") {
                    TextField("Cash in", text: $cashInText).keyboardType(.decimalPad)
                }
                Section("Cash spent") {
                    TextField("Cash out", text: $cashOutText).keyboardType(.decimalPad)
                }
                Section("Fees and shipping cost") {
                    TextField("cost", text: $feesAndShippingText).keyboardType(.decimalPad)
                }
                Section(header: Text("This trade happened at")) {
                    TextField("Platform name", text: $platform)
                }
                Section(header: Text("You trade with")) {
                    TextField("PlatformId", text: $platformId)
                }
                // Photo Section
                Section("Transaction Photo") {
                    if let transactionImage = transactionImage {
                        Image(uiImage: transactionImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Button("Remove Photo") {
                            self.transactionImage = nil
                            selectedPhoto = nil
                        }
                        .foregroundColor(.red)
                    }
                    HStack{
                        Button(action: { checkPhotoPermission() }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photo")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .sheet(isPresented: $showPhotoLibrary) {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images,
                                photoLibrary: .shared()) {
                                    Text("Select a photo")
                                }
                                .presentationDetents([.large])
                        }
                            
                        Button(action: { checkCameraPermission() }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Camera")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding()
            .navigationTitle(Text("Add a new Transaction"))
            Button(action: {addTransaction()}) {
                Text("Save")
            }
        }
        .onChange(of: selectedPhoto) { newValue in
            Task {
                showCamera = false
                showPhotoLibrary = false
                await loadSelectedPhoto()
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let resizedImage = image.resizedToMaxDimension(800) {
                    transactionImage = resizedImage
                }
                showCamera = false
            }
        }
        .alert("Photo Library Access", isPresented: $showPhotoPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo library access in Settings to select photos.")
        }
        .alert("Camera Access", isPresented: $showCameraPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to take photos.")
        }
    }
    
    private func addTransaction() {
        withAnimation {
            // First add a new transaction
            let newItem = Transaction(context: viewContext)
            newItem.pk = UUID()
            newItem.dateTime = dateTime
            // Save photo if available
            if let transactionImage = transactionImage,
               let imageData = transactionImage.jpegData(compressionQuality: 0.03) {
                newItem.photoData = imageData
            }
            // Handle cash in with safe unwrapping
            let cashIn = Decimal(string: cashInText) ?? Decimal.zero
            if cashIn > 0 {
                newItem.cashIn = cashIn as NSDecimalNumber
            }
            
            // Handle cash out with safe unwrapping
            let cashOut = Decimal(string: cashOutText) ?? Decimal.zero
            if cashOut > 0 {
                newItem.cashOut = cashOut as NSDecimalNumber
            }
            
            // Set platform info
            newItem.platform = platform.isEmpty ? nil : platform
            newItem.platformId = platformId.isEmpty ? nil : platformId
            
            // Handle fees and shipping with safe unwrapping
            let feesAndShipping = Decimal(string: feesAndShippingText) ?? Decimal.zero
            if feesAndShipping > 0 {
                newItem.feesAndShipping = feesAndShipping as NSDecimalNumber
            }
            
            // Set card info
            newItem.cardsIn = tradeInCards.compactMap { $0.title }.joined(separator: ", ")
            newItem.cardsOut = tradeOutCards.compactMap { $0.title }.joined(separator: ", ")
            
            // Calculate profit
            let cardsInValue = calculateTotalTradeInValueAndCashValue(cards: tradeInCards, settings: settings)
            let cardsOutValue = calculateTotalTradeInValueAndCashValue(cards: tradeOutCards, settings: settings)
            let profitValue = cardsInValue - cardsOutValue + cashIn - cashOut - feesAndShipping
            
            newItem.profit = profitValue as NSDecimalNumber
            
            let nowDateTime = Date()
            
            // Add a profit entry if there is any profit
            if profitValue != Decimal.zero {
                let newProfit = Profit(context: viewContext)
                newProfit.pk = UUID()
                newProfit.timestamp = nowDateTime
                newProfit.change = profitValue as NSDecimalNumber
                
                if profits.isEmpty {
                    newProfit.total = profitValue as NSDecimalNumber
                } else {
                    // Safe unwrapping of Core Data properties
                    let lastTotal = profits.last?.total as Decimal? ?? Decimal.zero
                    newProfit.total = (lastTotal + profitValue) as NSDecimalNumber
                }
                newProfit.transactionPk = newItem.pk
                newProfit.note = "Created by Add Card Transaction"
            }
            
            // Adjust cash balance if any cash change
            let change = cashIn - cashOut - feesAndShipping
            if change != Decimal.zero {
                let newCashBalance = CashBalance(context: viewContext)
                newCashBalance.change = change as NSDecimalNumber
                
                if cashBalances.isEmpty {
                    newCashBalance.pk = 1
                    newCashBalance.balance = change as NSDecimalNumber
                } else {
                    // Safe unwrapping of Core Data properties
                    let lastBalance = cashBalances.last?.balance as Decimal? ?? Decimal.zero
                    let lastPk = cashBalances.last?.pk ?? 0
                    newCashBalance.pk = lastPk + 1
                    newCashBalance.balance = (lastBalance + change) as NSDecimalNumber
                }
                newCashBalance.transactionPk = newItem.pk
                newCashBalance.dateTime = nowDateTime
                newCashBalance.note = "Created by Add Card Transaction"
            }
            
            if settings.markCardUnavailableWhenSold {
                tradeOutCards.forEach { card in
                    if card.available {
                        card.available = false
                    }
                }
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Failed to save transaction: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    private func loadSelectedPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Resize image to max 800px dimension to save space
                transactionImage = image.resizedToMaxDimension(800)
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }

    private func checkCameraPermission() {
        CameraPermissionManager.checkCameraPermission(
            onAuthorized: {
                showCamera = true
            },
            onDenied: {
                showCameraPermissionAlert = true
            }
        )
    }
    
    private func checkPhotoPermission() {
        CameraPermissionManager.checkPhotoLibraryPermission(
            onAuthorized: {
                showPhotoLibrary = true
            },
            onDenied: {
                showPhotoPermissionAlert = true
            }
        )
    }
}

func calculateTotalTradeInValueAndCashValue(cards: Set<Card>, settings: AppSettings) -> Decimal {
    return cards.reduce(Decimal.zero) {total, card in
        let tradeValue = ((card.tradeInValue ?? 0.00) as Decimal) * settings.tradeInCashRatio
        let cashValue = card.paid as Decimal? ?? Decimal.zero
        return (total + tradeValue + cashValue) as Decimal
    }
}

struct MultiSelectDropdown: View {
    @StateObject private var viewModel = MultiSelectViewModel()
    let placeholder: String
    let items: FetchedResults<Card>
    @Binding var selectedValues: Set<Card>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            //dropdown trigger button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selectedValues.isEmpty ? placeholder : "\(selectedValues.count) selected")
                        .foregroundColor(selectedValues.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            //dropdown list
            if viewModel.isExpanded {
                VStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        MultiSelectRow(
                            title: item.title!,
                            isSelected: selectedValues.contains(item)
                        ) { isSelected in
                            if isSelected {
                                selectedValues.insert(item)
                            } else {
                                selectedValues.remove(item)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 5, x:0, y:2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.cameraDevice = .rear
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        
        init(onImageCaptured: @escaping (UIImage) -> Void) {
            self.onImageCaptured = onImageCaptured
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        }
    }
}
struct MultiSelectRow: View {
    let title: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
    }
}
