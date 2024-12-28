import Testing
import CoreData
@testable import CoreDataStack

@Suite("Database Wipe Tests", .serialized)
final class DatabaseWipeTests {
    class MockFileOperations: FileOperations {
        var existingFiles: Set<String> = []
        var copiedFiles: [(from: URL, to: URL)] = []
        var deletedFiles: [URL] = []

        func fileExists(atPath path: String) -> Bool {
            existingFiles.contains(path)
        }

        func removeItem(at url: URL) throws {
            deletedFiles.append(url)
            existingFiles.remove(url.path)
        }

        func copyItem(at srcURL: URL, to dstURL: URL) throws {
            copiedFiles.append((srcURL, dstURL))
            existingFiles.insert(dstURL.path)
        }
    }

    @Test("Test database wipe with backup", arguments: BackupDirectory.allCases)
    func testWipeDatabaseWithBackup(backupDir: BackupDirectory) throws {
        // Setup
        let mockFileOps = MockFileOperations()
        // Feb 13, 2009 23:04:50 GMT
        let testDate = Date(timeIntervalSince1970: 1234567890)

        let string = DateFormatter()
            .configure {
                $0.dateFormat = "yyyy-MM-dd'T'HHmmss"
                $0.timeZone = TimeZone(secondsFromGMT: 0)
                $0.locale = Locale(identifier: "en_US_POSIX")
            }
            .string(from: testDate)
        print(string)

        let container = EntityContainer(
            name: "Model",
            isInMemoryStore: true,
            bundle: Bundle.module
        )
        container.fileOperations = mockFileOps
        container.currentDate = { testDate }
        container.backupDirectory = backupDir.url

        // Add existing database file
        let dbPath = backupDir.url.appendingPathComponent("Model.sqlite").path
        mockFileOps.existingFiles.insert(dbPath)

        // Execute
        let backupURL = try container.wipeSQLDatabase(backupFirst: true)

        // Verify backup was created
        #expect(backupURL != nil)
        #expect(mockFileOps.deletedFiles.count == 1)
        #expect(mockFileOps.copiedFiles.count == 1)

        // Verify paths
        let expectedBackupPath = dbPath + ".backup-2009-02-13T233130"
        #expect(backupURL?.path == expectedBackupPath)

        #expect(!mockFileOps.fileExists(atPath: dbPath))
        #expect(mockFileOps.fileExists(atPath: expectedBackupPath))

        // Verify copy operation details
        #expect(mockFileOps.copiedFiles.first?.from.path == dbPath)
        #expect(mockFileOps.copiedFiles.first?.to.path == expectedBackupPath)
    }

    @Test("Test database wipe without backup")
    func testWipeDatabaseWithoutBackup() throws {
        // Setup
        let mockFileOps = MockFileOperations()
        let backupDir = URL(fileURLWithPath: "/test/backup")

        let container = EntityContainer(name: "Model", isInMemoryStore: true, bundle: Bundle.module)
        container.fileOperations = mockFileOps
        container.backupDirectory = backupDir

        // Add existing database file
        let dbPath = backupDir.appendingPathComponent("Model.sqlite").path
        mockFileOps.existingFiles.insert(dbPath)

        // Execute
        let backupURL = try container.wipeSQLDatabase(backupFirst: false)

        // Verify
        #expect(backupURL == nil)
        #expect(mockFileOps.deletedFiles.count == 1)
        #expect(mockFileOps.copiedFiles.isEmpty)
        #expect(!mockFileOps.fileExists(atPath: dbPath))
    }
}
