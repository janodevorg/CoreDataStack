import OSLog

/**
 Usage:
 ```
 let log = LoggerFactory.coredata.logger()
 log.debug("A message")
 ```
 */
enum LoggerFactory: String {
    case coredata

    /// Returns a Logger instance whose category is the classname.
    func logger(classname: String = #fileID) -> Logger {
        let className = classname.components(separatedBy: ".")
            .last?.components(separatedBy: "/")
            .last?.replacingOccurrences(of: "swift", with: "")
            .trimmingCharacters(in: .punctuationCharacters) ?? ""
        return Logger(subsystem: rawValue, category: className)
    }
}
