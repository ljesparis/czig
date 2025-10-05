const std = @import("std");

const c = @cImport({
    @cInclude("mach/mach.h");
});

const CPU_STATE_USER = c.CPU_STATE_USER;
const CPU_STATE_SYSTEM = c.CPU_STATE_SYSTEM;
const CPU_STATE_IDLE = c.CPU_STATE_IDLE;
const CPU_STATE_NICE = c.CPU_STATE_NICE;

const HOST_CPU_LOAD_INFO = c.HOST_CPU_LOAD_INFO;
const HOST_CPU_LOAD_INFO_COUNT = c.HOST_CPU_LOAD_INFO_COUNT;

const KERN_SUCCESS = c.KERN_SUCCESS;

const hostStatistics = c.host_statistics;
const machHostSelf = c.mach_host_self;

pub const CpuError = error{ErrorGettingStatistics};

const CpuStatistics = struct {
    cpu_state_user: u64 = 0,
    cpu_state_system: u64 = 0,
    cpu_state_idle: u64 = 0,
    cpu_state_nice: u64 = 0,

    const Self = @This();

    fn getHostStatistics() !c.host_cpu_load_info_data_t {
        var cpuinfo: c.host_cpu_load_info_data_t = undefined;
        const cpuinfo_ptr: [*]c_int = @ptrCast(&cpuinfo);
        var count: c_uint = HOST_CPU_LOAD_INFO_COUNT;
        const kr: c.kern_return_t = hostStatistics(machHostSelf(), HOST_CPU_LOAD_INFO, cpuinfo_ptr, &count);
        if (kr != KERN_SUCCESS) {
            return CpuError.ErrorGettingStatistics;
        }
        return cpuinfo;
    }

    pub fn printLastStatistics(self: *Self) !void {
        const cpuinfo: c.host_cpu_load_info_data_t = try getHostStatistics();

        const cpu_state_user = @as(u64, cpuinfo.cpu_ticks[CPU_STATE_USER]);
        const cpu_state_system = @as(u64, cpuinfo.cpu_ticks[CPU_STATE_SYSTEM]);
        const cpu_state_idle = @as(u64, cpuinfo.cpu_ticks[CPU_STATE_IDLE]);
        const cpu_state_nice = @as(u64, cpuinfo.cpu_ticks[CPU_STATE_NICE]);

        const cpu_state_user_diff = cpu_state_user - self.cpu_state_user;
        const cpu_state_system_diff = cpu_state_system - self.cpu_state_system;
        const cpu_state_idle_diff = cpu_state_idle - self.cpu_state_idle;
        const cpu_state_nice_diff = cpu_state_nice - self.cpu_state_nice;

        const total = cpu_state_user_diff + cpu_state_system_diff + cpu_state_idle_diff + cpu_state_nice_diff;

        self.cpu_state_user = cpu_state_user;
        self.cpu_state_system = cpu_state_system;
        self.cpu_state_idle = cpu_state_idle;
        self.cpu_state_nice = cpu_state_nice;

        const total_float = @as(f64, @floatFromInt(total));
        const user_usage = @as(f64, @floatFromInt(cpu_state_user_diff)) / total_float * 100.0;
        const system_usage = @as(f64, @floatFromInt(cpu_state_system_diff)) / total_float * 100.0;
        const inactive_usage = @as(f64, @floatFromInt(cpu_state_idle_diff + cpu_state_nice_diff)) / total_float * 100.0;

        std.debug.print("\rSystem: {d:.2}%, User: {d:.2}%, Inactive: {d:.2}%", .{ user_usage, system_usage, inactive_usage });
    }
};

pub fn main() !void {
    var cpuinfo: CpuStatistics = .{};

    while (true) {
        try cpuinfo.printLastStatistics();
        std.Thread.sleep(1_000_000_000);
    }
}
