ifndef VERBOSE
.SILENT:
endif

# main build target. compiles the teamserver and client
all: ts-build client-build

# teamserver building target
ts-build:
	@ echo "[*] building teamserver"
	@ ./teamserver/Install.sh
	@ cd teamserver; GO111MODULE="on" go build -ldflags="-s -w -X cmd.VersionCommit=$(git rev-parse HEAD)" -o ../havoc main.go
	@ sudo setcap 'cap_net_bind_service=+ep' havoc # this allows you to run the server as a regular user

dev-ts-compile:
	@ echo "[*] compile teamserver"
	@ cd teamserver; GO111MODULE="on" go build -ldflags="-s -w -X cmd.VersionCommit=$(git rev-parse HEAD)" -o ../havoc main.go 

ts-cleanup: 
	@ echo "[*] teamserver cleanup"
	@ rm -rf ./teamserver/bin
	@ rm -rf ./data/loot
	@ rm -rf ./data/x86_64-w64-mingw32-cross 
	@ rm -rf ./data/havoc.db
	@ rm -rf ./data/server.*
	@ rm -rf ./teamserver/.idea
	@ rm -rf ./havoc

# client building and cleanup targets
client-build:
	@ echo "[*] building client"
	@ git submodule update --init --recursive
	@ mkdir -p client/Build; cd client/Build; cmake ..
	@ if [ -d "client/Modules" ]; then echo "Modules installed"; else git clone https://github.com/HavocFramework/Modules client/Modules --single-branch --branch main; fi
	@ cmake --build client/Build -- -j 4

client-cleanup:
	@ echo "[*] client cleanup"
	@ rm -rf ./client/Build
	@ rm -rf ./client/Bin/*
	@ rm -rf ./client/Data/database.db
	@ rm -rf ./client/.idea
	@ rm -rf ./client/cmake-build-debug
	@ rm -rf ./client/Havoc
	@ rm -rf ./client/Modules

# macOS app bundle creation target
macos-app:
	@ echo "[*] Creating macOS app bundle for Havoc Client"
	@if [ "$(shell uname)" != "Darwin" ]; then \
		echo "Error: This target is only for macOS"; \
		exit 1; \
	fi
	@if [ ! -f "client/Havoc" ]; then \
		echo "Error: Havoc client not built. Run 'make client-build' first"; \
		exit 1; \
	fi
	@ $(MAKE) --no-print-directory macos-create-app

macos-create-app:
	@ APP_NAME="Havoc"; \
	APP_BUNDLE="$$APP_NAME.app"; \
	TEMP_DIR=$$(mktemp -d); \
	TEMP_APP="$$TEMP_DIR/$$APP_BUNDLE"; \
	HAVOC_CLIENT_PATH="$$(pwd)/client"; \
	echo "[*] Creating app bundle structure..."; \
	mkdir -p "$$TEMP_APP/Contents/MacOS"; \
	mkdir -p "$$TEMP_APP/Contents/Resources"; \
	echo "[*] Creating launcher script..."; \
	printf '#!/bin/bash\n' > "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'DIR="$$( cd "$$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"\n' >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'export HAVOC_CLIENT_PATH="%s"\n' "$$HAVOC_CLIENT_PATH" >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'cd "$$HAVOC_CLIENT_PATH" || { osascript -e '"'"'display dialog "Failed to change to Havoc client directory." buttons {"OK"} default button 1 with icon stop'"'"'; exit 1; }\n' >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'if [ ! -f "$$HAVOC_CLIENT_PATH/Havoc" ]; then osascript -e '"'"'display dialog "Havoc executable not found. Please ensure Havoc is built." buttons {"OK"} default button 1 with icon stop'"'"'; exit 1; fi\n' >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'chmod +x "$$HAVOC_CLIENT_PATH/Havoc" 2>/dev/null\n' >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	printf 'exec "$$HAVOC_CLIENT_PATH/Havoc" "$$@"\n' >> "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	chmod +x "$$TEMP_APP/Contents/MacOS/$$APP_NAME"; \
	echo "[*] Creating Info.plist..."; \
	printf '<?xml version="1.0" encoding="UTF-8"?>\n' > "$$TEMP_APP/Contents/Info.plist"; \
	printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '<plist version="1.0">\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '<dict>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleExecutable</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>%s</string>\n' "$$APP_NAME" >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleIconFile</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>AppIcon</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleIdentifier</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>com.havoc.client</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleName</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>%s</string>\n' "$$APP_NAME" >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleDisplayName</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>%s Client</string>\n' "$$APP_NAME" >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundlePackageType</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>APPL</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleShortVersionString</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>1.0.0</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleVersion</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>1</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>CFBundleSignature</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>????</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>LSMinimumSystemVersion</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>10.12</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>NSHighResolutionCapable</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <true/>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>NSSupportsAutomaticGraphicsSwitching</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <true/>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>LSApplicationCategoryType</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <string>public.app-category.developer-tools</string>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>NSRequiresAquaSystemAppearance</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <false/>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <key>LSEnvironment</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    <dict>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '        <key>HAVOC_CLIENT_PATH</key>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '        <string>%s</string>\n' "$$HAVOC_CLIENT_PATH" >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '    </dict>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '</dict>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	printf '</plist>\n' >> "$$TEMP_APP/Contents/Info.plist"; \
	ICON_PATH=$$(find "$$HAVOC_CLIENT_PATH" "$$HAVOC_CLIENT_PATH/.." -name "Havoc.png" -o -name "havoc.png" 2>/dev/null | head -n 1); \
	if [ -n "$$ICON_PATH" ] && [ -f "$$ICON_PATH" ]; then \
		echo "[*] Found icon at: $$ICON_PATH"; \
		ICONSET_DIR="$$TEMP_DIR/AppIcon.iconset"; \
		mkdir -p "$$ICONSET_DIR"; \
		for size in 16 32 64 128 256 512 1024; do \
			sips -z $$size $$size "$$ICON_PATH" --out "$$ICONSET_DIR/icon_$${size}x$${size}.png" >/dev/null 2>&1 || true; \
		done; \
		for size in 16 32 64 128 256 512; do \
			size2x=$$((size * 2)); \
			cp "$$ICONSET_DIR/icon_$${size2x}x$${size2x}.png" "$$ICONSET_DIR/icon_$${size}x$${size}@2x.png" 2>/dev/null || true; \
		done; \
		iconutil -c icns "$$ICONSET_DIR" -o "$$TEMP_APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true; \
		rm -rf "$$ICONSET_DIR"; \
	else \
		echo "[*] No icon found, using default"; \
	fi; \
	echo "[*] Installing app bundle..."; \
	if [ -d "/Applications/$$APP_BUNDLE" ]; then \
		echo "[*] Removing existing installation..."; \
		rm -rf "/Applications/$$APP_BUNDLE"; \
	fi; \
	mv "$$TEMP_APP" "/Applications/$$APP_BUNDLE"; \
	rm -rf "$$TEMP_DIR"; \
	touch "/Applications/$$APP_BUNDLE"; \
	killall Finder 2>/dev/null || true; \
	echo "[+] Installation complete!"; \
	echo "    Havoc has been installed as: /Applications/$$APP_BUNDLE"; \
	echo ""; \
	echo "Launch options:"; \
	echo "    • Spotlight Search (⌘ + Space, then type 'Havoc')"; \
	echo "    • Applications folder"; \
	echo "    • Drag to Dock for quick access"


# cleanup target
clean: ts-cleanup client-cleanup
	@ rm -rf ./data/*.db
	@ rm -rf payloads/Demon/.idea
	@ if [ "$(shell uname)" = "Darwin" ] && [ -d "/Applications/Havoc.app" ]; then \
		echo "[*] Removing macOS app bundle..."; \
		rm -rf /Applications/Havoc.app; \
	fi

# Build all (with macOS app on macOS)
all-all: all
	@if [ "$(shell uname)" = "Darwin" ]; then \
		$(MAKE) macos-app; \
	fi

.PHONY: all all-all ts-build ts-cleanup dev-ts-compile client-build client-cleanup macos-app macos-create-app clean
