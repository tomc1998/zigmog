const glfw = @import("../c.zig").glfw;

pub const Renderer = struct {
    /// Render the state to the given gl w / h
    fn render(self: *const Renderer, w: f32, h: f32) void {
        glfw.glBegin(glfw.GL_TRIANGLES);
        glfw.glVertex2f(0.0,0.0);
        glfw.glVertex2f(  w,0.0);
        glfw.glVertex2f(  w,  h);
        glfw.glEnd();
    }
};
