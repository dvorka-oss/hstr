#  hstr.c     HSTR shell history completion utility

#  Copyright (C) 2014-2026 Martin Dvorak <martin.dvorak@mindforger.com>

#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

.DEFAULT_GOAL := help

#
# VARIABLES
#

# HSTR version - extracted from src/hstr.c
HSTR_VERSION := $(shell grep 'hstr version' ../src/hstr.c | sed 's/.*hstr version \\"\([^\\]*\)\\".*/\1/')

#
# HELP
#

.PHONY: help
help: ## make targets help
	@echo " _   _ ____ _____ ____  "
	@echo "| | | / ___|_   _|  _ \\ "
	@echo "| |_| \\___ \\ | | | |_) |"
	@echo "|  _  |___) || | |  _ < "
	@echo "|_| |_|____/ |_| |_| \\_\\ $(HSTR_VERSION)"
	@echo ""
	@echo "HSTR: history suggest box - Swiss knife:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#
# CODING
#

.PHONY: vibe
vibe:
	@ls -l ../.github/copilot*.md
	@cd .. && copilot --allow-all-tools --banner

#
# CLEAN
#

.PHONY: clean
clean: ## clean build artifacts
	@rm -vf ../hstr ../src/hstr
	@cd .. && make clean ; cd build

#
# BUILD
#

build-dev: clean ## clean, configure, and build HSTR
	cd ./tarball && ./tarball-automake.sh && cd ../.. && ./configure && make all

build: build-dev ## clean, configure, and build HSTR
	strip ../src/hstr

#
# RUN
#

.PHONY: run-dev
run-dev: ## run HSTR for development
	cd .. && make clean all && cd build && ../src/hstr

#
# TEST
#

.PHONY: test
test: ## run HSTR unit tests
	cd ../test && qmake hstr-unit-tests.pro && make clean all && ./hstr-unit-tests

.PHONY: test-memleaks
test-memleaks: ## run HSTR memory leak tests with Valgrind
	./test-memleaks.sh

#
# INSTALL
#

.PHONY: install-personal
install-personal: build ## install HSTR for personal user
	@echo "Installing HSTR $(HSTR_VERSION) for personal user..."
	@rm -vf $(HOME)/bin/hstr
	@cp -vf ../src/hstr $(HOME)/bin
	@echo "HSTR $(HSTR_VERSION) installed to $(HOME)/bin"
	hstr --version
