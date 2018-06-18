import UIKit

protocol AisClientDelegate: class {
  func receivedMessage(vessel: Vessel)
}

class AisClient: NSObject {
  
  weak var delegate: AisClientDelegate?
  
  var inputStream: InputStream!
  var outputStream: OutputStream!
  let maxReadLength = 4096
  
  var aisData: Dictionary<String, AnyObject>?
  
  override init() {
    super.init()
    self.readJsonData()
  }
  
  func readJsonData() {
    if let path = Bundle.main.path(forResource: "ais", ofType: "json") {
      do {
        let data = try Data(
          contentsOf: URL(fileURLWithPath: path),
          options: .mappedIfSafe
        )
        let jsonResult = try JSONSerialization.jsonObject(
          with: data,
          options: .mutableLeaves
        )
        if let jsonResult = jsonResult as? Dictionary<String, AnyObject> {
          // do stuff
          debugPrint(jsonResult)
          self.aisData = jsonResult
        }
      } catch {
        // handle error
        debugPrint("Error reading JSON data")
      }
    }
  }
  
  //1) Set up the input and output streams for message sending
  func setupNetworkCommunication() {
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       "10.0.1.4" as CFString,
                                       8101,
                                       &readStream,
                                       &writeStream)
    
    inputStream = readStream!.takeRetainedValue()
    outputStream = writeStream!.takeRetainedValue()
    // Set delegate
    inputStream.delegate = self
    outputStream.delegate = self
    // Schedule streams
    inputStream.schedule(in: .main, forMode: .commonModes)
    outputStream.schedule(in: .main, forMode: .commonModes)
    // Start reading data
    inputStream.open()
    outputStream.open()
  }
  
  func stopClientSession() {
    inputStream.close()
    outputStream.close()
  }
}

extension AisClient: StreamDelegate {
  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case Stream.Event.hasBytesAvailable:
      readAvailableBytes(stream: aStream as! InputStream)
    case Stream.Event.endEncountered:
      stopClientSession()
    case Stream.Event.errorOccurred:
      print("Unable to connect to AIS receiver.")
    default:
      break
    }
  }
  
  private func readAvailableBytes(stream: InputStream) {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
    while stream.hasBytesAvailable {
      let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
      if numberOfBytesRead < 0 {
        if let _ = inputStream.streamError {
          break
        }
      }
      if let vessel = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
        delegate?.receivedMessage(vessel: vessel)
      }
    }
  }

  private func fetchIntByAttr(buffer: [UInt8], aisType: Int, pos: String) ->  Int? {
    if let data = self.aisData {
      if let aisObject = data[String(aisType)] {
        if let aisProperty = aisObject[pos] as? [String: Any] {
          if let index = aisProperty["index"] as? Int, let length = aisProperty["len"] as? Int {
            return parseIntFromBuffer(buffer: buffer, start: index, len: length)
          }
        }
      }
    }
    return nil
  }
  
  private func convertToSignedInt32(int: Int) -> Int32 {
    // Convert using two-complement conversion, keeping the
    // bit size under control.
    if (int & 0x80000000 != 0) {
      return Int32(((int & 0xffffffff) ^ 0xffffffff + 1) & 0xffffffff)
    }
    return Int32(int & 0xffffffff)
  }
  
  private func getLatitudeAndLongitude(buffer: [UInt8], aisType: Int) -> (Double, Double)? {
    if var lon = fetchIntByAttr(buffer: buffer, aisType: aisType, pos: "lon"),
       var lat = fetchIntByAttr(buffer: buffer, aisType: aisType, pos: "lat") {
      if (lon & 0x08000000 != 0) {
        lon |= 0xf0000000
      }
      let lonf = Double(convertToSignedInt32(int: lon))/600000;
      if(lat & 0x04000000 != 0) {
        lat |= 0xf8000000
      }
      let latf = Double(convertToSignedInt32(int: lat))/600000
      return (latf, lonf)
    }
    return nil
  }
  
  private func parseIntFromBuffer(buffer: [UInt8], start: Int, len: Int) -> Int {
    var acc:Int = 0
    var cp:Int, cx: Int, c0:Int, cs:Int
    
    if buffer.count < Int((start + len)/6) {
      return 0
    }
    
    for i in 0...(len-1) {
      acc = acc << 1;
      cp = Int((start + i) / 6);
      cx = Int(buffer[cp]);
      cs = 5 - ((start + i) % 6);
      c0 = (cx >> cs) & 1;
      acc |= c0;
    }
    return acc;
  }
  
  private func decodePayloadToBitArray(buffer: String) -> [UInt8] {
    var bitarray: [UInt8] = [];

    for char in buffer.utf8 {
      var byte = char
      // check byte is not out of range
      if ((byte < 0x30) || (byte > 0x77)) {
        return []
      }
      if ((0x57 < byte) && (byte < 0x60)) {
        return []
      }
      // move from printable char to wacky AIS/IEC 6 bit representation
      byte += 0x28;
      if(byte > 0x80)  {
        byte += 0x20
      } else {
        byte += 0x28
      }
      bitarray.append(byte)
    }
    return bitarray;
  }
  
  private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                      length: Int) -> Vessel? {
    guard let stringArray =
      String(
        bytesNoCopy: buffer,
        length: length,
        encoding: .ascii,
        freeWhenDone: true)?.components(separatedBy: ",")
      else {
        return nil
    }
    debugPrint(stringArray)
    if stringArray.count > 4 {
      let data = decodePayloadToBitArray(buffer: stringArray[5])
      let aisType = parseIntFromBuffer(buffer: data, start: 0, len: 6)
      let immsi = parseIntFromBuffer(buffer: data, start: 8, len: 30)
      // Make sure it has a GPS position.
      if let (lat, lon) = getLatitudeAndLongitude(buffer: data, aisType: aisType) {
        return Vessel(
          type: aisType,
          immsi: immsi,
          latitude: lat,
          longitude: lon
        )
      }
    }
    return nil
  }
}
