//
//  ContentView.swift
//  ShareSleep
//
//  Created by Veit Progl on 08.10.23.
//

import SwiftUI

struct ContentView: View {
    let healthKitManager = HealthKitManager()

    @State var sleepData: SleepDataModel?
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Text(sleepData?.startTime ?? Date(), format: .dateTime)
            Text(sleepData?.endTime ?? Date(), format: .dateTime)
        }
        .padding()
        .onAppear(perform: {
            healthKitManager.requestAuthorization { success in
                guard success else {
                    // Handle error (user denied access, etc.)
                    return
                }
                
                self.healthKitManager.querySleepData { samples, error in
                    guard let sleepSamples = samples else {
                        // Handle errorp
                        return
                    }
                    
                    // Handle fetched sleep data
                    // ...
                    
                    print(sleepSamples)
                    sleepData = sleepSamples as? SleepDataModel
                    let timeZone = TimeZone.current
                    print(timeZone)
                }
            }
        })
    }
}

#Preview {
    ContentView()
}
