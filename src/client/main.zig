const std = @import("std");
const enet = @import("../enet.zig");
const c = @cImport({
    @cInclude("unistd.h");
});

var client : *enet.ENetHost = undefined;

var serverAddress : enet.ENetAddress = undefined;
var server : *enet.ENetPeer = undefined;

pub fn main() u8 {
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
        return 1;
    })[0];

    // Wait for connection to complete (5 seconds timeout)
    var event : enet.ENetEvent = undefined;
    if (enet.enet_host_service(@ptrCast(?[*]enet.ENetHost, client),
                               @ptrCast(?[*]enet.ENetEvent, &event), 5000) > 0
            and event.type == enet.ENetEventType.ENET_EVENT_TYPE_CONNECT) {
        std.debug.warn("Connected to server.\n");
    } else if (event.type == enet.ENetEventType.ENET_EVENT_TYPE_NONE) {
        std.debug.warn("Timeout connecting to server.\n");
        return 1;
    } else {
        std.debug.warn("Unknown error: {}", event);
        return 1;
    }

    while (true) {
        _ = c.sleep(1);
        var packet = enet.enet_packet_create(
            c"Ping", 4, @bitCast(c_uint, enet.ENET_PACKET_FLAG_RELIABLE));
        _ = enet.enet_peer_send(@ptrCast(?[*]enet.ENetPeer, server), 0, packet);
        enet.enet_host_flush(@ptrCast(?[*]enet.ENetHost, client));

        // Poll for responses
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
                    return 1;
                },
                else => {
                    std.debug.warn("Unexpected event: {}\n", event);
                }
            }
        }

    }

    return 0;
}
