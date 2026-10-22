import Foundation
import os

/// 诊断日志（对应原版 Diagnostic Logging）
enum MPTLog {
    static let os = OSLog(subsystem: "com.qingyao.moneyprinterturbo", category: "mpt")

    static func info(_ msg: String) { os_log("%{public}@", log: os, OSLogType.info, msg) }
    static func error(_ msg: String) { os_log("%{public}@", log: os, OSLogType.error, msg) }
}
