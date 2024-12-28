import Foundation

public enum FileError: Error, LocalizedError
{
    case missingFilename(String)
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .missingFilename(let filename):
            return "Missing file with name: \(filename)"
        case .unreadable(let URL):
            return "File missing at URL: \(URL)"
        }
    }
}
