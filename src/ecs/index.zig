const std = @import("std");
const ArrayList = std.ArrayList;

/// The type of component storage, different storages give different performance
/// characteristics
pub const CompStorageType = enum {
    /// A contiguous array, very fast for looping, O(n) search time
    Array,
};

pub fn CompStorage(comptime storage_type : CompStorageType, comptime data_type: type) type {
    return switch (storage_type) {
        CompStorageType.Array => struct {
            const Storage = ArrayList(data_type);
            data: Storage,
            pub fn init(alloc: *std.mem.Allocator) !@This() {
                var data = Storage.init(alloc);
                try data.ensureCapacity(128);
                return @This() {
                    .data = data,
                };
            }
        },
    };
}

pub const CompPos = struct {
    const Storage = CompStorage(CompStorageType.Array, @This());
    x: f32,
    y: f32,
};

pub const ECS = struct {
    pos: CompPos.Storage,
    pub fn init(alloc: *std.mem.Allocator) !ECS {
        return ECS {
            .pos = try CompPos.Storage.init(alloc),
        };
    }
};
