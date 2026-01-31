.PHONY: build test clean open simulator

# Build for connected device (Debug)
build:
	xcodebuild -project PRReviewer.xcodeproj \
		-scheme PRReviewer \
		-destination 'generic/platform=iOS' \
		-configuration Debug \
		build

# Build for simulator
simulator:
	xcodebuild -project PRReviewer.xcodeproj \
		-scheme PRReviewer \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-configuration Debug \
		build

# Run tests locally
test:
	xcodebuild test \
		-project PRReviewer.xcodeproj \
		-scheme PRReviewer \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-configuration Debug

# Clean build artifacts
clean:
	xcodebuild clean -project PRReviewer.xcodeproj -scheme PRReviewer
	rm -rf ~/Library/Developer/Xcode/DerivedData/PRReviewer-*

# Open project in Xcode
open:
	open PRReviewer.xcodeproj
