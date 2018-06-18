/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import MapKit

class MapViewController: UIViewController {
  
  @IBOutlet weak var mapView: MKMapView!
  
  var tileRenderer: MKTileOverlayRenderer!
  var ais: AisClient = AisClient()
  var boatPositions = [Int: BoatPin]()
  var annotationQueue = PriorityQueue<AnnotationWrapper>(sort: <)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupTileRenderer()
    
    mapView.delegate = self
    mapView.showsUserLocation = true
    mapView.showsCompass = true
    mapView.setUserTrackingMode(.followWithHeading, animated: true)

    ais.delegate = self
    ais.setupNetworkCommunication()
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    return tileRenderer
  }

  func setupTileRenderer() {
    let overlay = NauticalMapOverlay()
    mapView.add(overlay, level: .aboveLabels)
    tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
  }
}

extension MapViewController: MKMapViewDelegate {
  func mapView(_ : MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation {
      return nil
    }
    let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") ?? MKAnnotationView()
    annotationView.canShowCallout = true
    annotationView.image = UIImage(named: "shippin.png")
    return annotationView
  }
}

struct AnnotationWrapper {
  var priority: Int
  var annotation: Int
}

private func < (a: AnnotationWrapper, b: AnnotationWrapper) -> Bool {
  return a.priority < b.priority
}

private func getIndex() -> Int {
  return Int(Date().timeIntervalSince1970)
}

extension MapViewController: AisClientDelegate {
  
  private func purgeQueue() {
    let now = getIndex()
    let delta = 20
    // If the entry is older than delta time units
    debugPrint(self.annotationQueue.count)
    
    while let top = self.annotationQueue.peek(), top.priority < now - delta {
      debugPrint(top)
      // Dequeue it
      if let removed = self.annotationQueue.dequeueTop() {
        // And check if there is an entry with newer time added
        if let val = self.boatPositions[removed.annotation] {
          if val.added < now - delta {
            debugPrint("annotation removed")
            // If not, remove the annotation
            mapView.removeAnnotation(val)
          }
        }
      }
    }
  }
  
  func receivedMessage(vessel : Vessel) {
    // Check if we already have a registered
    // vessel in the map.
    if vessel == nil {
      return
    }
    if let val = self.boatPositions[vessel.immsi] {
      // If so, update coordinate
      val.coordinate = CLLocationCoordinate2DMake(vessel.latitude, vessel.longitude)
      val.added = getIndex()
    } else {
      // Else, we create a new one
      let boat = BoatPin(
        title: String(vessel.immsi),
        latitude: vessel.latitude,
        longitude: vessel.longitude,
        added: getIndex()
      )
      // Put into the map
      self.boatPositions[vessel.immsi] = boat
      // And queue it for deletion
      mapView.addAnnotation(boat)
    }
    self.annotationQueue.enqueue(AnnotationWrapper(
      priority: getIndex(),
      annotation: vessel.immsi
    ))
    purgeQueue()
  }
}
