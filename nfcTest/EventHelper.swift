//
//  EventHelper.swift
//  nfcTest
//
//  Created by Claus Wolf on 20.10.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import Foundation
import EventKit

// code from https://stackoverflow.com/questions/28379603/how-to-add-an-event-in-the-device-calendar-using-swift

class EventHelper{
    
    // my event variables
    var itemTitle = String()
    var itemDescription = String()
    var itemLocation = String()
    var startDate = Date()
    var endDate = Date()
    
    // remainder code
    let appleEventStore = EKEventStore()
    var calendars: [EKCalendar]?
    
    func generateEvent() {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        
        switch (status){
        case EKAuthorizationStatus.notDetermined:
            // This happens on first-run
            requestAccessToCalendar()
        case EKAuthorizationStatus.authorized:
            // User has access
            print("User has access to calendar")
            self.addAppleEvents()
        case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
            // We need to help them give us permission
            noPermission()
        }
    }
    
    func noPermission(){
        print("User has to change settings...goto settings to view access")
    }
    
    func requestAccessToCalendar() {
        appleEventStore.requestAccess(to: .event, completion: { (granted, error) in
            if (granted) && (error == nil) {
                DispatchQueue.main.async {
                    print("User has access to calendar")
                    self.addAppleEvents()
                }
            } else {
                DispatchQueue.main.async{
                    self.noPermission()
                }
            }
        })
    }
    
    func addAppleEvents() {
        let event:EKEvent = EKEvent(eventStore: appleEventStore)
        event.title = self.itemTitle
        event.startDate = self.startDate
        event.endDate = self.endDate
        event.notes = self.itemDescription
        event.calendar = appleEventStore.defaultCalendarForNewEvents
        do {
            try appleEventStore.save(event, span: .thisEvent)
            print("events added with dates:")
            messageLabel.text = "Event wurde hinzugefügt"

        } catch let e as NSError {
            print(e.description)
            messageLabel.text = "Fehler beim Hinzufügen eines Events"
            return
        }

        
        
    }
}
