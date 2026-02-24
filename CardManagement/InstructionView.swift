import SwiftUI

struct DetailedInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detailed Instructions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    instructionSection(
                        title: "Adding New Cards",
                        content: "1. Navigate to 'Available Cards'\n2. Tap 'Add Card' button\n3. Fill in card details including title, trade-in value, and/or amount paid\n4. Save the card"
                    )
                    
                    instructionSection(
                        title: "Creating Transactions",
                        content: "1. Add the traded in cards follow \"Adding New Cards\" \n2. Go to 'Transactions' section and tap 'Add Transaction'\n3. Select cards you're trading in and out\n4. Enter cash amounts and cost for fees and shippings\n5. Specify platform and trader information\n6. Save the transaction"
                    )
                    
                    instructionSection(
                        title: "Cash Balance and Profit Updates",
                        content: "• Cards selected as traded out in a transaction will be automatically marked as unavailable and will be removed from the 'Available Cards' list\n• Cash balance and profit will be updated automatically with each card transaction added or updated\n• Edit any transaction to update cash balance and profit  retroactively \n• Cash balance will be updated automatically with each cash flow entry added, this is for not card related incomes or spendings"
                    )
                    
                    instructionSection(
                        title: "Backup and Restore",
                        content: "• Go to Settings > Backup & Restore to export your data\n• Tap 'Export App Data' to create a backup file (JSON format)\n• The backup includes all cards, transactions, cash flows, balances, profits, and settings\n• Save the backup file to iCloud Drive or another location\n• To restore, tap 'Restore from Backup' and select your backup file\n• Warning: Restoring will replace ALL current data with the backup data\n• Regular backups are recommended to protect your data"
                    )
                    
                    instructionSection(
                        title: "Tips for Success",
                        content: "•Check the Setting page for different settings available\n• Always add cards before creating transactions\n• Keep accurate records of trade in values and purchase prices\n• Use short and clear card title, it will be used to find the card when adding/updating a transaction\n• Use descriptive notes for future reference"
                    )
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
