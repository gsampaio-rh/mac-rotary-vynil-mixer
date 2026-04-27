.PHONY: build run package clean

APP_NAME = VinylAudio
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

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

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
