# Network architecture

## State updates

### Persistence property
Given an ECS, making an object persistent using a component fits well.

#### List of component types requiring persistence
When marking an object as persistent, we need to know which components it
contains to make it persistent. See the below [issue](#unknown-bitmask-size) for
potential solutions to this.

### Distance based culling
### Partial state updates

Done via bitmask, N bits where N is the amount of fields in a struct

Recursive deserialisation on a type-by-type basis (allowing for nested structs)

This means we not only get partial updates via only updating certain components,
but we can also partially update certain components if needs be.

#### Issues

State updates with unreliable delivery are problematic, since we only update
with state deltas. We need to record which state update deltas were received
and which were dropped. Then we need to re-transmit the ones that were dropped.

The recipient then needs to discard the accidental double-sends, and we also
need to not bother re-transmitting data that's been invalidated by new datas.

##### Unknown bitmask size {#unknown-bitmask-size}

For a bitmask to work, we need a list of components that need to be update per
entity type. This is unfortunate, as we can't guarantee that each type of entity
will have a certain set of components, without making that set the set of all
components that can be persisted across the network - this defeats the gains of
serialising based on an ECS.

###### Potential solution

We could have a set of functions which deserialised objects using the notion of
a type, despite components being type-less. For example, a 'deserPlayer'
function, which deserialises a packet given that it's a player into its
components. This function would know that the player would never have a
'OpenableDoor' component, like a door in the game world might. We'd effectively
be hardcoding the type in the code, which is a shame because then we don't get
to take advantage of zig's typesystem, but I think this situation would be too
complex for the typesystem to handle anyway.

This also means we need to create per-type deser / ser functions for different
sets of components. Potentially we could find a way to generate these functions
by passing around arrays of types (?), since all types are just combinations of
different components. This would be really efficient code wise, and we'd
probably just end up with 1 big switch function that called all the right
functions automatically.
