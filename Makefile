format:
	ios/Pods/SwiftFormat/CommandLineTool/swiftformat ios/Source --exclude Toshi/Generated/Code --header "Copyright (c) 2017-{year} Coinbase Inc. See LICENSE"
	gradle ktlintFormat -p android

lint:
	ios/Pods/SwiftLint/swiftlint --path ios
	android/gradlew ktlint -p android

deps:
	rm -rf android/libraries; git submodule update --init --force --recursive
	git submodule foreach 'git checkout $$sha1 || :'
