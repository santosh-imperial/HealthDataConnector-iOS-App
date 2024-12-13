//
//  ViewController.swift
//  HealthDataConnector
//
//  Created by Santosh Kumar Saravanan on 23/11/24.
//

import UIKit
import HealthKit
import AWSMobileClientXCF
import AWSS3


class ViewController: UIViewController {
    
    
    @IBOutlet weak var statusLabel: UILabel!
    
    
    @IBAction func exportButtonTapped(_ sender: UIButton) {
        statusLabel.text = "Starting export..."
        exportHealthData()
    }
    
    
    @IBOutlet weak var startDatePicker: UIDatePicker!
    
    
    @IBOutlet weak var endDatePicker: UIDatePicker!
    
    
    func exportHealthData() {
        healthDataConnector.requestAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.statusLabel.text = "Authorization successful. Fetching data..."
                    self?.fetchAndSaveData()
                } else {
                    self?.statusLabel.text = "Authorization failed."
                }
            }
        }
    }

    func fetchAndSaveData() {
        let startDate = startDatePicker.date
        let endDate = endDatePicker.date

        guard startDate <= endDate else {
            statusLabel.text = "Start date must be earlier than end date."
            return
        }

        let dispatchGroup = DispatchGroup()
        var sleepData: [HKCategorySample] = []
        var glucoseData: [HKQuantitySample] = []
        var heartRateData: [HKQuantitySample] = []
        var workoutData: [HKWorkout] = []

        dispatchGroup.enter()
        healthDataConnector.fetchSleepData(startDate: startDate, endDate: endDate) { data, error in
            if let data = data {
                sleepData = data
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        healthDataConnector.fetchBloodGlucoseData(startDate: startDate, endDate: endDate) { data, error in
            if let data = data {
                glucoseData = data
            }
            dispatchGroup.leave()
        }
        
        // Fetch Heart Rate Data
        dispatchGroup.enter()
        healthDataConnector.fetchHeartRateData(startDate: startDate, endDate: endDate) { data, error in
                    if let data = data {
                        heartRateData = data
                    }
                    dispatchGroup.leave()
                }

        // Fetch Workout Data
        dispatchGroup.enter()
        healthDataConnector.fetchWorkoutData(startDate: startDate, endDate: endDate) { data, error in
                    if let data = data {
                        workoutData = data
                    }
                    dispatchGroup.leave()
                }

        dispatchGroup.notify(queue: .main) {
            if sleepData.isEmpty && glucoseData.isEmpty && heartRateData.isEmpty && workoutData.isEmpty{
                self.statusLabel.text = "No data found for selected dates."
                return
            }
            self.processAndSendHealthData(sleepData: sleepData, glucoseData: glucoseData, heartRateData: heartRateData, workoutData: workoutData)


           // let csvString = self.healthDataConnector.createCSV(sleepData: sleepData, glucoseData: glucoseData)
           //self.healthDataConnector.saveCSVFile(csvString: csvString)
            self.statusLabel.text = "Data export successful!"
            
            
        }
    }
    func processAndSendHealthData(sleepData: [HKCategorySample], glucoseData: [HKQuantitySample], heartRateData: [HKQuantitySample], workoutData: [HKWorkout]) {
            var healthDataArray: [HealthData] = []

            // Process sleep data
            for sample in sleepData {
                let dataType = "Sleep"
                let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                let endDate = ISO8601DateFormatter().string(from: sample.endDate)
                let value = "\(sample.value)"
                let unit = "Sleep Analysis"

                let healthData = HealthData(DataType: dataType, StartDate: startDate, EndDate: endDate, Value: value, Unit: unit)
                healthDataArray.append(healthData)
            }

            // Process glucose data
            for sample in glucoseData {
                let dataType = "Blood Glucose"
                let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                let endDate: String? = nil  // Glucose samples may not have an end date
                let glucoseUnit = HKUnit(from: "mg/dL")
                let value = "\(sample.quantity.doubleValue(for: glucoseUnit))"
                let unit = "mg/dL"

                let healthData = HealthData(DataType: dataType, StartDate: startDate, EndDate: endDate, Value: value, Unit: unit)
                healthDataArray.append(healthData)
            }
            // Process Heart Rate Data
            for sample in heartRateData {
                    let dataType = "Heart Rate"
                    let startDate = ISO8601DateFormatter().string(from: sample.startDate)
                    let endDate = ISO8601DateFormatter().string(from: sample.endDate)
                    let unit = "bpm"
                    let value = "\(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))"

                    let healthData = HealthData(DataType: dataType, StartDate: startDate, EndDate: endDate, Value: value, Unit: unit)
                    healthDataArray.append(healthData)
                }

            // Process Workout Data
            for workout in workoutData {
                    let dataType = "Workout"
                    let startDate = ISO8601DateFormatter().string(from: workout.startDate)
                    let endDate = ISO8601DateFormatter().string(from: workout.endDate)
                    let durationInMinutes = Int(workout.duration / 60)
                    let value = "\(durationInMinutes)"
                    let unit = "minutes"

                    let healthData = HealthData(DataType: dataType, StartDate: startDate, EndDate: endDate, Value: value, Unit: unit)
                    healthDataArray.append(healthData)
                }


            // Send the data to API
            sendHealthDataToAPI(healthDataArray: healthDataArray)
        }
    
    

    func sendHealthDataToAPI(healthDataArray: [HealthData]) {
        guard let apiURL = URL(string: "https://tipi3htkn7.execute-api.eu-north-1.amazonaws.com/prod/healthdata") else {
            DispatchQueue.main.async {
                self.statusLabel.text = "Invalid API URL."
            }
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(healthDataArray)
            request.httpBody = jsonData
        } catch {
            print("Failed to encode health data array: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.statusLabel.text = "Failed to encode data."
            }
            return
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Failed to send health data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Failed to send data."
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response received.")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Invalid server response."
                }
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                print("Health data sent successfully.")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Data export successful!"
                }
            } else {
                print("Server error with status code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Server error occurred."
                }
            }
        }

        task.resume()
    }


    
    
    let healthDataConnector = HealthDataConnector()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let today = Date()
            endDatePicker.date = today
            startDatePicker.date = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
            endDatePicker.maximumDate = today
            startDatePicker.maximumDate = today
        
        
        
    }
   
}
