import SwiftUI
import CoreData

struct AddCashFlowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    // Only need to grab the last cashBalance
    init() {
        let request: NSFetchRequest<CashBalance> = CashBalance.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CashBalance.pk, ascending: false)]
        _cashBalances = FetchRequest<CashBalance>(fetchRequest: request)
    }
    
    @FetchRequest
    private var cashBalances: FetchedResults<CashBalance>
    
    @State private var changeText: String = ""
    @State private var note: String = ""
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Note")) {
                    TextField("Income source or expense reason", text: $note)
                        .onChange(of: note) { newValue in
                            // Limit note length to prevent excessively long notes
                            if newValue.count > 100 {
                                note = String(newValue.prefix(100))
                            }
                        }
                    if note.count > 90 {
                        Text("\(note.count)/100 characters")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Amount received or spent") {
                    TextField("0.00", text: $changeText)
                        .keyboardType(.numbersAndPunctuation)
                        .onChange(of: changeText) { newValue in
                            // Format the input to ensure valid decimal format
                            changeText = formatDecimalInput(newValue, allowNegative: true)
                        }
                    Text("Use negative values if it's a spending")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(2)
            .navigationTitle(Text("Add Cash Flow"))
            
            Button(action: { addCashFlow() }) {
                Text("Save")
            }
            .disabled(changeText.isEmpty || Decimal(string: changeText) == 0 || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // Helper function to get current balance
    private func getCurrentBalance() -> Decimal {
        return cashBalances.last?.balance as Decimal? ?? Decimal.zero
    }
    
    // Helper function to format currency display
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    // Helper function to format decimal input with negative support
    private func formatDecimalInput(_ input: String, allowNegative: Bool = false) -> String {
        var filtered = input
        
        // Allow negative sign at the beginning if specified
        if allowNegative && filtered.hasPrefix("-") {
            filtered = "-" + String(filtered.dropFirst()).filter { $0.isNumber || $0 == "." }
        } else {
            filtered = filtered.filter { $0.isNumber || $0 == "." }
        }
        
        // Handle negative sign placement
        if allowNegative {
            let negativeCount = filtered.filter { $0 == "-" }.count
            if negativeCount > 1 {
                // Keep only the first negative sign
                let hasLeadingNegative = filtered.hasPrefix("-")
                filtered = filtered.replacingOccurrences(of: "-", with: "")
                if hasLeadingNegative {
                    filtered = "-" + filtered
                }
            } else if negativeCount == 1 && !filtered.hasPrefix("-") {
                // Move negative sign to the beginning
                filtered = "-" + filtered.replacingOccurrences(of: "-", with: "")
            }
        }
        
        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            if filtered.hasPrefix("-") {
                filtered = "-" + components[1] + "." + components[2]
            } else {
                filtered = components[0] + "." + components[1]
            }
        }
        
        // Limit to 2 decimal places
        if components.count == 2 {
            let decimalPart = components[1]
            if decimalPart.count > 2 {
                let integerPart = components[0]
                filtered = integerPart + "." + String(decimalPart.prefix(2))
            }
        }
        
        return filtered
    }
    
    private func addCashFlow() {
        // Validate inputs
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Note is required for cash flow")
            return
        }
        
        guard let changeAmount = Decimal(string: changeText), changeAmount != 0 else {
            print("Invalid or zero change amount")
            return
        }
        
        withAnimation {
            let nowDateTime = Date()
            
            let newCashFlow = CashFlow(context: viewContext)
            newCashFlow.pk = UUID()
            newCashFlow.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            newCashFlow.change = changeAmount as NSDecimalNumber
            newCashFlow.dateTime = nowDateTime
            
            let newEntry = CashBalance(context: viewContext)
            newEntry.change = changeAmount as NSDecimalNumber
            newEntry.note = "Update by Add Cash Flow"
            newEntry.dateTime = nowDateTime
            newEntry.cashFlowPk = newCashFlow.pk
            
            if cashBalances.isEmpty {
                newEntry.pk = 1
                newEntry.balance = changeAmount as NSDecimalNumber
            } else {
                guard let lastEntry = cashBalances.last else {
                    print("Error: Could not get last cash balance entry")
                    return
                }
                newEntry.pk = lastEntry.pk + 1
                let previousBalance = lastEntry.balance as Decimal? ?? Decimal.zero
                let newBalance = previousBalance + changeAmount
                newEntry.balance = newBalance as NSDecimalNumber
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Failed to save cash flow: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
