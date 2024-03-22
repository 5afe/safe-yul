DOCKER ?= docker
JQ ?= jq

SOLC := docker.io/ethereum/solc:0.8.25
FOUNDRY := ghcr.io/foundry-rs/foundry

.PHONY: all
all: artifacts/Safe.json

.PHONY: test
test: artifacts/test/Safe.sol

.PHONY: clean
clean:
	@rm -rf artifacts/ build/

artifacts/test/Safe.sol: artifacts/Safe.json src/ISafe.sol
	@mkdir -p artifacts/test/
	@cp src/ISafe.sol $@
	@echo '' >> $@
	@echo 'bytes constant BYTECODE = hex$(shell $(JQ) '.bytecode' artifacts/Safe.json);' >> $@
	@echo 'bytes constant DEPLOYED_BYTECODE = hex$(shell $(JQ) '.deployedBytecode' artifacts/Safe.json);' >> $@

artifacts/Safe.json: build/Safe.yul.output.json build/ISafe.sol.output.json
	@mkdir -p artifacts/
	@$(JQ) -Mn \
		--argjson SAFE '$(shell $(JQ) '.contracts["src/Safe.yul"]["Safe"]' build/Safe.yul.output.json)' \
		--argjson ISAFE '$(shell $(JQ) '.contracts["src/ISafe.sol"]["ISafe"]' build/ISafe.sol.output.json)' \
		'{ contractName: "Safe", abi: $$ISAFE.abi, bytecode: $$SAFE.evm.bytecode.object, deployedBytecode: $$SAFE.evm.deployedBytecode.object }' \
		>$@

.PRECIOUS: build/%.output.json
build/%.output.json: build/%.input.json
	@$(DOCKER) run -i $(SOLC) --standard-json <$< >$@
	@$(JQ) '(.errors // []) as $$e | $$e | map(.formattedMessage) | join("") | halt_error($$e | map(select(.severity == "error")) | length)' $@ \
		|| (rm $@; exit 1)

.PRECIOUS: build/%.input.json
build/%.input.json: src/% solc.config.jq
	@mkdir -p build/
	@$(JQ) -Mcn --arg FILENAME $< --rawfile FILE $< -f solc.config.jq >$@
