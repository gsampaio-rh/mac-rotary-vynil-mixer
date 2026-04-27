.PHONY: build run package install release clean

APP_NAME = VinylAudio
VERSION = 1.1.0
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
RELEASE_ZIP = $(APP_NAME)-$(VERSION)-macOS.zip

build:
	swift build -c release

run: build
	$(BUILD_DIR)/$(APP_NAME)

package: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/

install: package
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

release: package
	rm -f $(RELEASE_ZIP)
	ditto -c -k --keepParent $(APP_BUNDLE) $(RELEASE_ZIP)
	@echo ""
	@echo "Release: $(RELEASE_ZIP)"
	@du -h $(RELEASE_ZIP) | awk '{print "Size: " $$1}'
	@shasum -a 256 $(RELEASE_ZIP) | awk '{print "SHA-256: " $$1}'

clean:
	swift package clean
	rm -rf $(APP_BUNDLE) *.zip
