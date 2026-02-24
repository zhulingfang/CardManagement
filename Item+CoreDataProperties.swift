//
//  Item+CoreDataProperties.swift
//  CardManagement
//
//  Created by Ethan Ying on 7/28/25.
//
//

import Foundation
import CoreData


extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var title: String?
    @NSManaged public var id: UUID?
    @NSManaged public var note: String?
    @NSManaged public var tradeInValue: NSDecimalNumber?
    @NSManaged public var tradeOutValue: NSDecimalNumber?
    @NSManaged public var transactionPK: UUID?
    @NSManaged public var currentValue: NSDecimalNumber?
    @NSManaged public var timestamp: Date?

}

extension Item : Identifiable {

}
