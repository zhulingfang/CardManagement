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
                        content: "1. Navigate to 'Available Cards'\n2. Tap 'Add Card'\n3. Fill in the card details, including the title, trade-in value, and/or amount paid\n4. Optionally select an existing photo or take a new one\n5. Tap 'Save'"
                    )
                    
                    instructionSection(
                        title: "Creating Transactions",
                        content: "1. Add traded-in cards by following 'Adding New Cards'\n2. Go to 'Transactions' and tap 'Add Transaction'\n3. Select the cards you're trading in and out\n4. Enter cash amounts, fees, and shipping costs\n5. Specify the platform and trader information\n6. Optionally select an existing photo or take a new one\n7. Tap 'Save'"
                    )

                    instructionSection(
                        title: "Card and Transaction Photos",
                        content: "• Photos are saved in your iOS Photo Library; the app stores a reference to each photo\n• Allow Photo Library access when prompted so the app can save and display photos\n• Photos taken with the camera are added to your Photo Library when you save the card or transaction\n• Removing a photo from a card or transaction removes only the app's reference—it does not delete the photo from your Photo Library\n• If a referenced photo is deleted, unavailable, or belongs to another device, the app displays a Photo Unavailable message; the rest of the card or transaction remains usable"
                    )
                    
                    instructionSection(
                        title: "Cash Balance and Profit Updates",
                        content: "• Cards selected as traded out in a transaction will be automatically marked as unavailable and will be removed from the 'Available Cards' list\n• Cash balance and profit will be updated automatically with each card transaction added or updated\n• Edit any transaction to update cash balance and profit  retroactively \n• Cash balance will be updated automatically with each cash flow entry added, this is for not card related incomes or spendings"
                    )
                    
                    instructionSection(
                        title: "Backup and Restore",
                        content: "• Go to Settings > Backup & Restore to export your data as a JSON file\n• 'Export App Data (with Photos)' includes copies of referenced card and transaction photos; this produces a larger backup\n• 'Export App Data (without Photos)' includes records and settings but excludes photos and photo references\n• Save the backup file to iCloud Drive or another secure location\n• To restore, tap 'Restore from Backup' and select your backup file\n• Photos in the backup are added to the device's Photo Library and linked to the restored records\n• If Photo Library access is unavailable during restore, photo data is kept inside the restored app data as a fallback\n• Warning: Restoring replaces ALL current app data and cannot be undone\n• Regular backups are recommended"
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
