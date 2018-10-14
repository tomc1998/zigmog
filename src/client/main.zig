const std = @import("std");
const enet = @import("../enet.zig");
const Renderer = @import("renderer.zig").Renderer;
const glfw = @import("../c.zig").glfw;
const state = @import("state.zig");
const ECS = @import("ecs").ECS;

var client : *enet.ENetHost = undefined;

var serverAddress : enet.ENetAddress = undefined;
var server : *enet.ENetPeer = undefined;

fn initWindow() *glfw.GLFWwindow {
    _ = glfw.glfwInit();
    const window = glfw.glfwCreateWindow(800, 600, c"Zigmog", null, null).?;
    glfw.glfwMakeContextCurrent(window);
    return window;
}

const NetError = error {
    ServerDisconnected,
};

pub fn connectToServer() NetError!void {
    // Setup enet socket
    if (enet.enet_initialize() != 0) { std.debug.warn("Failed to initialize enet.\n"); }
    const clientPtr = enet.enet_host_create(null, 1, 2, 0, 0);
    client = &(clientPtr orelse {
        std.debug.warn("Failed to create enet host.\n");
        return 1;
    })[0];

    // Connect to the server
    _ = enet.enet_address_set_host(@ptrCast(?[*]enet.ENetAddress, &serverAddress),
                                   c"127.0.0.1");
    serverAddress.port = 1234;
    const serverPtr = enet.enet_host_connect(@ptrCast(?[*]enet.ENetHost, client),
                                             @ptrCast([*]enet.ENetAddress, &serverAddress), 2, 0);
    server = &(serverPtr orelse {
        std.debug.warn("Failed to connect to server.\n");
        NetError.ConnectError;
    })[0];

    // Wait for connection to complete (5 seconds timeout)
    var event : enet.ENetEvent = undefined;
    if (enet.enet_host_service(@ptrCast(?[*]enet.ENetHost, client),
                               @ptrCast(?[*]enet.ENetEvent, &event), 5000) > 0
            and event.type == enet.ENetEventType.ENET_EVENT_TYPE_CONNECT) {
        std.debug.warn("Connected to server.\n");
    } else if (event.type == enet.ENetEventType.ENET_EVENT_TYPE_NONE) {
        std.debug.warn("Timeout connecting to server.\n");
        return NetError.ConnectTimeout;
    } else {
        std.debug.warn("Unknown error: {}", event);
        return 1;
    }
}

pub fn pollEnet() NetError!void {
    while (enet.enet_host_service(@ptrCast(?[*]enet.ENetHost, client),
                                  @ptrCast(?[*]enet.ENetEvent, &event),
                                  0) > 0) {
        switch (event.type) {
            enet.ENetEventType.ENET_EVENT_TYPE_RECEIVE => {
                std.debug.warn(
                    "A packet of length {} containing {} was received on channel {}.\n",
                    event.packet.?[0].dataLength,
                    event.packet.?[0].data.?[0..event.packet.?[0].dataLength],
                    event.channelID);
                // Clean up the packet now that we're done using it.
                enet.enet_packet_destroy (event.packet);
            },
            enet.ENetEventType.ENET_EVENT_TYPE_DISCONNECT => {
                std.debug.warn("Server disconnected.\n");
                return NetError.ServerDisconnected;
            },
            else => {
                std.debug.warn("Unexpected event: {}\n", event);
            }
        }
    }
}

pub fn main() !void {
    const window = initWindow();
    const game_state = state.State {
        .ecs = try ECS.init(std.debug.global_allocator),
    };
    const renderer = Renderer {};

    while (!@bitCast(bool, @intCast(u8, glfw.glfwWindowShouldClose(window)))) {
        // Poll for responses
        glfw.glClear(glfw.GL_COLOR_BUFFER_BIT);
        renderer.render(1.0, 1.0);
        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}
