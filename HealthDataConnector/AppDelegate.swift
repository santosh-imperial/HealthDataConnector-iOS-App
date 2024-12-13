//
//  AppDelegate.swift
//  HealthDataConnector
//
//  Created by Santosh Kumar Saravanan on 23/11/24.
//

import UIKit
import CoreData
import AWSMobileClientXCF
import AWSS3
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    
    var window: UIWindow?



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize AWSMobileClient
                AWSMobileClient.default().initialize { (userState, error) in
                    if let error = error {
                        print("Error initializing AWSMobileClient: \(error.localizedDescription)")
                    } else {
                        print("AWSMobileClient initialized.")

                        // Set up the default service configuration
                        let credentialsProvider = AWSMobileClient.default()
                        let configuration = AWSServiceConfiguration(
                            region: .EUNorth1, 
                            credentialsProvider: credentialsProvider
                        )
                        AWSServiceManager.default().defaultServiceConfiguration = configuration
                    }
                }
        // Register the background tasks after AWS initialization
        registerBackgroundTasks()
        
        return true
    }
    
    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
            // Register for the daily health data export background task
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.santosh.HealthDataConnector.healthDataExport", using: nil) { task in
                self.handleHealthDataExport(task: task as! BGAppRefreshTask)
            }
        }
    
    // Handle the background refresh task for health data export
      private func handleHealthDataExport(task: BGAppRefreshTask) {
          // Schedule the next background task
          scheduleHealthDataExport()

          // Create the operation queue and the operation that performs the export
          let queue = OperationQueue()
          queue.maxConcurrentOperationCount = 1

          let exportOperation = HealthDataExportOperation()

          // If the task expires, cancel the operation
          task.expirationHandler = {
              queue.cancelAllOperations()
          }

          // When the operation completes, mark the task as completed
          exportOperation.completionBlock = {
              let success = !exportOperation.isCancelled
              task.setTaskCompleted(success: success)
          }

          // Start the operation
          queue.addOperation(exportOperation)
      }
    // Schedule the daily health data export approximately 24 hours later
    func scheduleHealthDataExport() {
            let request = BGAppRefreshTaskRequest(identifier: "com.santosh.HealthDataConnector.healthDataExport")
            // Request to run earliest after 24 hours
            request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("Could not schedule health data export: \(error)")
            }
        }
    
    
    
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - App Lifecycle Events

    func applicationDidEnterBackground(_ application: UIApplication) {
            // Schedule the background task when the app goes to the background
            scheduleHealthDataExport()
        }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "HealthDataConnector")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                //
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

