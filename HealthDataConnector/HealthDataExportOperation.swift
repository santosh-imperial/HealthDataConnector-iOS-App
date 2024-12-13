//
//  HealthDataExportOperation.swift
//  HealthDataConnector
//
//

import Foundation
import HealthKit

class HealthDataExportOperation: Operation {

    private let healthDataConnector = HealthDataConnector()

    override func main() {
        if self.isCancelled { return }

        // Define the date range for the export (e.g., previous day)
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) else { return }

        let semaphore = DispatchSemaphore(value: 0)

        healthDataConnector.requestAuthorization { [weak self] success, error in
            if success {
                self?.healthDataConnector.fetchAndSendData(startDate: startDate, endDate: endDate) {
                    semaphore.signal()
                }
            } else {
                print("Authorization failed: \(String(describing: error))")
                semaphore.signal()
            }
        }

        // Wait until the export is done or operation is cancelled
        semaphore.wait()

        if self.isCancelled { return }
    }
}
