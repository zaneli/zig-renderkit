const std = @import("std");
const backend = @import("backend");
const gfx = @import("../gfx.zig");
const math = aya.math;

pub const Mesh = struct {
    bindings: backend.BufferBindings,
    element_count: c_int,

    pub fn init(comptime VertT: type, verts: []VertT, comptime IndexT: type, indices: []IndexT) Mesh {
        var vbuffer = backend.createBuffer(VertT, .{
            .content = verts,
        });
        var ibuffer = backend.createBuffer(IndexT, .{
            .type = .index,
            .content = indices,
        });
        var bindings = backend.createBufferBindings(ibuffer, vbuffer);

        return .{
            .bindings = bindings,
            .element_count = @intCast(c_int, indices.len),
        };
    }

    pub fn deinit(self: Mesh) void {
        backend.destroyBufferBindings(self.bindings);
    }

    pub fn draw(self: Mesh) void {
        backend.drawBufferBindings(self.bindings, self.element_count);
    }
};

/// Contains a dynamic vert buffer and a slice of verts
pub fn DynamicMesh(comptime VertT: type, comptime IndexT: type) type {
    return struct {
        const Self = @This();

        bindings: gfx.BufferBindings,
        vertex_buffer: gfx.Buffer,
        verts: []VertT,
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator, vertex_count: usize, indices: []IndexT) !Self {
            var vertex_buffer = backend.createBuffer(VertT, .{
                .usage = .stream,
                .size = @intCast(c_long, vertex_count * @sizeOf(VertT)),
            });
            var ibuffer = backend.createBuffer(IndexT, .{
                .type = .index,
                .content = indices,
            });
            var bindings = backend.createBufferBindings(ibuffer, vertex_buffer);

            return Self{
                .bindings = bindings,
                .vertex_buffer = vertex_buffer,
                .verts = try allocator.alloc(VertT, vertex_count),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            // vertex_buffer is owned by BufferBindings so we dont deinit it here
            backend.destroyBufferBindings(self.bindings);
            self.allocator.free(self.verts);
        }

        pub fn updateAllVerts(self: *Self) void {
            backend.updateBuffer(VertT, self.vertex_buffer, self.verts);
        }

        /// uploads to the GPU the slice from start_index with num_verts
        pub fn updateVertSlice(self: *Self, start_index: usize, num_verts: usize) void {
            std.debug.assert(start_index + num_verts <= self.verts.len);
            const vert_slice = self.verts[start_index .. start_index + num_verts];
            backend.updateBuffer(VertT, self.vertex_buffer, vert_slice);
        }

        pub fn draw(self: Self, element_count: c_int) void {
            backend.drawBufferBindings(self.bindings, element_count);
        }

        pub fn drawAllVerts(self: Self) void {
            self.draw(@intCast(c_int, @divExact(self.verts.len, 4) * 6));
        }
    };
}