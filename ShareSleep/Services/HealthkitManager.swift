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
    var score: Double? { get set }
    var debt: Double? { get set }
    var sleepDepChart: [Double] { get set }
}

struct SleepDataModel: SleepData {
    internal init(duration: Double, startTime: Date, endTime: Date, timeAwake: Double, timeREM: Double, timeCore: Double, timeDeep: Double, InterruptionsCount: Int, timeNeededTillSleep: Double, hartRateMin: Double, hartRateMax: Double, hartRateAvg: Double, score: Double?, debt: Double?) {
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
        self.score = score
        self.debt = debt
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
    var score: Double?
    var debt: Double?
    var sleepDepChart: [Double] = []
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
    
    func sleepDept(completion: @escaping ([Double], Error?) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -14, to: endDate)!
//        var totalSleepDebt = 0.0
        var sleepDeps: [Double] = []

        func queryNextDay(currentDate: Date) {
            guard currentDate < endDate else {
                completion(sleepDeps, nil)
                return
            }
            let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            let targetSleep = UserDefaults.standard.double(forKey: "targetedSleep")

            querySleepData(startDate: currentDate, endDate: nextDate) { (sleepData, error) in
                if let sleepData = sleepData, error == nil {

                    let idealSleep = targetSleep  // Angenommen, 8 Stunden Schlaf pro Nacht sind ideal
                    let actualSleep = sleepData.duration / 3600  // Umrechnung von Sekunden in Stunden
                    let sleepDebt = idealSleep - actualSleep
                    sleepDeps.append(sleepDebt)
//                    totalSleepDebt += sleepDebt
                }
                queryNextDay(currentDate: nextDate)
            }
        }
        
        queryNextDay(currentDate: startDate)
    }
    
    func querySleepData(startDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!, 
                        endDate: Date = Date(),
                        completion: @escaping (SleepData?, Error?) -> Void) {
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
            guard var sleepSamples = samples as? [HKCategorySample], error == nil else {
                completion(nil, error)
                return
            }

            if sleepSamples.count == 0 {
                completion(nil, HealthKitError.noData)
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
            
            guard let sleepStart = sleepSamples.first(where: {
                $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue
            } )?.startDate else {
                return completion(nil, HealthKitError.noData)
            }
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
                    hartRateAvg: avgHart, score: nil, debt: nil
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
