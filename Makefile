DOCKER ?= docker
JQ ?= jq

SOLC := docker.io/ethereum/solc:0.8.25
FOUNDRY := ghcr.io/foundry-rs/foundry

FORGEBUILDFLAGS ?=
FORGEFMTFLAGS ?=
FORGETESTFLAGS ?=

DOCKERSOLC := $(DOCKER) run --rm -i $(SOLC)
DOCKERFOUNDRY := $(DOCKER) run --rm -v $(PWD):/src -w /src $(FOUNDRY)

.PHONY: all
all: build

.PHONY: ci
ci: clean
	@$(MAKE) build fmt test FORGEFMTFLAGS=--check FORGETESTFLAGS=-vvvv

.PHONY: build
build: artifacts/Safe.json

.PHONY: test
test: test/SafeBytecode.sol
	@mkdir -p build/sol
	@$(DOCKERFOUNDRY) 'forge test $(FORGETESTFLAGS)'

.PHONY: fmt
fmt:
	@$(DOCKERFOUNDRY) 'forge fmt $(FORGEFMTFLAGS) $(shell find src -name '*.sol') $(shell find test -name '*.sol')'

.PHONY: opcodes/%
opcodes/%: build/yul/%.json
	@$(JQ) -r '.evm.deployedBytecode.opcodes' $< \
		| sed -E -e 's/(PUSH[1-9][0-9]?) ([^ ]*)/\1,\2/g' -e 's/ +$$//' -e 's/([^ ]*) /\1\n/g' -e 's/,/ /g' \
		| awk '/PUSH[1-9][0-9]?/ { b=2+2*substr($$1,5)-length($$2); if (b!=0) { $$2=sprintf("0x%0" b "d%s",0,substr($$2,3)) } } { print }' \
		| awk '{ printf "%04x: %s\n",x,$$0; x+=1 } /PUSH[1-9][0-9]?/ { x+=substr($$1,5) }'

.PHONY: codesize/%
codesize/%: build/yul/%.json
	@eval "$$($(JQ) -r '.evm.deployedBytecode.object | length | (.-2)/2 | ["printf", "%d (%.2f%%)\n", ., . * 100 / 24576] | @sh' $<)"

.PHONY: clean
clean:
	@rm -rf artifacts/ build/ test/SafeBytecode.sol

artifacts/Safe.json: build/yul/Safe.json build/sol/forge.fingerprint
	@mkdir -p artifacts/
	@$(JQ) -Mn \
		--slurpfile SAFE build/yul/Safe.json \
		--slurpfile ISAFE build/sol/out/ISafe.sol/ISafe.json \
		'{ contractName: "Safe", abi: $$ISAFE[0].abi, bytecode: $$SAFE[0].evm.bytecode.object, deployedBytecode: $$SAFE[0].evm.deployedBytecode.object }' \
		>$@

.PRECIOUS: build/sol/%.json
artifacts/%.json: build/sol/forge.fingerprint
	@$(JQ) -Mn \
		--slurpfile FILE build/sol/out/$*.sol/$*.json \
		'{ contractName: "$*", abi: $$FILE[0].abi, bytecode: $$FILE[0].bytecode.object, deployedBytecode: $$FILE[0].deployedBytecode.object }' \
		>$@

build/sol/forge.fingerprint: foundry.toml $(shell find src -name '*.sol') test/SafeBytecode.sol
	@mkdir -p build/sol
	@$(DOCKERFOUNDRY) 'forge build $(FORGEBUILDFLAGS)'
	@touch $@

.PRECIOUS: test/%Bytecode.sol
test/%Bytecode.sol: build/yul/%.json
	@echo '// SPDX-License-Identifier: LGPL-3.0-only' >$@
	@echo 'pragma solidity ^0.8.0;' >>$@
	@echo '' >>$@
	@echo 'bytes constant BYTECODE =' >>$@
	@echo '    hex$(shell $(JQ) '.evm.bytecode.object' $<);' >>$@
	@echo 'bytes constant DEPLOYED_BYTECODE =' >>$@
	@echo '    hex$(shell $(JQ) '.evm.deployedBytecode.object' $<);' >>$@

.PRECIOUS: build/yul/%.json
build/yul/%.json: build/yul/%.output.json
	@$(JQ) -Mc '.contracts["src/$*.yul"]["$*"]' $< >$@

.PRECIOUS: build/yul/%.output.json
build/yul/%.output.json: build/yul/%.input.json
	@$(DOCKERSOLC) --standard-json <$< >$@
	@$(JQ) '(.errors // []) as $$e | $$e | map(.formattedMessage) | join("") | halt_error($$e | map(select(.severity == "error")) | length)' $@ \
		|| (rm $@; exit 1)

.PRECIOUS: build/yul/%.input.json
build/yul/%.input.json: src/%.yul yul.config.jq
	@mkdir -p build/yul
	@$(JQ) -Mcn --arg FILENAME $< --rawfile FILE $< -f yul.config.jq >$@
