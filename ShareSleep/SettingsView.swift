//
//  SettingsView.swift
//  ShareSleep
//
//  Created by Veit Progl on 01.11.23.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    
    @State var sleepHours: Double = 8
    
    var body: some View {
        VStack() {
            Text("Sleep Target:")
            Stepper {
                Text(String(sleepHours))
            } onIncrement: {
                sleepHours += 0.25
            } onDecrement: {
                sleepHours -= 0.25
            }
            
            Button("Save", action: {
                UserDefaults.standard.setValue(sleepHours, forKey: "targetedSleep")
            })
        }.onAppear(perform: {
            self.sleepHours =  UserDefaults.standard.double(forKey: "targetedSleep")
        })
    }
}
