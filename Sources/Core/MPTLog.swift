import Foundation
import os

/// 诊断日志（对应原版 Diagnostic Logging）
enum MPTLog {
    static func info(_ msg: String) { NSLog("[MPT][INFO] %@", msg) }
    static func error(_ msg: String) { NSLog("[MPT][ERROR] %@", msg) }
}
