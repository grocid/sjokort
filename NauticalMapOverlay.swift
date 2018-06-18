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

import Foundation
import MapKit

class NauticalMapOverlay: MKTileOverlay {

  let parentDirectory = "tilecache"
  let maximumCacheAge: TimeInterval = 30.0 * 24.0 * 60.0 * 60.0
  var urlSession: URLSession?
  
  init() {
    super.init(urlTemplate: "http://t2.openseamap.org/tiles/base/{z}/{x}/{y}.png")
    self.canReplaceMapContent = true
    self.isGeometryFlipped = true
    self.minimumZ = 4
    self.maximumZ = 14
    let sessionConfiguration = URLSessionConfiguration.default
    sessionConfiguration.urlCache = nil
    sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
    self.urlSession = URLSession(configuration: sessionConfiguration)
  }
  
  override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
    let parentXFolderURL = URLForTilecacheFolder().appendingPathComponent(self.cacheXFolderNameForPath(path))
    let tileFilePathURL = parentXFolderURL.appendingPathComponent(fileNameForTile(path))
    let tileFilePath = tileFilePathURL.path
    var useCachedVersion = false
    
    if FileManager.default.fileExists(atPath: tileFilePath) {
      if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: tileFilePath),
        let fileModificationDate = fileAttributes[FileAttributeKey.modificationDate] as? Date {
        if fileModificationDate.timeIntervalSinceNow > -1.0 * maximumCacheAge {
          useCachedVersion = true
        }
      }
    }
    
    if (useCachedVersion) {
      let cachedData = try? Data(contentsOf: URL(fileURLWithPath: tileFilePath))
      result(cachedData, nil)
    } else {
      let request = URLRequest(url: self.url(forTilePath: path))
      let task = urlSession!.dataTask(
        with: request,
        completionHandler: { (data, response, error) in
          if response != nil {
            if let httpResponse = response as? HTTPURLResponse {
              if httpResponse.statusCode == 200 {
                do {
                  try FileManager.default.createDirectory(
                    at: parentXFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil)
                } catch {
              }
              if !((try? data!.write(
                to: URL(fileURLWithPath: tileFilePath),
                options: [.atomic])) != nil) {
              }
              result(data, error as NSError?)
            }
          }
        }
      })
      task.resume()
    }
  }
  
  fileprivate func fileNameForTile(_ path: MKTileOverlayPath) -> String {
    return "\(path.y).png"
  }
  
  fileprivate func cacheXFolderNameForPath(_ path: MKTileOverlayPath) -> String {
    return "\(path.contentScaleFactor)/\(path.z)/\(path.x)"
  }
  
  fileprivate func URLForTilecacheFolder() -> URL {
    let URLForAppCacheFolder : URL = try! FileManager.default.url(
      for: FileManager.SearchPathDirectory.cachesDirectory,
      in: FileManager.SearchPathDomainMask.userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return URLForAppCacheFolder.appendingPathComponent(
      parentDirectory,
      isDirectory: true
    )
  }
  
  fileprivate func URLForXFolder(_ path: MKTileOverlayPath) -> URL {
    return URLForTilecacheFolder().appendingPathComponent(
      cacheXFolderNameForPath(path),
      isDirectory: true
    )
  }

    /*
  override func url(forTilePath path: MKTileOverlayPath) -> URL {
    let tilePath = Bundle.main.url(
      forResource: "\(path.y)",
      withExtension: "png",
      subdirectory: "tiles/\(path.z)/\(path.x)",
      localization: nil)
    guard let tile = tilePath else {
      return Bundle.main.url(
        forResource: "paper",
        withExtension: "jpg",
        subdirectory: "tiles",
        localization: nil)!
    }
    return tile
  }

  override func url(forTilePath path: MKTileOverlayPath) -> URL {
    let tileUrl = "http://10.0.1.4:8080/\(path.z)/\(path.x)/\(path.y).png"
    return URL(string: tileUrl)!
  }*/
  
}
