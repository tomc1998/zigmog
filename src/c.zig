pub const glfw = @cImport({
    @cDefine("GLFW_DLL", "");
    @cInclude("GLFW/glfw3.h");
});
