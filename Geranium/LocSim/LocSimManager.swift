//
//  LocSimManager.swift
//  Geranium
//
//  Created by Constantin Clerc on 12.11.2022.
//

import Foundation
import CoreLocation


class LocSimManager {
    static let simManager = CLSimulationManager()
    
    /// Updates timezone
    static func post_required_timezone_update(){
        CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), .init("AutomaticTimeZoneUpdateNeeded" as CFString), nil, nil, kCFNotificationDeliverImmediately);
    }
    
    /// Starts a location simulation of specified argument "location"
    // TODO: save
    static func startLocSim(location: CLLocation) {
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.appendSimulatedLocation(location)
        simManager.flush()
        simManager.startLocationSimulation()
        post_required_timezone_update();
    }
    
    /// Stops location simulation
    static func stopLocSim(){
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.flush()
        post_required_timezone_update();
    }
}


struct EquatableCoordinate: Equatable {
    var coordinate: CLLocationCoordinate2D
    
    static func ==(lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}


// https://stackoverflow.com/a/75703059

class LocationModel: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var authorisationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?

    override init() {
        // 在初始化时就获取当前的权限状态
        self.authorisationStatus = CLLocationManager().authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 如果已经有权限，立即开始更新位置
        if authorisationStatus == .authorizedWhenInUse || authorisationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    public func requestAuthorisation(always: Bool = false) {
        if always {
            self.locationManager.requestAlwaysAuthorization()
        } else {
            self.locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }
}

extension LocationModel: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorisationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
    }
}
