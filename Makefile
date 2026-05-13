APP_NAME := FnScribe
PROJECT := FnScribe.xcodeproj
SCHEME := FnScribe
CONFIGURATION ?= Debug
BUILD_ROOT := $(CURDIR)/build
BUILD_DIR := $(BUILD_ROOT)/$(CONFIGURATION)
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APPLICATIONS_DIR ?= /Applications

.PHONY: build install uninstall clean

build:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination 'platform=macOS' \
		-allowProvisioningUpdates \
		CONFIGURATION_BUILD_DIR="$(BUILD_DIR)" \
		build

install: build
	-pkill -x "$(APP_NAME)"
	-pluginkit -r "$(APPLICATIONS_DIR)/$(APP_NAME).app/Contents/PlugIns/FnScribeWidget.appex"
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	ditto "$(APP_BUNDLE)" "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	-pluginkit -r "$(APP_BUNDLE)/Contents/PlugIns/FnScribeWidget.appex"
	/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	pluginkit -a "$(APPLICATIONS_DIR)/$(APP_NAME).app/Contents/PlugIns/FnScribeWidget.appex"

uninstall:
	-pluginkit -r "$(APPLICATIONS_DIR)/$(APP_NAME).app/Contents/PlugIns/FnScribeWidget.appex"
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME).app"

clean:
	rm -rf "$(BUILD_ROOT)"
