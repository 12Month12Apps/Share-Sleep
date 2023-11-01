//
//  HealthkitManager.swift
//  ShareSleep
//
//  Created by Veit Progl on 08.10.23.
//

import Foundation
import HealthKit

protocol SleepData {
    var duration: Double { get set }
    var startTime: Date { get set }
    var endTime: Date { get set }
    var timeAwake: Double { get set }
    var timeREM: Double { get set }
    var timeCore: Double { get set }
    var timeDeep: Double { get set }
    var InterruptionsCount: Int { get set }
    var timeNeededTillSleep: Double { get set }
    var hartRateMin: Double { get set }
    var hartRateMax: Double { get set }
    var hartRateAvg: Double { get set }
}

class SleepDataModel: SleepData, ObservableObject {
    internal init(duration: Double, startTime: Date, endTime: Date, timeAwake: Double, timeREM: Double, timeCore: Double, timeDeep: Double, InterruptionsCount: Int, timeNeededTillSleep: Double, hartRateMin: Double, hartRateMax: Double, hartRateAvg: Double) {
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.timeAwake = timeAwake
        self.timeREM = timeREM
        self.timeCore = timeCore
        self.timeDeep = timeDeep
        self.InterruptionsCount = InterruptionsCount
        self.timeNeededTillSleep = timeNeededTillSleep
        self.hartRateMin = hartRateMin
        self.hartRateMax = hartRateMax
        self.hartRateAvg = hartRateAvg
    }
    
    var duration: Double
    var startTime: Date
    var endTime: Date
    var timeAwake: Double
    var timeREM: Double
    var timeCore: Double
    var timeDeep: Double
    var InterruptionsCount: Int
    var timeNeededTillSleep: Double
    var hartRateMin: Double
    var hartRateMax: Double
    var hartRateAvg: Double
}

enum HealthKitError: Error {
    case noData
}

class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func getAuthorizationState() -> HKAuthorizationStatus {
        let authorizationStatusSleep = healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        return authorizationStatusSleep
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let readTypes: Set = [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, HKQuantityType.quantityType(forIdentifier: .heartRate)!]
        
        let authorizationStatusSleep = getAuthorizationState()
        
        let authorizationStatusHeartRate = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)

        if authorizationStatusSleep == .notDetermined || authorizationStatusHeartRate == .notDetermined {
            // Fordern Sie die Autorisierung an
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) in
                if success {
                    // Autorisierungsstatus speichern
                    UserDefaults.standard.set(true, forKey: "isAuthorized")
                    
                    completion(success)
                } else {
                    // Fehler bei der Autorisierung
                    if let error = error {
                        print("Fehler bei der Autorisierung: \(error.localizedDescription)")
                    }
                    completion(false)
                }
            }
        } else if authorizationStatusSleep == .sharingAuthorized && authorizationStatusHeartRate == .sharingAuthorized {
            // Die Autorisierung wurde bereits erteilt
            completion(true)
        } else {
            // Überprüfen, ob die Autorisierung zuvor erteilt wurde
            let isAuthorized = UserDefaults.standard.bool(forKey: "isAuthorized")
            if isAuthorized {
                // Die Autorisierung wurde zuvor erteilt
                completion(true)
            } else {
                // Die Autorisierung wurde abgelehnt oder es ist ein anderer Fehler aufgetreten
                completion(false)
            }
        }
    }
    
    func querySleepData(completion: @escaping (SleepData?, Error?) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
            guard var sleepSamples = samples as? [HKCategorySample], error == nil else {
                completion(nil, error)
                return
            }

            var timeREM = 0.0, timeCore = 0.0, timeDeep = 0.0, timeAwake = 0.0

            let bedTimeStart = sleepSamples.removeFirst()
            
            for sample in sleepSamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    timeCore += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    timeAwake += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    timeREM += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    timeDeep += duration
                default:
                    break
                }
            }
            
            var sleepData: SleepData? = nil
            
            guard let sleepStart = sleepSamples.first?.startDate else { return completion(nil, HealthKitError.noData) }
            guard let sleepEnd = sleepSamples.last?.endDate else { return completion(nil, HealthKitError.noData) }
            let timeNeededTillSleep = bedTimeStart.endDate.timeIntervalSince( bedTimeStart.startDate)
            
            let sleepInterruptions = sleepSamples.filter( { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue } ).count
            
            
            self.queryHeartRate(start: sleepStart, end: sleepEnd) { minHart, maxHart, avgHart, err in
                
                if err != nil {
                    completion(nil, err)
                }
                
                sleepData = SleepDataModel(
                    duration: sleepEnd.timeIntervalSince(sleepStart) - timeAwake,
                    startTime: sleepStart,
                    endTime: sleepEnd,
                    timeAwake: timeAwake,
                    timeREM: timeREM,
                    timeCore: timeCore,
                    timeDeep: timeDeep,
                    InterruptionsCount: sleepInterruptions,
                    timeNeededTillSleep: timeNeededTillSleep,
                    hartRateMin: minHart,
                    hartRateMax: maxHart,
                    hartRateAvg: avgHart
                )
                
                completion(sleepData, nil)

            }
        }

        healthStore.execute(query)
    }
    
    private func queryHeartRate(start: Date, end: Date, completion: @escaping (Double, Double, Double, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMin, .discreteMax]) { (query, statistics, error) in
            guard let statistics = statistics, error == nil else {
                completion(0, 0, 0, error)
                return
            }
            
            let minRate = statistics.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let maxRate = statistics.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let avgRate = statistics.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            
            completion(minRate ?? 0, maxRate ?? 0, avgRate ?? 0, nil)
        }
        
        healthStore.execute(query)
    }
}
