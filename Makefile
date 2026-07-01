ALPINE_TAG := 3.24

all: alpine-airgap-$(ALPINE_TAG)-x86_64.iso

clean:
	rm -f *.iso

alpine-airgap-$(ALPINE_TAG)-x86_64.iso:
	./build.sh "$(ALPINE_TAG)"
