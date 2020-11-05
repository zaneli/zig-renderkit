const std = @import("std");
usingnamespace @import("gl_decls.zig");
usingnamespace @import("../descriptions.zig");

pub const Image = *GLImage;

pub const GLImage = struct {
    tid: GLuint,
    width: i32,
    height: i32,
};

pub fn createImage(desc: ImageDesc) Image {
    var img = @ptrCast(*GLImage, @alignCast(@alignOf(*GLImage), std.c.malloc(@sizeOf(GLImage)).?));
    img.* = std.mem.zeroes(GLImage);
    img.width = desc.width;
    img.height = desc.height;

    if (desc.pixel_format == .depth_stencil) {
        std.debug.assert(desc.usage == .immutable);
        glGenRenderbuffers(1, &img.tid);
        glBindRenderbuffer(GL_RENDERBUFFER, img.tid);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, desc.width, desc.height);
    } else if (desc.pixel_format == .stencil) {
        std.debug.assert(desc.usage == .immutable);
        glGenRenderbuffers(1, &img.tid);
        glBindRenderbuffer(GL_RENDERBUFFER, img.tid);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, desc.width, desc.height);
    } else {
        std.debug.assert(!desc.render_target);
        glGenTextures(1, &img.tid);
        glBindTexture(GL_TEXTURE_2D, img.tid);

        const wrap_u: GLint = if (desc.wrap_u == .clamp) GL_CLAMP_TO_EDGE else GL_REPEAT;
        const wrap_v: GLint = if (desc.wrap_v == .clamp) GL_CLAMP_TO_EDGE else GL_REPEAT;
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap_u);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap_v);

        const filter_min: GLint = if (desc.min_filter == .nearest) GL_NEAREST else GL_LINEAR;
        const filter_mag: GLint = if (desc.mag_filter == .nearest) GL_NEAREST else GL_LINEAR;
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter_min);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter_mag);

        if (desc.content) |content| {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, desc.width, desc.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, content.ptr);
        }

        glBindTexture(GL_TEXTURE_2D, 0);
    }

    return img;
}

pub fn destroyImage(image: Image) void {
    glDeleteTextures(1, &image.tid);
    std.c.free(image);
}

pub fn updateImage(comptime T: type, image: Image, content: []const T) void {
    std.debug.assert(@sizeOf(T) == image.width * image.height);
    glBindTexture(GL_TEXTURE_2D, image.tid);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, image.width, image.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, content.ptr);
    // glBindTexture(GL_TEXTURE_2D, 0);
}