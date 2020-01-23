SUDO := sudo -H

default: pbuild prun

pbuild:
	$(SUDO) podman build -t pcp-preview .

prun:
	$(SUDO) podman run --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -p 3000:3000 pcp-preview

dbuild:
	$(SUDO) docker build -t pcp-preview .

drun:
	$(SUDO) docker run --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -p 3000:3000 pcp-preview
