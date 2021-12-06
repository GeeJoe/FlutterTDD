#!/bin/sh

source coverage_helper.sh flutter_tdd
flutter test --coverage
flutter pub run remove_from_coverage -f coverage/lcov.info
flutter pub run test_coverage_badge
git add coverage_badge.svg
git commit -m "Update coverage badge"
genhtml coverage/lcov.info -o coverage/html
