// Yeni dosya: ZipArchive+Extension.swift
import Foundation
import Compression

extension FileManager {
    func zipFiles(at urls: [URL], to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(writingItemAt: destinationURL, options: .forReplacing, error: &error) { (zipURL) in
            do {
                let archive = try FileWrapper(directoryWithFileWrappers: [:])
                
                for url in urls {
                    let fileName = url.lastPathComponent
                    if let data = try? Data(contentsOf: url) {
                        let fileWrapper = FileWrapper(regularFileWithContents: data)
                        fileWrapper.preferredFilename = fileName
                        archive.addFileWrapper(fileWrapper)
                    }
                }
                
                try archive.write(to: zipURL, options: .atomic, originalContentsURL: nil)
            } catch {
                print("ZIP oluşturma hatası: \(error)")
            }
        }
        
        if let error = error {
            throw error
        }
    }
}
