# Options:
# osx_enet_patch (default 0)
# Set to 1 to apply a patch to enet.zig to make it compatible with OSX. The
# current zig translate-c is broken.

os=
ifeq ($(shell uname -s),Darwin)
	os=osx
endif

ifndef osx_enet_patch
	osx_enet_patch=0
	ifeq ($(os),osx)
		osx_enet_patch=1
	endif
endif

GLFW_LIB=
ifeq ($(os),osx)
GLFW_LIB=$(LIBDIR)/libglfw.3.dylib
else
GLFW_LIB=$(LIBDIR)/libglfw.so.3
endif

SRCDIR=src
BINDIR=bin
LIBDIR=lib
DEPDIR=dep
ZC=zig
CLIENT_ZFLAGS:=-L$(LIBDIR) -rpath $(LIBDIR) \
	            -framework OpenGL \
	            --library $(GLFW_LIB) \
	            --library c \
	            --library enet \
	            -isystem $(DEPDIR)/glfw/include
SERVER_ZFLAGS=-L$(LIBDIR) \
							--library c \
							--library enet
CMAKE=cmake
SRC=$(shell find src -type f)
SRC+=$(SRCDIR)/enet.zig # enet.zig is generated from enet.h

ALL: $(ALL_DIRS)
	$(info Targets: run-server, run-client, clean (cleans built objects), clean-all (cleans dependencies and built objects))

ALL_DIRS=$(SRCDIR) $(BINDIR) $(LIBDIR) $(DEPDIR) $(DEPDIR)/tmp/
$(ALL_DIRS):
	mkdir -p $@

.PHONY: run-server
.PHONY: run-client
.PHONY: clean
.PHONY: clean-all

clean:
	rm -rf $(BINDIR)

clean-all:
	rm -rf $(BINDIR)
	rm -rf $(LIBDIR)
	rm -rf $(DEPDIR)

run-server: $(ALL_DIRS) $(BINDIR)/server
	$(BINDIR)/server

run-client: $(ALL_DIRS) $(BINDIR)/client
	$(BINDIR)/client

$(BINDIR)/server: $(LIBDIR)/libenet.a $(SRC)
	$(ZC) build-exe $(SERVER_ZFLAGS) --output $@ $(SRCDIR)/server/main.zig

$(BINDIR)/client: $(LIBDIR)/libenet.a $(GLFW_LIB) $(SRC)
	$(ZC) build-exe $(CLIENT_ZFLAGS) --output $@ $(SRCDIR)/client/main.zig

# Builds enet.h into a .zig. This is because some platforms fail to properly
# @cimport the enet.h file, so when porting to other platforms we can apply
# extra post-processing here to correct the translated .h files.
$(SRCDIR)/enet.zig: $(DEPDIR)/enet/include
	$(ZC) translate-c -isystem $< $</enet/enet.h > $(DEPDIR)/tmp/enet.zig
# Apply patch if osx_enet_patch=1.
ifeq ($(osx_enet_patch), 1)
	patch $(DEPDIR)/tmp/enet.zig patches/osx_enet.zig.patch
endif
	cp $(DEPDIR)/tmp/enet.zig $@

################
# Dependencies #
################

$(LIBDIR)/libenet.a:
	if [ ! -d $(DEPDIR)/enet ] ; then \
		git clone https://github.com/lsalzman/enet $(DEPDIR)/enet ; \
	fi
	mkdir -p $(DEPDIR)/enet/build
	cd $(DEPDIR)/enet/build && cmake .. && make
	mv $(DEPDIR)/enet/build/libenet.a $@


$(GLFW_LIB):
	if [ ! -d $(DEPDIR)/glfw ] ; then \
		git clone https://github.com/glfw/glfw $(DEPDIR)/glfw ; \
	fi
	mkdir -p $(DEPDIR)/glfw/build
	cd $(DEPDIR)/glfw/build ; \
	cmake .. -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_EXAMPLES=OFF \
	         -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DGLFW_INSTALL=OFF ; \
	make
	mv $(DEPDIR)/glfw/build/src/$(notdir $@) $@
