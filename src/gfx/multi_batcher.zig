const std = @import("std");
const gfx = @import("gfx.zig");
const math = gfx.math;

const IndexBuffer = gfx.IndexBuffer;
const VertexBuffer = gfx.VertexBuffer;

pub const MultiVertex = extern struct {
    pos: math.Vec2,
    uv: math.Vec2 = .{ .x = 0, .y = 0 },
    col: u32 = 0xFFFFFFFF,
    tid: f32 = 0,
};

pub const MultiBatcher = struct {
    mesh: gfx.DynamicMesh(MultiVertex, u16),
    vert_index: usize = 0, // current index into the vertex array
    texture: gfx.TextureId = std.math.maxInt(gfx.TextureId),
    textures: [8]gfx.TextureId = undefined,
    last_texture: usize = 0,

    pub fn init(allocator: *std.mem.Allocator, max_sprites: usize) MultiBatcher {
        if (max_sprites * 6 > std.math.maxInt(u16)) @panic("max_sprites exceeds u16 index buffer size");

        var indices = allocator.alloc(u16, max_sprites * 6) catch unreachable;
        var i: usize = 0;
        while (i < max_sprites) : (i += 1) {
            indices[i * 3 * 2 + 0] = @intCast(u16, i) * 4 + 0;
            indices[i * 3 * 2 + 1] = @intCast(u16, i) * 4 + 1;
            indices[i * 3 * 2 + 2] = @intCast(u16, i) * 4 + 2;
            indices[i * 3 * 2 + 3] = @intCast(u16, i) * 4 + 0;
            indices[i * 3 * 2 + 4] = @intCast(u16, i) * 4 + 2;
            indices[i * 3 * 2 + 5] = @intCast(u16, i) * 4 + 3;
        }

        return .{
            .mesh = gfx.DynamicMesh(MultiVertex, u16).init(allocator, max_sprites * 4, indices) catch unreachable,
            .textures = [_]gfx.TextureId{0} ** 8,
        };
    }

    pub fn deinit(self: *MultiBatcher) void {
        self.mesh.deinit();
    }

    pub fn begin(self: *MultiBatcher) void {
        self.vert_index = 0;
    }

    pub fn end(self: *MultiBatcher) void {
        self.flush();
    }

    pub fn flush(self: *MultiBatcher) void {
        if (self.vert_index == 0) return;

        // send data to gpu
        self.mesh.updateVertSlice(0, self.vert_index);

        // bind textures
        for (self.textures) |tid, i| {
            if (i == self.last_texture) break;
            self.mesh.bindings.bindTexture(tid, @intCast(c_uint, i));
        }

        // draw
        const quads = self.vert_index / 4;
        self.mesh.draw(@intCast(c_int, quads * 6));

        // reset state
        for (self.textures) |*tid, i| {
            if (i == self.last_texture) break;
            self.mesh.bindings.bindTexture(0, @intCast(c_uint, i));
            tid.* = 0;
        }

        self.vert_index = 0;
        self.last_texture = 0;
    }

    inline fn submitTexture(self: *MultiBatcher, tid: gfx.TextureId) f32 {
        if (std.mem.indexOfScalar(gfx.TextureId, &self.textures, tid)) |index| return @intToFloat(f32, index);

        self.textures[self.last_texture] = tid;
        self.last_texture += 1;
        return @intToFloat(f32, self.last_texture - 1);
    }

    pub fn drawTex(self: *MultiBatcher, pos: math.Vec2, col: u32, texture: gfx.Texture) void {
        if (self.vert_index >= self.mesh.verts.len) {
            self.flush();
        }

        const tid = self.submitTexture(texture.id);

        var verts = self.mesh.verts[self.vert_index .. self.vert_index + 4];
        verts[0].pos = pos; // bl
        verts[0].uv = .{ .x = 0, .y = 1 };
        verts[0].col = col;
        verts[0].tid = tid;

        verts[1].pos = .{ .x = pos.x + texture.width, .y = pos.y }; // br
        verts[1].uv = .{ .x = 1, .y = 1 };
        verts[1].col = col;
        verts[1].tid = tid;

        verts[2].pos = .{ .x = pos.x + texture.width, .y = pos.y + texture.height }; // tr
        verts[2].uv = .{ .x = 1, .y = 0 };
        verts[2].col = col;
        verts[2].tid = tid;

        verts[3].pos = .{ .x = pos.x, .y = pos.y + texture.height }; // tl
        verts[3].uv = .{ .x = 0, .y = 0 };
        verts[3].col = col;
        verts[3].tid = tid;

        self.vert_index += 4;
    }
};
