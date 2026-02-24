import SwiftUI
import CoreData
import PhotosUI
import UIKit
import AVFoundation
import Photos

@available(iOS 16.0, *)
struct EditCardView: View {
    var selectedCard: Card
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @State private var tradeInValueText: String = ""
    @State private var tradeOutValueText: String = ""
    @State private var currentValueText: String = ""
    @State private var paidText: String = ""
    @State private var soldText: String = ""
    @State private var dateAdded: Date
    @State private var dateSold: Date
    @State private var note: String = ""
    @State private var available: Bool
    
    private var defaultTradeInValue = "0.00"
    private var defaultTradeOutValue = "0.00"
    private var defaultCurrentValue = "0.00"
    private var defaultPaid = "0.00"
    private var defaultSold = "0.00"
    private var defaultdDateAdded = Date()
    private var defaultDateSold = Date()
    private var defaultNote: String = "No description"
    private var defaultaAvailable = true
    
    @State private var isDateAddedChanged = false
    @State private var isDateSoldChanged = false
    
    // Photo-related properties
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cardImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showPhotoPermissionAlert = false
    @State private var showCameraPermissionAlert = false
    
    init(selectedCard:Card) {
        self.selectedCard = selectedCard
        available = selectedCard.available
        currentValueText = selectedCard.currentValue?.description ?? defaultCurrentValue
        note = selectedCard.note ?? defaultNote
        tradeInValueText = selectedCard.tradeInValue?.description ?? defaultTradeInValue
        tradeOutValueText = selectedCard.tradeOutValue?.description ?? defaultTradeOutValue
        dateAdded = selectedCard.dateAdded ?? defaultdDateAdded
        paidText = selectedCard.paid?.description ?? defaultPaid
        soldText = selectedCard.sold?.description ?? defaultSold
        dateSold = selectedCard.dateSold ?? defaultDateSold
        
        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.fetchLimit = 1;
        request.predicate = NSPredicate(format: "id == %@", selectedCard.id! as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Card.timestamp, ascending: false)]
        _existingCards = FetchRequest<Card>(fetchRequest: request)
    }
    
    @FetchRequest
    private var existingCards: FetchedResults<Card>
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Text("\(selectedCard.title ?? "")").bold()
                Section(header: Text("Card Details")) {
                    TextField("Description", text: $note)
                }
                Section(header: Text("Available")) {
                    Picker("Still own this card", selection: $available) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                }
                // Photo Section
                Section("Card Photo") {
                    if let cardImage = cardImage {
                        Image(uiImage: cardImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Button("Remove Photo") {
                            self.cardImage = nil
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
                
                Section("Trade In Value") {
                    TextField("value", text: $tradeInValueText).keyboardType(.decimalPad)
                }
                
                Section("Cash Paid") {
                    TextField("amount", text: $paidText).keyboardType(.decimalPad)
                }
                
                Section("Trade Out Value") {
                    TextField("value", text: $tradeOutValueText).keyboardType(.decimalPad)
                }
                
                Section("Sold for cash") {
                    TextField("amount", text: $soldText).keyboardType(.decimalPad)
                }
                
                Section("Current Value") {
                    TextField("value", text: $currentValueText).keyboardType(.decimalPad)
                }
                
                Section("When this card added") {
                    DatePicker("When", selection: $dateAdded, displayedComponents: [.date])
                        .onChange(of: dateAdded) { newValue in
                            isDateAddedChanged = true
                        }
                }
                
                Section("When this card sold") {
                    DatePicker("When", selection: $dateSold, displayedComponents: [.date])
                        .onChange(of: dateSold) { newValue in
                            isDateSoldChanged = true
                        }
                }
            }
            
            // Fixed button bar at bottom
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button(action: { updateCard() }) {
                    Text("Save")
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 1, x: 0, y: -1)
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPhotoData()
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
                    cardImage = resizedImage
                }
                showCamera = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        .interactiveDismissDisabled(true)
    }
    
    private func loadPhotoData() {
        // This triggers the fault and loads the photoData from Core Data
        // Access the property to force it to load from the database
        if let imageData = selectedCard.photoData {
            cardImage = UIImage(data: imageData)
        }
    }
    
    private func updateCard() {
        withAnimation {
            // Use guard for better error handling and early return
            guard let cardToUpdate = existingCards.first else {
                print("No card found to update")
                return
            }
            
            // Update timestamp
            cardToUpdate.timestamp = Date()
            
            // Update note with cleaner logic
            if note == defaultNote && cardToUpdate.note == nil {
                // Do nothing - keep as nil
            } else if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cardToUpdate.note = nil
            } else {
                cardToUpdate.note = note
            }
            
            // Update availability
            cardToUpdate.available = available
            
            // Update trade in value
            if tradeInValueText == defaultTradeInValue && cardToUpdate.tradeInValue == nil {
                // Keep as nil
            } else if let decimal = Decimal(string: tradeInValueText) {
                cardToUpdate.tradeInValue = decimal as NSDecimalNumber
            } else if tradeInValueText.isEmpty {
                cardToUpdate.tradeInValue = nil
            }
            
            // Update trade out value
            if tradeOutValueText == defaultTradeOutValue && cardToUpdate.tradeOutValue == nil {
                // Keep as nil
            } else if let decimal = Decimal(string: tradeOutValueText) {
                cardToUpdate.tradeOutValue = decimal as NSDecimalNumber
            } else if tradeOutValueText.isEmpty {
                cardToUpdate.tradeOutValue = nil
            }
            
            // Update current value
            if currentValueText == defaultCurrentValue && cardToUpdate.currentValue == nil {
                // Keep as nil
            } else if let decimal = Decimal(string: currentValueText) {
                cardToUpdate.currentValue = decimal as NSDecimalNumber
            } else if currentValueText.isEmpty {
                cardToUpdate.currentValue = nil
            }
            
            // Update paid amount
            if paidText == defaultPaid && cardToUpdate.paid == nil {
                // Keep as nil
            } else if let decimal = Decimal(string: paidText) {
                cardToUpdate.paid = decimal as NSDecimalNumber
            } else if paidText.isEmpty {
                cardToUpdate.paid = nil
            }
            
            // Update sold amount
            if soldText == defaultSold && cardToUpdate.sold == nil {
                // Keep as nil
            } else if let decimal = Decimal(string: soldText) {
                cardToUpdate.sold = decimal as NSDecimalNumber
            } else if soldText.isEmpty {
                cardToUpdate.sold = nil
            }
            
            // Update dates if they were changed
            if isDateAddedChanged {
                cardToUpdate.dateAdded = dateAdded
            }
            
            if isDateSoldChanged {
                cardToUpdate.dateSold = dateSold
            }
            
            // Update card image
            if let image = cardImage {
                cardToUpdate.photoData = image.jpegData(compressionQuality: 0.03)
            } else {
                cardToUpdate.photoData = nil
            }
            
            // Save changes
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Failed to update card: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    private func loadSelectedPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                cardImage = image.resizedToMaxDimension(800)
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

@available(iOS 16.0, *)
struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    
    @State private var title: String = ""
    @State private var tradeInValueText: String = ""
    @State private var paidText: String = ""
    @State private var timestamp: Date = Date()
    @State private var dateAdded: Date = Date()
    @State private var note: String = ""
    // Photo-related properties
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cardImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showPhotoPermissionAlert = false
    @State private var showCameraPermissionAlert = false
    
    // Custom decimal formatter for better display
    private var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Card Title")) {
                    TextField("Title", text: $title)
                        .onChange(of: title) { newValue in
                            // Limit title to 50 characters
                            if newValue.count > settings.maxCardTitleLength {
                                title = String(newValue.prefix(settings.maxCardTitleLength))
                            }
                        }
                    Text("\(title.count)/\(settings.maxCardTitleLength) characters")
                        .font(.caption)
                        .foregroundColor(title.count > settings.maxCardTitleLength - 2 ? .orange : .gray)
                }
                Section(header: Text("Card Details")) {
                    TextField("Description", text: $note)
                }
                Section("Trade In Value") {
                    TextField("0.00", text: $tradeInValueText)
                        .keyboardType(.decimalPad)
                        .onChange(of: tradeInValueText) { newValue in
                            // Format the input to ensure valid decimal format
                            tradeInValueText = formatDecimalInput(newValue)
                        }
                }
                Section("Cash Paid") {
                    TextField("0.00", text: $paidText)
                        .keyboardType(.decimalPad)
                        .onChange(of: paidText) { newValue in
                            // Format the input to ensure valid decimal format
                            paidText = formatDecimalInput(newValue)
                        }
                }
                Section("When did you get it") {
                    DatePicker("Date", selection: $dateAdded, displayedComponents: [.date])
                }
                // Photo Section
                Section("Card Photo") {
                    if let cardImage = cardImage {
                        Image(uiImage: cardImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Button("Remove Photo") {
                            self.cardImage = nil
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
            .padding(2)
            .navigationTitle(Text("Add a new Card"))
            
            Button(action: { addCard() }) {
                Text("Save")
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    cardImage = resizedImage
                }
                showCamera = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
    
    // Helper function to format decimal input
    private func formatDecimalInput(_ input: String) -> String {
        // Remove any non-numeric characters except decimal point
        let filtered = input.filter { $0.isNumber || $0 == "." }
        
        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            return components[0] + "." + components[1]
        }
        
        // Limit to 2 decimal places
        if components.count == 2 && components[1].count > 2 {
            return components[0] + "." + String(components[1].prefix(2))
        }
        
        return filtered
    }
    
    private func loadSelectedPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Resize image to max 800px dimension to save space
                cardImage = image.resizedToMaxDimension(800)
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
    
    private func addCard() {
        // Validate required fields
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Title is required")
            return
        }
        
        withAnimation {
            let newCard = Card(context: viewContext)
            newCard.id = UUID()
            newCard.timestamp = Date()
            
            // Convert string inputs to Decimal safely
            let tradeInValue = Decimal(string: tradeInValueText) ?? Decimal.zero
            let paidValue = Decimal(string: paidText) ?? Decimal.zero
            
            // Only set values if they're greater than zero
            if tradeInValue > 0 {
                newCard.tradeInValue = tradeInValue as NSDecimalNumber
                // Set current value to trade in value initially
                newCard.currentValue = tradeInValue as NSDecimalNumber
            } else {
                newCard.tradeInValue = nil
                newCard.currentValue = nil
            }
            
            if paidValue > 0 {
                newCard.paid = paidValue as NSDecimalNumber
                if newCard.currentValue == nil {
                    newCard.currentValue = paidValue as NSDecimalNumber
                }
            } else {
                newCard.paid = nil
            }
            
            // Set other properties
            newCard.tradeOutValue = nil
            newCard.sold = nil
            newCard.available = true
            newCard.dateSold = nil
            newCard.dateAdded = dateAdded
            newCard.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Only set note if it's not empty
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            newCard.note = trimmedNote.isEmpty ? nil : trimmedNote
            
            // Save photo if available
            if let cardImage = cardImage,
               let imageData = cardImage.jpegData(compressionQuality: 0.03) {
                newCard.photoData = imageData
            }
            do {
                try viewContext.save()
                dismiss()
            } catch {
                // Better error handling for production
                let nsError = error as NSError
                print("Failed to save card: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
