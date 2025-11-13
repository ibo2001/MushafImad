//
//  AppLogger.swift
//  MushafImad
//
//  A lightweight, efficient, and pretty logging system.
//  - Uses Apple's os.Logger for performance and signpost integration
//  - Pretty, colorized console output (DEBUG builds)
//  - Optional file logging with simple rotation by size
//

import Foundation
import os

public enum LogLevel: Int, Comparable, CaseIterable {
    case trace = 0
    case debug
    case info
    case notice
    case warning
    case error
    case critical

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var emoji: String {
        switch self {
        case .trace: return "🟣"
        case .debug: return "🔵"
        case .info: return "🟢"
        case .notice: return "🟤"
        case .warning: return "🟡"
        case .error: return "🔴"
        case .critical: return "🛑"
        }
    }

    var name: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    // Intentionally avoid depending on Logger.Level for broader SDK compatibility
}

public enum LogCategory: String, CaseIterable {
    case app = "APP"
    case ui = "UI"
    case audio = "AUDIO"
    case network = "NET"
    case database = "DB"
    case download = "DL"
    case timing = "TIMING"
    case realm = "REALM"
    case images = "IMAGES"
    case mushaf = "MUSHAF"
}

/// Pretty wrapper around `os.Logger` with optional colored console output and file logging.
public struct AppLogger: @unchecked Sendable {
    nonisolated(unsafe) public static var shared = AppLogger()

    private let subsystem: String = Bundle.main.bundleIdentifier
        ?? Bundle.mushafResources.bundleIdentifier
        ?? "MushafImad"
    private var isEnabled: Bool = true
    private var minimumLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()
    private var enableColors: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    private var enableFileLogging: Bool = false
    private var maxFileSizeKB: Int = 512

    private var fileURL: URL? = nil
    private var osLoggers: [LogCategory: Logger] = [:]
    private let fileQueue = DispatchQueue(label: "AppLogger.file.queue", qos: .utility)

    public init() {}

    // MARK: - Configuration
    public mutating func configure(
        enabled: Bool? = nil,
        minLevel: LogLevel? = nil,
        enableColors: Bool? = nil,
        enableFileLogging: Bool? = nil,
        maxFileSizeKB: Int? = nil
    ) {
        if let enabled { self.isEnabled = enabled }
        if let minLevel { self.minimumLevel = minLevel }
        if let enableColors { self.enableColors = enableColors }
        if let enableFileLogging { self.enableFileLogging = enableFileLogging }
        if let maxFileSizeKB { self.maxFileSizeKB = maxFileSizeKB }

        if self.enableFileLogging {
            prepareLogFileIfNeeded()
        }
    }

    // MARK: - Public API
    public func trace(_ message: @autoclosure () -> String, category: LogCategory = .app,
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .trace, category: category, file: file, function: function, line: line)
    }

    public func debug(_ message: @autoclosure () -> String, category: LogCategory = .app,
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .debug, category: category, file: file, function: function, line: line)
    }

    public func info(_ message: @autoclosure () -> String, category: LogCategory = .app,
                     file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .info, category: category, file: file, function: function, line: line)
    }

    public func notice(_ message: @autoclosure () -> String, category: LogCategory = .app,
                       file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .notice, category: category, file: file, function: function, line: line)
    }

    public func warn(_ message: @autoclosure () -> String, category: LogCategory = .app,
                     file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .warning, category: category, file: file, function: function, line: line)
    }

    public func error(_ message: @autoclosure () -> String, category: LogCategory = .app,
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .error, category: category, file: file, function: function, line: line)
    }

    public func critical(_ message: @autoclosure () -> String, category: LogCategory = .app,
                         file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message(), level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Core
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        category: LogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        guard level >= minimumLevel else { return }

        let text = message()
        let formatted = formattedMessage(level: level, category: category, message: text, file: file, function: function, line: line)

        // Console (pretty)
        print(formatted)

        // OSLog (efficient, structured)
        let osLogger = logger(for: category)
        switch level {
        case .trace, .debug:
            osLogger.debug("\(text, privacy: .public)")
        case .info:
            osLogger.info("\(text, privacy: .public)")
        case .notice:
            osLogger.notice("\(text, privacy: .public)")
        case .warning:
            osLogger.warning("\(text, privacy: .public)")
        case .error:
            osLogger.error("\(text, privacy: .public)")
        case .critical:
            osLogger.critical("\(text, privacy: .public)")
        }

        // File logging (optional)
        if enableFileLogging {
            writeToFile(formatted: formatted)
        }
    }

    // MARK: - Internals
    private func logger(for category: LogCategory) -> Logger {
        if let existing = osLoggers[category] { return existing }
        var new = osLoggers
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        new[category] = logger
        // Workaround for struct mutability: rebuild via shared
        AppLogger.shared.osLoggers = new
        return logger
    }

    private func formattedMessage(level: LogLevel, category: LogCategory, message: String, file: String, function: String, line: Int) -> String {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let thread = Thread.isMainThread ? "main" : (Thread.current.name ?? "bg")
        let fileName = (file as NSString).lastPathComponent
        let base = "\(level.emoji) [\(level.name)] [\(category.rawValue)] \(timestamp) [\(thread)] \(fileName):\(line) \(function) — \(message)"
        guard enableColors else { return base }
        return colorize(base, level: level)
    }

    private func colorize(_ text: String, level: LogLevel) -> String {
        // ANSI color codes for Xcode console
        let reset = "\u{001B}[0m"
        let color: String
        switch level {
        case .trace: color = "\u{001B}[35m" // magenta
        case .debug: color = "\u{001B}[34m" // blue
        case .info: color = "\u{001B}[32m" // green
        case .notice: color = "\u{001B}[36m" // cyan
        case .warning: color = "\u{001B}[33m" // yellow
        case .error: color = "\u{001B}[31m" // red
        case .critical: color = "\u{001B}[1;31m" // bright red
        }
        return "\(color)\(text)\(reset)"
    }

    private mutating func prepareLogFileIfNeeded() {
        guard fileURL == nil else { return }
        do {
            let fm = FileManager.default
            let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Logs", isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let url = dir.appendingPathComponent("app.log")
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            fileURL = url
        } catch {
            // If file prep fails, silently disable file logging to avoid crashes in production
            enableFileLogging = false
        }
    }

    private func writeToFile(formatted: String) {
        guard let url = fileURL else { return }
        fileQueue.async {
            do {
                let data = (formatted + "\n").data(using: .utf8) ?? Data()
                if let handle = try? FileHandle(forWritingTo: url) {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: url, options: .atomic)
                }
                try rotateIfNeeded(url: url)
            } catch {
                // Ignore file logging errors in runtime
            }
        }
    }

    private func rotateIfNeeded(url: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? NSNumber {
            let sizeKB = size.intValue / 1024
            if sizeKB > maxFileSizeKB {
                try? FileManager.default.removeItem(at: url)
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
        }
    }

    // MARK: - Utilities
    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}


