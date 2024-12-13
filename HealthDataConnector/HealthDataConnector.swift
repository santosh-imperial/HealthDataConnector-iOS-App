//
//  HealthDataConnector.swift
//  HealthDataConnector
//
//  Created by Santosh Kumar Saravanan on 23/11/24.
//

import Foundation
import HealthKit
import AWSMobileClientXCF
import AWSS3

struct HealthData: Codable {
    let DataType: String
    let StartDate: String
    let EndDate: String?
    let Value: String
    let Unit: String
}


class HealthDataConnector {
    let healthStore = HKHealthStore()
    let apiURL = URL(string: "https://tipi3htkn7.execute-api.eu-north-1.amazonaws.com/prod/healthdata")!
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false, nil)
            return
        }
        let workoutType = HKObjectType.workoutType()
        let typesToRead: Set<HKObjectType> = [sleepType, glucoseType, heartRateType, workoutType]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
    func fetchHeartRateData(startDate: Date, endDate: Date, completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                completion(nil, error)
                return
            }

            if let samples = results as? [HKQuantitySample] {
                completion(samples, nil)
            } else {
                completion(nil, nil)
            }
        }

        healthStore.execute(query)
    }
    
    func fetchWorkoutData(startDate: Date, endDate: Date, completion: @escaping ([HKWorkout]?, Error?) -> Void) {
         let workoutType = HKObjectType.workoutType()

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                completion(nil, error)
                return
            }

            if let samples = results as? [HKWorkout] {
                completion(samples, nil)
            } else {
                completion(nil, nil)
            }
        }

        healthStore.execute(query)
    }

    
    func fetchSleepData(startDate: Date, endDate: Date, completion: @escaping ([HKCategorySample]?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                completion(nil, error)
                return
            }

            if let samples = results as? [HKCategorySample] {
                completion(samples, nil)
            } else {
                completion(nil, nil)
            }
        }

        healthStore.execute(query)
    }

    
    
    func fetchBloodGlucoseData(startDate: Date, endDate: Date, completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil, nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                completion(nil, error)
                return
            }

            if let samples = results as? [HKQuantitySample] {
                completion(samples, nil)
            } else {
                completion(nil, nil)
            }
        }

        healthStore.execute(query)
    }

    
    
    func createCSV(sleepData: [HKCategorySample], glucoseData: [HKQuantitySample]) -> String {
        var csvString = "Type,Start Date,End Date,Value,Unit\n"

        // Process sleep data
        for sample in sleepData {
            let startDate = sample.startDate
            let endDate = sample.endDate
            let value = sample.value
            let valueDescription: String

            switch value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                valueDescription = "In Bed"
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                valueDescription = "Asleep"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                valueDescription = "Awake"
            default:
                valueDescription = "Unknown"
            }

            csvString += "Sleep,\(startDate),\(endDate),\(valueDescription),\n"
        }

        // Process blood glucose data
        for sample in glucoseData {
            let startDate = sample.startDate
            let endDate = sample.endDate
            let unit = HKUnit(from: "mg/dL")
            let value = sample.quantity.doubleValue(for: unit)
            csvString += "Blood Glucose,\(startDate),\(endDate),\(value),\(unit.unitString)\n"
        }

        return csvString
    }
    
  
    func uploadCSVToS3(fileURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let bucketName = "ix-iot-data-bucket"
        let keyName = "HealthData/\(fileURL.lastPathComponent)"

        // Ensure AWSMobileClient is initialized
        AWSMobileClient.default().initialize { (userState, error) in
            if let error = error {
                print("Error initializing AWSMobileClient: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("AWSMobileClient initialized.")

                // Set up the service configuration
                let credentialsProvider = AWSMobileClient.default()
                let configuration = AWSServiceConfiguration(
                    region: .EUNorth1,
                    credentialsProvider: credentialsProvider
                )
                AWSServiceManager.default().defaultServiceConfiguration = configuration

                // Proceed with uploading the file
                self.performFileUpload(fileURL: fileURL, bucketName: bucketName, keyName: keyName, completion: completion)
            }
        }
    }

    private func performFileUpload(fileURL: URL, bucketName: String, keyName: String, completion: @escaping (Bool, Error?) -> Void) {
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = { (task, progress) in
            DispatchQueue.main.async {
                // Update progress UI if needed
                print("Upload Progress: \(progress.fractionCompleted)")
            }
        }

        let transferUtility = AWSS3TransferUtility.default()

        transferUtility.uploadFile(
            fileURL,
            bucket: bucketName,
            key: keyName,
            contentType: "text/csv",
            expression: expression
        ) { (task, error) in
            if let error = error {
                print("Error uploading file: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("Upload successful")
                completion(true, nil)
            }
        }
    }
    
    func saveCSVFile(csvString: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "HealthData_\(timestamp).csv"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)

            do {
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file saved at \(fileURL)")
                
                // Upload the file to S3
                uploadCSVToS3(fileURL: fileURL) { (success, error) in
                    if success {
                        print("File uploaded to S3 successfully.")
                    } else {
                        print("Failed to upload file to S3: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
                
            } catch {
                print("Failed to save CSV: \(error.localizedDescription)")
            }
        }
    }
    
    func sendHealthData(data: HealthData, completion: @escaping (Bool, Error?) -> Void) {
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let jsonData = try JSONEncoder().encode(data)
                request.httpBody = jsonData
            } catch {
                completion(false, error)
                return
            }

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(false, error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let statusError = NSError(domain: "Invalid response", code: 0, userInfo: nil)
                    completion(false, statusError)
                    return
                }

                completion(true, nil)
            }

            task.resume()
        }
    func fetchAndSendData(startDate: Date, endDate: Date, completion: @escaping () -> Void) {
            let dispatchGroup = DispatchGroup()
            var sleepData: [HKCategorySample] = []
            var glucoseData: [HKQuantitySample] = []
            var heartRateData: [HKQuantitySample] = []
            var workoutData: [HKWorkout] = []

            // Fetch Sleep Data
            dispatchGroup.enter()
            fetchSleepData(startDate: startDate, endDate: endDate) { data, error in
                if let data = data {
                    sleepData = data
                }
                dispatchGroup.leave()
            }

            // Fetch Blood Glucose Data
            dispatchGroup.enter()
            fetchBloodGlucoseData(startDate: startDate, endDate: endDate) { data, error in
                if let data = data {
                    glucoseData = data
                }
                dispatchGroup.leave()
            }

            // Fetch Heart Rate Data
            dispatchGroup.enter()
            fetchHeartRateData(startDate: startDate, endDate: endDate) { data, error in
                if let data = data {
                    heartRateData = data
                }
                dispatchGroup.leave()
            }

            // Fetch Workout Data
            dispatchGroup.enter()
            fetchWorkoutData(startDate: startDate, endDate: endDate) { data, error in
                if let data = data {
                    workoutData = data
                }
                dispatchGroup.leave()
            }

            dispatchGroup.notify(queue: .global()) {
                if sleepData.isEmpty && glucoseData.isEmpty && heartRateData.isEmpty && workoutData.isEmpty {
                    print("No data found for selected dates.")
                    completion()
                    return
                }
                self.processAndSendHealthData(sleepData: sleepData, glucoseData: glucoseData, heartRateData: heartRateData, workoutData: workoutData)
                completion()
            }
        }
    
    func processAndSendHealthData(sleepData: [HKCategorySample],
                                      glucoseData: [HKQuantitySample],
                                      heartRateData: [HKQuantitySample],
                                      workoutData: [HKWorkout]) {
            var healthDataArray: [HealthData] = []

            // Process Sleep Data
            for sample in sleepData {
                let dataType = "Sleep"
                let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                let endDate = ISO8601DateFormatter().string(from: sample.endDate)
                let value = "\(sample.value)"
                let unit = "Sleep Analysis"

                let healthData = HealthData(DataType: dataType,
                                            StartDate: startDate,
                                            EndDate: endDate,
                                            Value: value,
                                            Unit: unit)
                healthDataArray.append(healthData)
            }

            // Process Blood Glucose Data
            for sample in glucoseData {
                let dataType = "Blood Glucose"
                let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                let endDate: String? = nil
                let glucoseUnit = HKUnit(from: "mg/dL")
                let value = "\(sample.quantity.doubleValue(for: glucoseUnit))"
                let unit = "mg/dL"

                let healthData = HealthData(DataType: dataType,
                                            StartDate: startDate,
                                            EndDate: endDate,
                                            Value: value,
                                            Unit: unit)
                healthDataArray.append(healthData)
            }

            // Process Heart Rate Data
            for sample in heartRateData {
                let dataType = "Heart Rate"
                let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                let endDate = ISO8601DateFormatter().string(from: sample.endDate)
                let unit = "bpm"
                let value = "\(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))" // bpm

                let healthData = HealthData(DataType: dataType,
                                            StartDate: startDate,
                                            EndDate: endDate,
                                            Value: value,
                                            Unit: unit)
                healthDataArray.append(healthData)
            }

            // Process Workout Data
            for workout in workoutData {
                let dataType = "Workout"
                let startDate = ISO8601DateFormatter().string(from: workout.startDate)
                let endDate = ISO8601DateFormatter().string(from: workout.endDate)
                let durationInMinutes = Int(workout.duration / 60) // Duration in minutes
                let value = "\(durationInMinutes)"
                let unit = "minutes"

                let healthData = HealthData(DataType: dataType,
                                            StartDate: startDate,
                                            EndDate: endDate,
                                            Value: value,
                                            Unit: unit)
                healthDataArray.append(healthData)
            }

            // Send the data to API
            sendHealthDataToAPI(healthDataArray: healthDataArray)
        }
    // MARK: - Send Health Data to API
        func sendHealthDataToAPI(healthDataArray: [HealthData]) {
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let jsonData = try JSONEncoder().encode(healthDataArray)
                request.httpBody = jsonData
            } catch {
                print("Failed to encode health data array: \(error.localizedDescription)")
                return
            }

            let semaphore = DispatchSemaphore(value: 0)

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                defer { semaphore.signal() }

                if let error = error {
                    print("Failed to send health data: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response received.")
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    print("Health data sent successfully.")
                } else {
                    let responseBody = String(data: data ?? Data(), encoding: .utf8) ?? "No response body"
                    print("Server error with status code: \(httpResponse.statusCode). Response: \(responseBody)")
                }
            }

            task.resume()
            semaphore.wait() // Wait until the request is done
        }
    
    
}

