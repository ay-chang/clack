# Clack — build, sign and package the app bundle.
#
#   make            build Clack.app (ad-hoc signed, fine for local use)
#   make run        build and launch it
#   make dmg        build a distributable disk image
#   make icon       regenerate Resources/AppIcon.icns from Scripts/make-icon.swift
#
# For release builds, pass a real identity:
#   make SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" dmg

VERSION ?= 1.0.0
BUILD   ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

# "-" is ad-hoc. Accessibility permission is bound to the signature, so an
# ad-hoc build must be re-authorised in System Settings after every rebuild.
SIGN_IDENTITY ?= -

APP        := build/Clack.app
BINARY     := .build/apple/Products/Release/Clack
CONTENTS   := $(APP)/Contents

.PHONY: all run clean dmg icon binary open-support

all: $(APP)

binary:
	swift build -c release --arch arm64 --arch x86_64

$(APP): binary Resources/Info.plist Resources/AppIcon.icns Resources/MenuBarIcon.png
	rm -rf $(APP)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BINARY) $(CONTENTS)/MacOS/Clack
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	cp Resources/MenuBarIcon.png $(CONTENTS)/Resources/MenuBarIcon.png
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD)/' \
		Resources/Info.plist > $(CONTENTS)/Info.plist
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "==> ad-hoc signing (local use only)"; \
		codesign --force --sign - --timestamp=none "$(APP)"; \
	else \
		echo "==> signing with $(SIGN_IDENTITY)"; \
		codesign --force --options runtime --timestamp \
			--sign "$(SIGN_IDENTITY)" "$(APP)"; \
	fi
	@echo "==> built $(APP)"

run: $(APP)
	@pkill -x Clack || true
	open $(APP)

dmg: $(APP)
	rm -f build/Clack-$(VERSION).dmg
	rm -rf build/dmg && mkdir -p build/dmg
	cp -R $(APP) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Clack" -srcfolder build/dmg -ov -format ULFO \
		build/Clack-$(VERSION).dmg
	rm -rf build/dmg
	@echo "==> built build/Clack-$(VERSION).dmg"

icon: Resources/AppIcon.icns Resources/MenuBarIcon.png

Resources/MenuBarIcon.png: Resources/AppIcon.icns

Resources/AppIcon.icns: Scripts/make-icon.swift Resources/clack-mark.png
	rm -rf build/AppIcon.iconset
	mkdir -p build/AppIcon.iconset
	swift Scripts/make-icon.swift build Resources/clack-mark.png
	cp build/MenuBarIcon.png Resources/MenuBarIcon.png
	for pair in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
	            "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
	            "512 512x512" "1024 512x512@2x"; do \
		set -- $$pair; \
		sips -z $$1 $$1 build/icon_1024.png \
			--out build/AppIcon.iconset/icon_$$2.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	rm -rf build/AppIcon.iconset build/icon_1024.png build/MenuBarIcon.png

# Reveal the history file, for anyone who wants to inspect what is stored.
open-support:
	open ~/Library/Application\ Support/Clack

clean:
	rm -rf .build build
