import Foundation
import os

struct ParsedXMLHealthRecord {
  let type: String
  let startDate: Date
  let endDate: Date
  let value: String
  let unit: String?
}

protocol GooseHealthKitXMLParserDelegate: AnyObject {
  func parser(_ parser: GooseHealthKitXMLParser, didParseBatch batch: [ParsedXMLHealthRecord])
  func parserDidFinish(_ parser: GooseHealthKitXMLParser)
  func parser(_ parser: GooseHealthKitXMLParser, didFailWithError error: Error)
}

final class GooseHealthKitXMLParser: NSObject, XMLParserDelegate {
  private let fileURL: URL
  private let batchSize: Int
  weak var delegate: GooseHealthKitXMLParserDelegate?

  private var currentBatch: [ParsedXMLHealthRecord] = []
  private lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private let relevantTypes: Set<String> = [
    "HKQuantityTypeIdentifierHeartRate",
    "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
    "HKQuantityTypeIdentifierRestingHeartRate",
    "HKCategoryTypeIdentifierSleepAnalysis",
    "HKQuantityTypeIdentifierActiveEnergyBurned",
    "HKQuantityTypeIdentifierRespiratoryRate"
  ]

  init(fileURL: URL, batchSize: Int = 1000) {
    self.fileURL = fileURL
    self.batchSize = batchSize
    super.init()
  }

  func startParsing() {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      guard let parser = XMLParser(contentsOf: self.fileURL) else {
        let error = NSError(domain: "GooseHealthKitXMLParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize XMLParser"])
        self.delegate?.parser(self, didFailWithError: error)
        return
      }
      
      parser.delegate = self
      
      if parser.parse() {
        if !self.currentBatch.isEmpty {
          self.delegate?.parser(self, didParseBatch: self.currentBatch)
          self.currentBatch.removeAll()
        }
        self.delegate?.parserDidFinish(self)
      } else if let error = parser.parserError {
        self.delegate?.parser(self, didFailWithError: error)
      }
    }
  }

  // MARK: - XMLParserDelegate

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String : String] = [:]
  ) {
    guard elementName == "Record",
          let type = attributeDict["type"],
          relevantTypes.contains(type),
          let startDateString = attributeDict["startDate"],
          let endDateString = attributeDict["endDate"],
          let value = attributeDict["value"] else {
      return
    }

    guard let startDate = dateFormatter.date(from: startDateString),
          let endDate = dateFormatter.date(from: endDateString) else {
      return
    }

    let record = ParsedXMLHealthRecord(
      type: type,
      startDate: startDate,
      endDate: endDate,
      value: value,
      unit: attributeDict["unit"]
    )
    
    currentBatch.append(record)

    if currentBatch.count >= batchSize {
      let batchToYield = currentBatch
      currentBatch.removeAll(keepingCapacity: true)
      
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.delegate?.parser(self, didParseBatch: batchToYield)
      }
    }
  }
}
