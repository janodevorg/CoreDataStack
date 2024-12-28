#!/bin/bash -e -o pipefail

# Copy these to the Makefile
# PROJECT_NAME = $(shell ls | grep xcodeproj | head -1 | xargs -I{} xcodebuild -project {} -showBuildSettings | grep PROJECT_NAME | awk '{print $$NF}')
# MODULE_NAME = $(shell ls | grep xcodeproj | head -1 | xargs -I{} xcodebuild -project {} -showBuildSettings | grep PRODUCT_MODULE_NAME | awk '{print $$NF}')
# TARGET_NAME = $(shell swift package dump-package | jq '.products[0].name' | tr -d '"')
# TARGET_NAME_LOWERCASE = $(shell echo ${TARGET_NAME} | tr '[:upper:]' '[:lower:]')
# GITHUB_USER = janodevorg

.PHONY: clean help project requirebrew requiretuist resetgit swiftdoc swiftlint test xcodegen

help: requirebrew requiretuist 
	@echo Usage:
	@echo ""
	@echo "  make clean       - removes all generated products"
	@echo "  make docc        - Generate documentation for a package"
	@echo "  make doccapp     - Generate documentation for UIKit project"
	@echo "  make project     - generates a xcode project with local dependencies"
	@echo "  make projecttest - Run tests using xcodebuild and a generated project"
	@echo "  make runner      - Run the CI actions locally"
	@echo "  make spmcache    - Remove SPM cache"
	@echo "  make swiftbuild  - compile package using swift build"
	@echo "  make swiftlint   - Run swiftlint"
	@echo "  make swifttest   - test package using swift test"
	@echo ""

clean:
	rm -rf .build
	rm -rf .swiftpm
	rm -rf build
	rm -rf docs
	rm -rf Package.resolved

docc: requirejq
	rm -rf docs
	swift build
	DOCC_JSON_PRETTYPRINT=YES
	swift package \
 	--allow-writing-to-directory ./docs \
	generate-documentation \
 	--target ${TARGET_NAME} \
 	--output-path ./docs \
 	--transform-for-static-hosting \
 	--hosting-base-path ${TARGET_NAME} \
	--emit-digest
	cat docs/linkable-entities.json | jq '.[].referenceURL' -r | sort > docs/all_identifiers.txt
	sort docs/all_identifiers.txt | sed -e "s/doc:\/\/${TARGET_NAME}\/documentation\\///g" | sed -e "s/^/- \`\`/g" | sed -e 's/$$/``/g' > docs/all_symbols.txt
	@echo "Check https://${GITHUB_USER}.github.io/${TARGET_NAME}/documentation/${TARGET_NAME_LOWERCASE}/"
	@echo ""

doccapp: requirejq
	rm -rf docs
	mkdir -p docs
	xcodebuild build -scheme ${TARGET_NAME} -destination generic/platform=iOS
	DOCC_JSON_PRETTYPRINT=YES
	xcodebuild docbuild \
		-scheme ${TARGET_NAME} \
		-destination generic/platform=iOS \
		OTHER_DOCC_FLAGS="--transform-for-static-hosting --hosting-base-path ${TARGET_NAME} --output-path docs"
	@echo "Check https://${GITHUB_USER}.github.io/${TARGET_NAME}/documentation/${TARGET_NAME_LOWERCASE}/"
	@echo ""

swiftlint:
	swift run swiftlint

swiftbuild: 
	@if [ ! -f Package.swift ]; then echo "You tried to compile as package but Package.swift doesn’t exist." >&2; exit 1; fi
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios18.2-simulator" 

swiftbuildmac: 
	@if [ ! -f Package.swift ]; then echo "You tried to compile as package but Package.swift doesn’t exist." >&2; exit 1; fi
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk macosx --show-sdk-path`"

swifttest: 
	@if [ ! -f Package.swift ]; then echo "You tried to compile as package but Package.swift doesn’t exist." >&2; exit 1; fi
	swift test -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios18.2-simulator" 

swifttestmac: 
	@if [ ! -f Package.swift ]; then echo "You tried to compile as package but Package.swift doesn’t exist." >&2; exit 1; fi
	swift test -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk macosx --show-sdk-path`"

projecttest: project
	@echo project name is ${PROJECT_NAME}
	xcodebuild test -project ${PROJECT_NAME}.xcodeproj -scheme ${PROJECT_NAME} -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14,OS=latest' CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO

project: requiretuist
	rm Grimoire/Info.plist || true
	cp Grimoire/Info-original.plist Grimoire/Info.plist
	rm -rf "${PROJECT_NAME}.xcodeproj"
	xcodegen generate --project . --spec project.yml
	echo Generated ${PROJECT_NAME}.xcodeproj
	open ${PROJECT_NAME}.xcodeproj

requirebrew:
	@if ! command -v brew &> /dev/null; then echo "Please install brew from https://brew.sh/"; exit 1; fi

requirejq:
	@if ! command -v jq &> /dev/null; then echo "Please install jq using 'brew install jq'"; exit 1; fi

requirexcbeautify: requirebrew
	@if ! command -v xcbeautify &> /dev/null; then echo "Please install xcbeautify using 'brew install xcbeautify'"; exit 1; fi

requiretuist: requirebrew
	@if ! command -v tuist &> /dev/null; then echo "Please install tuist using 'brew install mise; mise install tuist'"; exit 1; fi

resetgit:
	# @echo "This removes Git history, including tags. Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	DIR=$(shell cd -P -- '$(shell dirname -- "$0")' && pwd -P | sed 's:.*/::'); \
	rm -rf .git; \
	git init; \
	git add .; \
	git commit -m "Initial"; \
	git remote add origin git@github.com:${GITHUB_USER}/$$DIR.git; \
	git push --force --set-upstream origin main; \
	git tag -d `git tag | grep -E '.'`; \
	git ls-remote --tags origin | awk '/^(.*)(s+)(.*[a-zA-Z0-9])$$/ {print ":" $$2}' | xargs git push origin; \
	git tag 1.0.0; \
	git push origin main --tags

spmcache:
	rm -rf ~/Library/Caches/org.swift.swiftpm/

runner: requirexcbeautify requiretuist
	tuist generate --no-open
	set -o pipefail && xcodebuild build -scheme "CoreDataStack" -destination "OS=18.2,name=iPhone 16 Pro" -skipPackagePluginValidation | xcbeautify
	set -o pipefail && xcodebuild build -scheme "CoreDataStack" -destination "platform=macOS,arch=arm64" -skipPackagePluginValidation | xcbeautify

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
