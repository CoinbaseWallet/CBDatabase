format:
	ios/Pods/SwiftFormat/CommandLineTool/swiftformat ios/Source --exclude Toshi/Generated/Code --header "Copyright (c) 2017-{year} Coinbase Inc. See LICENSE"
	gradle ktlintFormat -p android

lint:
	Pods/SwiftLint/swiftlint

init:
	 brew install gradle
