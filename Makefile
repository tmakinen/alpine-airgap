ALPINE_VER    := 3.24.1
ALPINE_BRANCH := $(shell echo "$(ALPINE_VER)" | cut -d. -f1-2)
ISO_SOURCE    := alpine-standard-$(ALPINE_VER)-x86_64.iso

all: alpine-airgap-x86_64.iso

clean:
	rm -f *.iso

alpine-extended-$(ALPINE_VER)-x86_64.iso:
	curl --fail -O \
	    "https://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_BRANCH)/releases/x86_64/$@"

alpine-airgap-x86_64.iso: alpine-extended-$(ALPINE_VER)-x86_64.iso
	./build.sh "$<"
