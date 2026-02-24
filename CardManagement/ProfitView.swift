import SwiftUI
import CoreData
//import Foundation

struct AdjustProfitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    //only need to grab the last profit
    init() {
        let request: NSFetchRequest<Profit> = Profit.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Profit.timestamp, ascending: false)]
        _profits = FetchRequest<Profit>(fetchRequest: request)
    }
    
    @FetchRequest
    private var profits: FetchedResults<Profit>
    
    @State private var note: String = ""
    @State private var change: Decimal = 0
    @State private var changeText: String = ""
    
    // Computed properties for preview calculations
    private var currentTotal: Decimal {
        if profits.isEmpty {
            return 0
        } else {
            return profits.last?.total?.decimalValue ?? 0
        }
    }
    
    private var newTotal: Decimal {
        return currentTotal + change
    }
    
    // Formatters for display
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }
    
    private var currentTotalFormatted: String {
        return numberFormatter.string(from: NSDecimalNumber(decimal: currentTotal)) ?? "$0.00"
    }
    
    private var changeFormatted: String {
        let formattedChange = numberFormatter.string(from: NSDecimalNumber(decimal: change)) ?? "$0.00"
        return change >= 0 ? "+\(formattedChange)" : formattedChange
    }
    
    private var newTotalFormatted: String {
        return numberFormatter.string(from: NSDecimalNumber(decimal: newTotal)) ?? "$0.00"
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Note")) {
                    TextField("Note", text: $note)
                }
                Section("Value changed") {
                    TextField("amount", text: $changeText)
                        .keyboardType(.decimalPad)
                        .onChange(of: changeText) { newValue in
                            // Convert string to Decimal, handling invalid input gracefully
                            if let decimal = Decimal(string: newValue) {
                                change = decimal
                            } else if newValue.isEmpty {
                                change = 0
                            }
                            // If conversion fails, keep previous valid value
                        }
                }
                
                Section("Preview") {
                    HStack {
                        Text("Current Total:")
                        Spacer()
                        Text(currentTotalFormatted)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Change:")
                        Spacer()
                        Text(changeFormatted)
                            .foregroundColor(change >= 0 ? .green : .red)
                    }
                    
                    HStack {
                        Text("New Total:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(newTotalFormatted)
                            .fontWeight(.semibold)
                            .foregroundColor(newTotal >= currentTotal ? .green : .red)
                    }
                }
            }
            .padding(2)
            .navigationTitle(Text("Adjust Profit"))
            
            Button(action: { adjustProfit() }) {
                Text("Save")
            }
            .disabled(changeText.isEmpty || change == 0)
        }
    }
    
    private func adjustProfit() {
        withAnimation {
            let newEntry = Profit(context: viewContext)
            newEntry.change = NSDecimalNumber(decimal: change)
            newEntry.note = note
            newEntry.pk = UUID()
            newEntry.timestamp = Date()
            
            if profits.isEmpty {
                newEntry.total = NSDecimalNumber(decimal: change)
            } else {
                let previousTotal = profits.last?.total ?? NSDecimalNumber.zero
                let previousDecimal = previousTotal.decimalValue
                let newTotal = previousDecimal + change
                newEntry.total = NSDecimalNumber(decimal: newTotal)
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                // Handle the error appropriately in production
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                // Consider showing an alert to the user instead of crashing
            }
        }
    }
}
