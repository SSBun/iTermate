import Darwin
import Foundation

/// Observes venom-cli debug builds from startup without changing command lifecycle state.
enum VenomDebugMonitor {
    /// Returns terminal TTYs whose foreground process tree contains a live debug build.
    static func monitoringTTYs(in ttys: Set<String>) -> Set<String> {
        Set(ttys.filter { tty in
            guard tty.hasPrefix("/dev/tty"), tty.count > 8, tty.count <= 128,
                  !tty.dropFirst(5).contains("/") else { return false }
            var attributes = stat()
            guard stat(tty, &attributes) == 0,
                  attributes.st_mode & S_IFMT == S_IFCHR else { return false }
            var visited: Set<pid_t> = []
            return processIDs(type: UInt32(PROC_TTY_ONLY), value: UInt32(bitPattern: attributes.st_rdev))
                .contains { pid in
                    guard let root = processInfo(pid),
                          root.pbi_uid == getuid(),
                          root.pbi_pgid == root.e_tpgid,
                          root.e_tdev == UInt32(bitPattern: attributes.st_rdev),
                          hasMonitoringDescendant(root, depth: 0, visited: &visited),
                          let current = processInfo(pid) else { return false }
                    return sameProcess(root, current) && current.pbi_pgid == current.e_tpgid
                }
        })
    }

    private static func hasMonitoringDescendant(
        _ parent: proc_bsdinfo,
        depth: Int,
        visited: inout Set<pid_t>
    ) -> Bool {
        let pid = pid_t(parent.pbi_pid)
        guard depth <= 8, visited.count < 128, visited.insert(pid).inserted else { return false }
        let children = processIDs(type: UInt32(PROC_PPID_ONLY), value: parent.pbi_pid).compactMap { childPID -> proc_bsdinfo? in
            guard let child = processInfo(childPID), child.pbi_ppid == parent.pbi_pid,
                  child.pbi_uid == parent.pbi_uid else { return nil }
            return child
        }
        var found = false
        if parent.pbi_pgid == parent.e_tpgid,
           let parentArguments = arguments(of: pid),
           debugBuildRunsApp(parentArguments) != nil {
            // Build/install/rebuild phases precede (or temporarily stop) log capture.
            found = true
        }
        if !found {
            // Terminal wrappers (for example kiro-cli-term) can give their shell a nested PTY.
            // Follow real parentage, not TTY-number proximity or session titles.
            found = children.contains { hasMonitoringDescendant($0, depth: depth + 1, visited: &visited) }
        }
        guard found, let current = processInfo(pid) else { return false }
        return sameProcess(parent, current)
    }

    /// Nil means this is not a supported debug build; the value records the --run flag.
    static func debugBuildRunsApp(_ arguments: [String]) -> Bool? {
        guard let executable = arguments.first else { return nil }
        let name = URL(fileURLWithPath: executable).lastPathComponent
        var index = 1
        if name == "node" || name == "nodejs" {
            guard arguments.count > 1,
                  ["venom-cli", "venom-cli.js"].contains(
                    URL(fileURLWithPath: arguments[1]).lastPathComponent
                  ) else { return nil }
            index = 2
        } else if name != "venom-cli" {
            return nil
        }
        var foundBuild = false
        var debug = false
        var run = false
        while index < arguments.count {
            let argument = arguments[index]
            let option = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument
            let valueOptions = foundBuild
                ? ["-p", "--project", "--scheme", "--variant", "--app-id", "--device"]
                : ["-p", "--project"]
            if valueOptions.contains(option) {
                if !argument.contains("=") {
                    index += 1
                    guard index < arguments.count else { return nil }
                }
            } else if argument == "build", !foundBuild {
                foundBuild = true
            } else if foundBuild, argument == "--debug" {
                debug = true
            } else if foundBuild, argument == "--run" {
                run = true
            } else if foundBuild, ["--verbose", "--reconnect"].contains(argument) {
                // These flags do not change debug-build recognition.
            } else {
                return nil
            }
            index += 1
        }
        return foundBuild && debug ? run : nil
    }

    private static func processIDs(type: UInt32, value: UInt32) -> [pid_t] {
        let requiredBytes = proc_listpids(type, value, nil, 0)
        guard requiredBytes > 0 else { return [] }
        // Allow room for processes created between the sizing and reading calls.
        var pids = [pid_t](repeating: 0, count: Int(requiredBytes) / MemoryLayout<pid_t>.size + 16)
        let capacity = pids.count * MemoryLayout<pid_t>.size
        let bytes = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(type, value, buffer.baseAddress, Int32(capacity))
        }
        guard bytes > 0, bytes < capacity else { return [] }
        return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    private static func processInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size,
              info.pbi_status != SZOMB, info.pbi_status != SSTOP else { return nil }
        return info
    }

    private static func sameProcess(_ first: proc_bsdinfo, _ second: proc_bsdinfo) -> Bool {
        first.pbi_pid == second.pbi_pid && first.pbi_ppid == second.pbi_ppid
            && first.pbi_start_tvsec == second.pbi_start_tvsec
            && first.pbi_start_tvusec == second.pbi_start_tvusec
    }

    private static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size, size <= 1_048_576 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes { buffer in
            sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0, size > MemoryLayout<Int32>.size else { return nil }
        let count = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard count > 0, count <= 4096 else { return nil }
        var index = MemoryLayout<Int32>.size
        // KERN_PROCARGS2 stores argc, executable path, padding, argv, then environment.
        while index < size, bytes[index] != 0 { index += 1 }
        while index < size, bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        for _ in 0..<count {
            let start = index
            while index < size, bytes[index] != 0 { index += 1 }
            guard index < size,
                  let argument = String(bytes: bytes[start..<index], encoding: .utf8) else { return nil }
            arguments.append(argument)
            index += 1
        }
        return arguments
    }
}
