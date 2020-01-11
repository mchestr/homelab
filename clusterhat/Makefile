TARGETDIR := build

USERNAME := mchestr
CONTROLLER_STATIC_IP := 192.168.1.30
LAN_ROUTER := 192.168.1.1
HYPRIOT_VERSION := v1.11.5
HYPRIOT_FILE := hypriotos-rpi-$(HYPRIOT_VERSION).img.zip
HYPRIOT_URL := https://github.com/hypriot/image-builder-rpi/releases/download/$(HYPRIOT_VERSION)/$(HYPRIOT_FILE)
COMPILE_NODE = m4 -D USERNAME=$(USERNAME) -D STATIC_IP_ADDR=$(STATIC_IP_ADDR) -D LAN_ROUTER=$(LAN_ROUTER) -D NODE=$* $< > $@

.PHONY: all controller p1 p2 p3 p4 clean flash guard-%

all: | controller p1 p2 p3 p4

guard-%:
	@ if [ "${${*}}" = "" ]; then \
        echo "Environment variable $* not set"; \
        exit 1; \
    fi

controller: $(TARGETDIR)/controller/user-data
p1 p2 p3 p4: p% : $(TARGETDIR)/p%/cmdline.txt $(TARGETDIR)/p%/user-data

$(TARGETDIR)/controller/user-data: source/controller/* | $(TARGETDIR)/controller/
	m4 -D CLUSTERHAT="$(shell base64 -w0 source/controller/files/python/clusterhat)" \
	   -D UDEV_RULES="$(shell base64 -w0 source/controller/files/90-clusterhat.rules)" \
	   -D INTERFACES="$(shell base64 -w0 source/controller/files/interfaces)" \
	   -D XRA_SCRIPT="$(shell base64 -w0 source/controller/files/python/xra1200.py)" \
	   -D USERNAME=$(USERNAME) -D STATIC_IP_ADDR=$(STATIC_IP_ADDR) -D LAN_ROUTER=$(LAN_ROUTER) \
	   source/controller/user-data.yml \
	   > $@

$(TARGETDIR)/p%/cmdline.txt : source/cluster-nodes/cmdline.txt | $(TARGETDIR)/p%/
	$(COMPILE_NODE)

$(TARGETDIR)/p%/user-data : source/cluster-nodes/user-data.yml | $(TARGETDIR)/p%/
	$(COMPILE_NODE)

$(TARGETDIR)/%/:
	mkdir -p $(TARGETDIR)/$*

flash: guard-t $(t) $(HYPRIOT_FILE)
	flash -C source/$(t)/config.txt -u build/$(t)/user-data $(HYPRIOT_FILE)

$(HYPRIOT_FILE):
	curl -L $(HYPRIOT_URL) -o $(HYPRIOT_FILE)

clean:
	rm -rf build

