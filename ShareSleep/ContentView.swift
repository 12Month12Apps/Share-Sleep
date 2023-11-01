//
//  ContentView.swift
//  ShareSleep
//
//  Created by Veit Progl on 08.10.23.
//

import SwiftUI

extension String {
    static func timeString(from seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        var timeString = ""
        
        if hours > 0 {
            timeString += "\(hours)h "
        }
        
        if minutes > 0 {
            timeString += "\(minutes)m "
        }
        
        if remainingSeconds > 0 {
            timeString += "\(remainingSeconds)s"
        }
        
        return timeString
    }
}
struct ContentView: View {
    let healthKitManager = HealthKitManager()

    @State var sleepData: SleepDataModel?
    @State var sleepScore: Double?
    
    var body: some View {
        VStack {
            List {
                if sleepScore != nil {
                    Section("Score") {
                        Text(String((sleepScore)!))
                    }
                }
                
                if sleepData?.score != nil {
                    Section("Score") {
                        Text(String((sleepData?.score)!))
                    }
                }
                
                Section("Start Time") {
                    Text(sleepData?.startTime ?? Date(), format: .dateTime)
                }
                
                Section("End Time") {
                    Text(sleepData?.endTime ?? Date(), format: .dateTime)
                }
                
                if let duration = sleepData?.duration {
                    Section("Länge") {
                        Text(String.timeString(from: duration))
                    }
                }
                
                if let timeAwake = sleepData?.timeAwake {
                    Section("Time Awake") {
                        Text(String.timeString(from: timeAwake))
                    }
                }
                
                if let timeREM = sleepData?.timeREM {
                    Section("Time REM") {
                        Text(String.timeString(from: timeREM))
                    }
                }
                
                if let timeCore = sleepData?.timeCore {
                    Section("Time Core") {
                        Text(String.timeString(from: timeCore))
                    }
                }
                
                if let timeDeep = sleepData?.timeDeep {
                    Section("Time Deep") {
                        Text(String.timeString(from: timeDeep))
                    }
                }
                
                if let interruptionsCount = sleepData?.InterruptionsCount {
                    Section("InterrouptionsCount") {
                        Text(String(interruptionsCount))
                    }
                }
                
                if let timeNeededTillSleep = sleepData?.timeNeededTillSleep {
                    Section("Time needed till sleep") {
                        Text(String.timeString(from: timeNeededTillSleep))
                    }
                }
                
                if (sleepData?.hartRateMax) != nil {
                    Section("Time heartRate Max") {
                        Text(String(sleepData!.hartRateMax))
                    }
                }
                if (sleepData?.hartRateMin) != nil {
                    Section("Time heartRate Min") {
                        Text(String(sleepData!.hartRateMin))
                    }
                }
                
                if (sleepData?.hartRateMin) != nil {
                    Section("Time heartRate Avg") {
                        Text(String(sleepData!.hartRateAvg))
                    }
                }
            }
        }
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
                
                self.healthKitManager.sleepDept() { dept, error in
                    guard let sleepDept = dept else { return }
                    
                    guard let sleepDuration = self.sleepData?.duration else { return }
                    self.sleepScore = sleepDuration / 3600 * 100 / (7.5 + sleepDept / 5)
                }
            }
        })
    }
}

#Preview {
    ContentView()
}
