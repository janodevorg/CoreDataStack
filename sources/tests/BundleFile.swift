import Foundation

/**
 Reads a file from a bundle.
*/
public struct BundleFile
{
    public let filename: String
    private let bundle: Bundle

    /**
     Reads a file from a bundle.

     What you should pass as bundle parameter:

     - If the file is in a Xcode project use `Bundle.main` or `Bundle(identifier:)`.
     - If the file is in a SPM package use `Bundle.module`.

     However,
     - if this class is used from a unit test,
     - and the file is in the target under test,

     you will have to expose the `Bundle.module` of the target under test writing a class like this
     inside the target:
     ```
     public enum BundleReference {
         public static let bundle = Bundle.module
     }
     ```

     Note that writing `Bundle(of: ClassUnderTest.self)` will not give you the bundle of the target
     under test.

     - Parameters:
       - filename: Filename including extension, e.g. `file.txt`.
       - bundle: Bundle of the target containing the file.
    */
    public init(filename: String, bundle: Bundle) {
        self.filename = filename
        self.bundle = bundle
    }

    /**
     Returns the file as string.
     - Throws: FileError if the file is missing or unreadable.
     */
    public var string: String {
        get throws {
            let fileURL = try url
            do {
                return try String(contentsOf: fileURL)
            } catch {
                throw FileError.unreadable(fileURL)
            }
        }
    }

    /**
     Returns the file as Data.
     - Throws: FileError if the file is missing or unreadable.
     */
    public var data: Data {
        get throws {
            let fileURL = try url
            do {
                return try Data(contentsOf: fileURL)
            } catch {
                throw FileError.unreadable(fileURL)
            }
        }
    }

    /**
     Returns a URL that points to an existing file at the moment of executing this method.
     - Throws FileError if the file is missing or it is a directory.
     */
    public var url: URL {
        get throws {
            guard let fileURL = bundle.url(forResource: filename, withExtension: nil) else {
                throw FileError.missingFilename(filename)
            }
            return fileURL
        }
    }
}
