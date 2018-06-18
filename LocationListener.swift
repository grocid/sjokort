import Foundation
import CoreLocation

class LocationListener: NSObject {
  let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    manager.activityType = .other
    manager.requestWhenInUseAuthorization()
  }
}

extension LocationListener: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedWhenInUse {
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error)
  }
}
