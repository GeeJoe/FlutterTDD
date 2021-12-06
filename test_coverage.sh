#!/bin/sh

source coverage_helper.sh mirai
flutter test --coverage
flutter pub run remove_from_coverage -f coverage/lcov.info -r 'lib/model/proto/*'
flutter pub run test_coverage_badge
git add coverage_badge.svg
git commit -m "Update coverage badge"
genhtml coverage/lcov.info -o coverage/html
