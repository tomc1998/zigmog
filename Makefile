SRCDIR=src
BINDIR=bin
LIBDIR=lib
DEPDIR=dep
ZC=zig
CLIENT_ZFLAGS=-L$(LIBDIR) --library c --library glfw --library enet
SERVER_ZFLAGS=-L$(LIBDIR) --library c --library enet
CMAKE=cmake
SRC=$(shell find src -type f)

ALL: $(ALL_DIRS) 
	$(info Targets: run-server, run-client, clean (cleans built objects), clean-all (cleans dependencies and built objects))

ALL_DIRS=$(SRCDIR) $(BINDIR) $(LIBDIR) $(DEPDIR) 
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

$(BINDIR)/server: $(LIBDIR)/libenet.a
	$(ZC) build-exe $(ZFLAGS) --output $@ $(SRCDIR)/server/main.zig

$(BINDIR)/client: $(LIBDIR)/libenet.a $(LIBDIR)/libglfw3.a
	$(ZC) build-exe $(ZFLAGS) --output $@ $(SRCDIR)/client/main.zig

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

$(LIBDIR)/libglfw3.a:
	if [ ! -d $(DEPDIR)/glfw ] ; then \
		git clone https://github.com/glfw/glfw $(DEPDIR)/glfw ; \
	fi
	mkdir -p $(DEPDIR)/glfw/build
	cd $(DEPDIR)/glfw/build ; \
	cmake .. -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DGLFW_INSTALL=OFF ; \
	make
	mv $(DEPDIR)/glfw/build/src/libglfw3.a $@

