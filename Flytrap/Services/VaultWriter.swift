// Zoidberg/Services/VaultWriter.swift
import Foundation

enum VaultWriterError: Error, LocalizedError {
    case vaultPathNotFound(String)
    case vaultNotWritable(String)
    case mediaFileMissing(String)

    var errorDescription: String? {
        switch self {
        case .vaultPathNotFound(let path): return "Vault path not found: \(path)"
        case .vaultNotWritable(let path): return "Vault path not writable: \(path)"
        case .mediaFileMissing(let path): return "Media file not found: \(path)"
        }
    }
}

struct SaveResult {
    let filePath: String
}

final class VaultWriter {
    let vaultPath: String
    private let fm = FileManager.default

    init(vaultPath: String) {
        self.vaultPath = vaultPath
    }

    func validate() throws {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: vaultPath, isDirectory: &isDir), isDir.boolValue else {
            throw VaultWriterError.vaultPathNotFound(vaultPath)
        }
        guard fm.isWritableFile(atPath: vaultPath) else {
            throw VaultWriterError.vaultNotWritable(vaultPath)
        }
    }

    func save(session: CaptureSession, title: String?, folder: String?) throws -> SaveResult {
        try validate()
        let targetFolder = folder ?? "Captures"
        let folderPath = (vaultPath as NSString).appendingPathComponent(targetFolder)
        try fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        let filename: String
        if let title = title {
            filename = sanitizeFilename(title) + ".md"
        } else {
            filename = session.fallbackFilename()
        }
        let filePath = (folderPath as NSString).appendingPathComponent(filename)
        if !session.allMediaFiles.isEmpty {
            let attachmentsPath = (folderPath as NSString).appendingPathComponent("attachments")
            try fm.createDirectory(atPath: attachmentsPath, withIntermediateDirectories: true)
            for media in session.allMediaFiles {
                let dest = (attachmentsPath as NSString).appendingPathComponent(media.filename)
                if fm.fileExists(atPath: media.sourcePath) {
                    try? fm.removeItem(atPath: dest)
                    try fm.copyItem(atPath: media.sourcePath, toPath: dest)
                }
            }
        }
        let entry = session.toMarkdown(title: title)
        if fm.fileExists(atPath: filePath) {
            // Append a separator and the new entry
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
            handle.seekToEndOfFile()
            handle.write(("\n---\n\n" + entry).data(using: .utf8)!)
            handle.closeFile()
        } else {
            // New daily file: date heading + first entry
            let header = session.dailyHeading() + "\n\n"
            try (header + entry).write(toFile: filePath, atomically: true, encoding: .utf8)
        }
        return SaveResult(filePath: filePath)
    }

    func moveToEnhancedLocation(from originalPath: String, enhancedMarkdown: String, title: String, folder: String) throws -> String {
        let folderPath = (vaultPath as NSString).appendingPathComponent(folder)
        try fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        let filename = sanitizeFilename(title) + ".md"
        let finalPath = (folderPath as NSString).appendingPathComponent(filename)
        let tempPath = finalPath + ".tmp"
        try enhancedMarkdown.write(toFile: tempPath, atomically: true, encoding: .utf8)
        try? fm.removeItem(atPath: finalPath)
        try fm.moveItem(atPath: tempPath, toPath: finalPath)
        let originalAttachments = ((originalPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent("attachments")
        if fm.fileExists(atPath: originalAttachments) {
            let newAttachments = (folderPath as NSString).appendingPathComponent("attachments")
            try fm.createDirectory(atPath: newAttachments, withIntermediateDirectories: true)
            if let files = try? fm.contentsOfDirectory(atPath: originalAttachments) {
                for file in files {
                    let src = (originalAttachments as NSString).appendingPathComponent(file)
                    let dst = (newAttachments as NSString).appendingPathComponent(file)
                    try? fm.removeItem(atPath: dst)
                    try fm.moveItem(atPath: src, toPath: dst)
                }
            }
        }
        try? fm.removeItem(atPath: originalPath)
        return finalPath
    }

    private func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "-")
    }
}
