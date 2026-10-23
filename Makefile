.PHONY: app selftest xcodebuild open

app:
	./Scripts/build.sh

selftest: app
	./dist/BussinessRunner.app/Contents/MacOS/BussinessRunner --self-test

open: app
	open dist/BussinessRunner.app

xcodebuild:
	xcodebuild -project BussinessRunner.xcodeproj -scheme BussinessRunner -configuration Release -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
