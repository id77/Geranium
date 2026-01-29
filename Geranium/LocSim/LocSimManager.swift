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
    
    // 持久化键名
    private static let isSpoofingKey = "isSpoofing"
    private static let spoofingCoordinateKey = "spoofingCoordinate"
    private static let spoofingLabelKey = "spoofingLabel"
    private static let spoofingNoteKey = "spoofingNote"
    
    /// 检查模拟是否真的在运行
    /// 通过对比真实位置和保存的模拟位置来判断
    static func isSimulationActuallyRunning(currentLocation: CLLocation?, savedCoordinate: CLLocationCoordinate2D) -> Bool {
        guard let currentLocation = currentLocation else {
            // 没有当前位置，无法判断，暂时认为在运行
            return true
        }
        
        let savedLocation = CLLocation(latitude: savedCoordinate.latitude, longitude: savedCoordinate.longitude)
        let distance = savedLocation.distance(from: currentLocation)
        
        // 如果当前位置和保存的模拟位置距离很近（< 50米），说明模拟还在运行
        // 如果距离很远（> 1000米），说明模拟已经停止，系统回到了真实位置
        if distance > 1000 {
            NSLog("⚠️ 当前位置距离保存的模拟位置 \(distance) 米，判断模拟已停止")
            return false
        }
        
        return true
    }
    
    /// Updates timezone
    static func post_required_timezone_update(){
        CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), .init("AutomaticTimeZoneUpdateNeeded" as CFString), nil, nil, kCFNotificationDeliverImmediately);
    }
    
    /// Starts a location simulation of specified argument "location"
    static func startLocSim(location: CLLocation, point: LocationPoint) {
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.appendSimulatedLocation(location)
        simManager.flush()
        simManager.startLocationSimulation()
        post_required_timezone_update()
        
        // 持久化模拟状态和坐标信息
        NSLog("💾 开始持久化模拟状态")
        NSLog("📍 坐标: \(point.latitude), \(point.longitude)")
        NSLog("🏷️ 标签: \(point.label ?? "无")")
        NSLog("🏠 地址: \(point.note ?? "无")")
        
        UserDefaults.standard.set(true, forKey: isSpoofingKey)
        UserDefaults.standard.set([point.latitude, point.longitude], forKey: spoofingCoordinateKey)
        UserDefaults.standard.set(point.label, forKey: spoofingLabelKey)
        UserDefaults.standard.set(point.note, forKey: spoofingNoteKey)
        UserDefaults.standard.synchronize() // 强制立即同步
        
        NSLog("✅ 持久化完成")
        NSLog("   - isSpoofing: \(UserDefaults.standard.bool(forKey: isSpoofingKey))")
        NSLog("   - coordinate: \(UserDefaults.standard.array(forKey: spoofingCoordinateKey) ?? [])")
    }
    
    /// Stops location simulation
    /// 停止模拟定位，并强制重启系统定位服务以加快恢复
    static func stopLocSim(locationModel: LocationModel? = nil){
        NSLog("🛑 停止位置模拟...")
        
        simManager.stopLocationSimulation()
        simManager.clearSimulatedLocations()
        simManager.flush()
        post_required_timezone_update()
        
        // 清除持久化状态
        UserDefaults.standard.set(false, forKey: isSpoofingKey)
        UserDefaults.standard.removeObject(forKey: spoofingCoordinateKey)
        UserDefaults.standard.removeObject(forKey: spoofingLabelKey)
        UserDefaults.standard.removeObject(forKey: spoofingNoteKey)
        UserDefaults.standard.synchronize()
        
        // 强制重启系统定位服务，加快恢复真实位置
        locationModel?.forceRestartLocationServices()
    }
    
    /// 检查并同步模拟状态
    /// 在 app 启动时调用，对比当前位置和保存的模拟位置
    /// 如果误差小于 1000 米，认为模拟依然有效
    static func checkAndRestoreSpoofingState(currentLocation: CLLocation?) -> LocationPoint? {
        // 检查是否有持久化的模拟状态
        let isSpoofing = UserDefaults.standard.bool(forKey: isSpoofingKey)
        NSLog("🔍 检查持久化状态: isSpoofing = \(isSpoofing)")
        
        guard isSpoofing,
              let coordArray = UserDefaults.standard.array(forKey: spoofingCoordinateKey) as? [Double],
              coordArray.count == 2 else {
            NSLog("❌ 没有找到持久化的模拟状态")
            return nil
        }
        
        let savedCoordinate = CLLocationCoordinate2D(latitude: coordArray[0], longitude: coordArray[1])
        let label = UserDefaults.standard.string(forKey: spoofingLabelKey)
        let note = UserDefaults.standard.string(forKey: spoofingNoteKey)
        
        NSLog("✅ 找到持久化坐标: \(savedCoordinate.latitude), \(savedCoordinate.longitude)")
        NSLog("📍 标签: \(label ?? "无"), 地址: \(note ?? "无")")
        
        // 检查模拟是否真的在运行
        let actuallyRunning = isSimulationActuallyRunning(currentLocation: currentLocation, savedCoordinate: savedCoordinate)
        
        if !actuallyRunning {
            NSLog("⚠️ 持久化状态显示模拟中，但实际模拟已停止（可能被其他软件关闭），清除持久化状态")
            // 清除持久化状态
            UserDefaults.standard.set(false, forKey: isSpoofingKey)
            UserDefaults.standard.removeObject(forKey: spoofingCoordinateKey)
            UserDefaults.standard.removeObject(forKey: spoofingLabelKey)
            UserDefaults.standard.removeObject(forKey: spoofingNoteKey)
            return nil
        }
        
        let savedLocation = CLLocation(latitude: savedCoordinate.latitude, longitude: savedCoordinate.longitude)
        
        // 如果有当前位置，检查误差
        if let currentLocation = currentLocation {
            let distance = savedLocation.distance(from: currentLocation)
            NSLog("📏 当前位置与保存位置距离: \(distance) 米")
            
            // 误差小于 1000 米，认为模拟依然有效
            // 其他 app 定位时跳动可能导致误差较大，允许 1000 米的误差范围
            if distance < 1000 {
                NSLog("✅ 距离小于1000米，模拟依然有效，恢复状态")
                return LocationPoint(coordinate: savedCoordinate, label: label, note: note)
            } else {
                NSLog("⚠️ 距离大于1000米，模拟已失效，清除状态")
                // 误差过大，清除持久化状态
                UserDefaults.standard.set(false, forKey: isSpoofingKey)
                UserDefaults.standard.removeObject(forKey: spoofingCoordinateKey)
                UserDefaults.standard.removeObject(forKey: spoofingLabelKey)
                UserDefaults.standard.removeObject(forKey: spoofingNoteKey)
                return nil
            }
        } else {
            // 没有当前位置，直接恢复（因为如果模拟还在运行，系统位置就是模拟位置）
            NSLog("⚠️ 没有获取到当前位置，直接恢复模拟状态")
            return LocationPoint(coordinate: savedCoordinate, label: label, note: note)
        }
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
    
    /// 强制重启定位服务，用于停止模拟后快速恢复真实位置
    public func forceRestartLocationServices() {
        NSLog("🔄 强制重启定位服务")
        
        // 先停止定位
        locationManager.stopUpdatingLocation()
        
        // 清除缓存的位置
        currentLocation = nil
        
        // 设置最高精度，加快定位
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 设置距离过滤器为无，确保收到所有位置更新
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // 重新开始定位
        locationManager.startUpdatingLocation()
        
        // 请求单次高精度定位（iOS 9+）
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
        }
        
        NSLog("✅ 定位服务已重启，等待新位置...")
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
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("⚠️ 定位失败: \(error.localizedDescription)")
        // 定位失败后继续尝试
        if CLLocationManager.locationServicesEnabled() {
            manager.startUpdatingLocation()
        }
    }
}
