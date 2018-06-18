//
//  Boat.swift
//  Båtkarta
//
//  Created by Carl Löndahl on 2018-05-26.
//  Copyright © 2018 Grocid. All rights reserved.
//

import Foundation
import MapKit

class BoatPin: NSObject, MKAnnotation {
  let title: String?
  dynamic var coordinate: CLLocationCoordinate2D
  var added: Int
  
  init(title: String, latitude: Double, longitude: Double, added: Int) {
    self.title = title
    self.coordinate = CLLocationCoordinate2DMake(latitude, longitude)
    self.added = added
    super.init()
  }
}
