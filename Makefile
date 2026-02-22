.PHONY: build test clean open simulator dead-code dead-code-ci

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

# Dead code detection (local)
dead-code:
	periphery scan --strict

# Dead code detection (CI - no code signing)
dead-code-ci:
	periphery scan --strict \
		--build-arguments 'CODE_SIGN_IDENTITY=-,CODE_SIGNING_REQUIRED=NO,CODE_SIGNING_ALLOWED=NO'

# Clean build artifacts
clean:
	xcodebuild clean -project PRReviewer.xcodeproj -scheme PRReviewer
	rm -rf ~/Library/Developer/Xcode/DerivedData/PRReviewer-*

# Open project in Xcode
open:
	open PRReviewer.xcodeproj
