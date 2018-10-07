const std = @import("std");
const enet = @import("../enet.zig");
const c = @cImport({
    @cInclude("unistd.h");
});

var address : enet.ENetAddress = undefined;
var server : *enet.ENetHost = undefined;

pub const CharData = struct {};

/// The state of the client - this is not an in-world state, but rather the
/// state through the authentication process. Most clients will spend the majority
/// of their time in the ClientState.InGame state. Clients will progress through
/// these states in the order declared below.
pub const ClientState = enum {
    /// Client hasn't sent their auth token yet
    Unverified,
    /// Client sent their auth token, this is being checked with the auth server
    Verifying,
    /// Client has been verified, their data is being loaded
    Fetching,
    /// Client is controlling an in-game player character
    InGame
};

/// Client data. All data should be considered invalid until state = ClientState.InGame.
/// Once the player has been verified with their auth token, this is set to true
/// and the data is fetched from the DB.
pub const ClientData = struct {
    /// ID of the player character.
    charId: usize,
    /// ID of this client's account.
    accountId: usize,
    /// The client's player character's in-game data. This is the struct that
    /// stores stuff like position and in-game state.
    char: CharData,
    /// Overall client state, used mainly for the verification process, and
    /// won't change much (if at all) once in-game
    state: ClientState,

    /// Returns a blank, unverified clientdata.
    pub fn init(alloc: *std.mem.Allocator) !*ClientData {
        var clientData = try alloc.createOne(ClientData);
        clientData.state = ClientState.Unverified;
        return clientData;
    }
};

pub fn pollEnet(alloc: *std.mem.Allocator) !void {
    var event : enet.ENetEvent = undefined;
    while (enet.enet_host_service(@ptrCast(?[*]enet.ENetHost, server),
                                  @ptrCast(?[*]enet.ENetEvent, &event),
                                  0) > 0) {
        switch (event.type) {
            enet.ENetEventType.ENET_EVENT_TYPE_CONNECT => {
                std.debug.warn("Creating client data\n");
                event.peer.?[0].data = try ClientData.init(alloc);
            },
            enet.ENetEventType.ENET_EVENT_TYPE_RECEIVE => {
                {
                  @setRuntimeSafety(false); // For alignCast
                  std.debug.warn(
                      "A packet of length {} containing {} was received on channel {}. Clientstate = {}.\n",
                      event.packet.?[0].dataLength,
                      event.packet.?[0].data.?[0..event.packet.?[0].dataLength],
                      event.channelID,
                      @intToPtr(*ClientData, @ptrToInt(event.peer.?[0].data.?)).state);
                }
                // Clean up the packet now that we're done using it.
                enet.enet_packet_destroy(event.packet);
                // Send a response.
                var packet = enet.enet_packet_create(
                    "Pong", 4, @bitCast(c_uint, enet.ENET_PACKET_FLAG_RELIABLE));
                _ = enet.enet_peer_send(@ptrCast(?[*]enet.ENetPeer, event.peer), 0, packet);
                enet.enet_host_flush(@ptrCast(?[*]enet.ENetHost, server));
            },
            enet.ENetEventType.ENET_EVENT_TYPE_DISCONNECT => {
                std.debug.warn("{} disconnected.\n", event.peer.?[0].data);
                // Reset the peer's client information.
                event.peer.?[0].data = null;
            },
            else => {}
        }
    }
}


pub fn main() error!void {
    // Setup server
    if (enet.enet_initialize() != 0) { std.debug.warn("Failed to initialize enet.\n"); }
    address.host = enet.ENET_HOST_ANY;
    address.port = 1234;
    const serverPtr = enet.enet_host_create(
        @ptrCast([*]const enet.ENetAddress, &address), 32, 2, 0, 0);
    server = &(serverPtr orelse {
        std.debug.warn("Failed to create enet host.\n");
        return;
    })[0];

    // Continuously poll
    while(true) {
        try pollEnet(std.debug.global_allocator);
        _ = c.sleep(1);
    }
}
