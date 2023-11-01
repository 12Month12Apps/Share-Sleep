//
//  ShareSleepApp.swift
//  ShareSleep
//
//  Created by Veit Progl on 08.10.23.
//

import SwiftUI

@main
struct ShareSleepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: {
                    let targetSleep = UserDefaults.standard.double(forKey: "targetedSleep")
                    if targetSleep == 0 {
                        UserDefaults.standard.setValue(8, forKey: "targetedSleep")
                    }
                })
        }
    }
}
