set dotenv-load

chain := env_var_or_default("CHAIN", "mainnet")
deploy_script_name := if chain == "mainnet" {
    "DeployMainnet"
} else if chain == "holesky" {
    "DeployHolesky"
} else {
    error("Unsupported chain " + chain)
}

upgrade_script_name := if chain == "mainnet" {
    "UpgradeMainnet"
} else if chain == "holesky" {
    "UpgradeHolesky"
} else {
    error("Unsupported chain " + chain)
}

deploy_script_path := "script" / deploy_script_name + ".s.sol:" + deploy_script_name
upgrade_script_path := "script" / upgrade_script_name + ".s.sol:" + upgrade_script_name

anvil_host := env_var_or_default("ANVIL_IP_ADDR", "127.0.0.1")
anvil_port := "8545"
anvil_rpc_url := "http://" + anvil_host + ":" + anvil_port

default: clean deps build test-all

build *args:
    forge build --force {{args}}

clean:
    forge clean
    rm -rf cache broadcast out node_modules

deps:
    yarn workspaces focus --all --production

deps-dev:
    yarn workspaces focus --all && npx husky install

lint-solhint:
    yarn lint:solhint

lint-fix:
    yarn lint:fix

lint:
    yarn lint:check

test-all:
    just test-unit &
    just test-local

test-unit *args:
    forge test --no-match-path 'test/fork/*' -vvv {{args}}

test-deployment *args:
    forge test --match-path 'test/fork/*' -vvv {{args}}

gas-report:
    #!/usr/bin/env python

    import subprocess
    import re

    command = "just test-unit --nmt 'testFuzz.+' --gas-report"
    output = subprocess.check_output(command, shell=True, text=True)

    lines = output.split('\n')

    filename = 'GAS.md'
    to_print = False
    skip_next = False

    with open(filename, 'w') as fh:
        for line in lines:
            if skip_next:
                skip_next = False
                continue

            if line.startswith('|'):
                to_print = True

            if line.startswith('| Deployment Cost'):
                to_print = False
                skip_next = True

            if re.match(r"Ran \d+ test suites", line):
                break

            if to_print:
                fh.write(line + '\n')

    print(f"Done. Gas report saved to {filename}")

coverage *args:
    FOUNDRY_PROFILE=coverage forge coverage --no-match-path 'test/fork/*' {{args}}

# Run coverage and save the report in LCOV file.
coverage-lcov *args:
    FOUNDRY_PROFILE=coverage forge coverage --no-match-path 'test/fork/*' --report lcov {{args}}

diffyscan-contracts *args:
    yarn generate:diffyscan {{args}}

make-fork *args:
    @if pgrep -x "anvil" > /dev/null; \
        then just _warn "anvil process is already running in the background. Make sure it's connected to the right network and in the right state."; \
        else anvil -f ${RPC_URL} --host {{anvil_host}} --port {{anvil_port}} --config-out localhost.json {{args}}; \
    fi

kill-fork:
    @-pkill anvil && just _warn "anvil process is killed"

# deploy production
deploy *args:
    forge script {{deploy_script_path}} --rpc-url {{anvil_rpc_url}} --broadcast --slow {{args}}

deploy-prod *args:
    just _warn "The current `tput bold`chain={{chain}}`tput sgr0` with the following rpc url: $RPC_URL"
    ARTIFACTS_DIR=./artifacts/latest/ just _deploy-prod-confirm {{args}}

    cp ./broadcast/{{deploy_script_name}}.s.sol/`cast chain-id --rpc-url=$RPC_URL`/run-latest.json \
        ./artifacts/latest/transactions.json

[confirm("You are about to broadcast deployment transactions to the network. Are you sure?")]
_deploy-prod-confirm *args:
    just _deploy-prod --broadcast --verify {{args}}

deploy-prod-dry *args:
    just _deploy-prod {{args}}

verify-prod *args:
    just _warn "Pass --chain=your_chain manually. e.g. --chain=holesky for testnet deployment"
    forge script {{deploy_script_path}} --rpc-url ${RPC_URL} --verify {{args}} --unlocked

_deploy-prod *args:
    forge script {{deploy_script_path}} --force --rpc-url ${RPC_URL} {{args}}

# upgrade production
upgrade *args:
    forge script {{upgrade_script_path}} --rpc-url {{anvil_rpc_url}} --broadcast --slow {{args}}

upgrade-prod *args:
    just _warn "The current `tput bold`chain={{chain}}`tput sgr0` with the following rpc url: $RPC_URL"
    ARTIFACTS_DIR=./artifacts/latest/ just _upgrade-prod-confirm {{args}}

    cp ./broadcast/{{upgrade_script_path}}.s.sol/`cast chain-id --rpc-url=$RPC_URL`/run-latest.json \
        ./artifacts/latest/transactions.json

[confirm("You are about to broadcast upgrade transactions to the network. Are you sure?")]
_upgrade-prod-confirm *args:
    just _upgrade-prod --broadcast --verify {{args}}

upgrade-prod-dry *args:
    just _upgrade-prod {{args}}

_upgrade-prod *args:
    forge script {{upgrade_script_path}} --force --rpc-url ${RPC_URL} {{args}}

# local deployment
deploy-local:
    just make-fork &
    @while ! echo exit | nc {{anvil_host}} {{anvil_port}} > /dev/null; do sleep 1; done
    ARTIFACTS_DIR=./artifacts/local/ just deploy
    just _warn "anvil is kept running in the background: {{anvil_rpc_url}}"

upgrade-local:
    just make-fork &
    @while ! echo exit | nc {{anvil_host}} {{anvil_port}} > /dev/null; do sleep 1; done
    ARTIFACTS_DIR=./artifacts/local/ just upgrade
    just _warn "anvil is kept running in the background: {{anvil_rpc_url}}"

test-local *args:
    just make-fork --silent &
    @while ! echo exit | nc {{anvil_host}} {{anvil_port}} > /dev/null; do sleep 1; done
    DEPLOYER_PRIVATE_KEY=`cat localhost.json | jq -r ".private_keys[0]"` \
    ARTIFACTS_DIR=./artifacts/local/ just deploy --silent
    DEPLOY_CONFIG=./artifacts/local/deploy-{{chain}}.json \
    RPC_URL={{anvil_rpc_url}} \
        just test-deployment {{args}}
    just kill-fork

_warn message:
    @tput setaf 3 && printf "[WARNING]" && tput sgr0 && echo " {{message}}"
