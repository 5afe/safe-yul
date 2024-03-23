DOCKER ?= docker
JQ ?= jq

SOLC := docker.io/ethereum/solc:0.8.25
FOUNDRY := ghcr.io/foundry-rs/foundry

FORGEFLAGS ?= '-vvv'

.PHONY: all
all: artifacts/Safe.json

.PHONY: test
test: test/SafeBytecode.sol
	@$(DOCKER) run --rm -it -v $(PWD):/src:z -w /src $(FOUNDRY) 'forge test $(FORGEFLAGS)'

.PHONY: fmt
fmt:
	@$(DOCKER) run --rm -it -v $(PWD):/src:z -w /src $(FOUNDRY) 'forge fmt src/*.sol test/*.sol'

.PHONY: opcodes
opcodes: build/Safe.yul.output.json
	@$(JQ) -r '.contracts["src/Safe.yul"]["Safe"].evm.deployedBytecode.opcodes' $< \
		| sed -E -e 's/(PUSH[1-9][0-9]?) ([^ ]*)/\1,\2/g' -e 's/ +$$//' -e 's/([^ ]*) /\1\n/g' -e 's/,/ /g' \
		| awk '/PUSH[1-9][0-9]?/ { b=2+2*substr($$1,5)-length($$2); if (b!=0) { $$2=sprintf("0x%0" b "d%s",0,substr($$2,3)) } } { print }' \
		| awk '{ printf "%04x: %s\n",x,$$0; x+=1 } /PUSH[1-9][0-9]?/ { x+=substr($$1,5) }'

.PHONY: clean
clean:
	@rm -rf artifacts/ build/

artifacts/Safe.json: build/Safe.yul.output.json build/ISafe.sol.output.json
	@mkdir -p artifacts/
	@$(JQ) -Mn \
		--argjson SAFE '$(shell $(JQ) '.contracts["src/Safe.yul"]["Safe"]' build/Safe.yul.output.json)' \
		--argjson ISAFE '$(shell $(JQ) '.contracts["src/ISafe.sol"]["ISafe"]' build/ISafe.sol.output.json)' \
		'{ contractName: "Safe", abi: $$ISAFE.abi, bytecode: $$SAFE.evm.bytecode.object, deployedBytecode: $$SAFE.evm.deployedBytecode.object }' \
		>$@

test/SafeBytecode.sol: artifacts/Safe.json
	@echo '// SPDX-License-Identifier: LGPL-3.0-only' > $@
	@echo 'pragma solidity ^0.8.0;' >> $@
	@echo '' >> $@
	@echo 'bytes constant BYTECODE = hex$(shell $(JQ) '.bytecode' artifacts/Safe.json);' >> $@
	@echo 'bytes constant DEPLOYED_BYTECODE = hex$(shell $(JQ) '.deployedBytecode' artifacts/Safe.json);' >> $@

.PRECIOUS: build/%.output.json
build/%.output.json: build/%.input.json
	@$(DOCKER) run --rm -i $(SOLC) --standard-json <$< >$@
	@$(JQ) '(.errors // []) as $$e | $$e | map(.formattedMessage) | join("") | halt_error($$e | map(select(.severity == "error")) | length)' $@ \
		|| (rm $@; exit 1)

.PRECIOUS: build/%.input.json
build/%.input.json: src/% solc.config.jq
	@mkdir -p build/
	@$(JQ) -Mcn --arg FILENAME $< --rawfile FILE $< -f solc.config.jq >$@
