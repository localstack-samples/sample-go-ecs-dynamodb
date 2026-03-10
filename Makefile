export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

.PHONY: test run deploy destroy build_docker run_docker start stop ready logs

.EXPORT_ALL_VARIABLES:
AWS_PROFILE = default
AWS_REGION = us-east-1

start:		## Start LocalStack
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) localstack start -d

stop:		## Stop LocalStack
	@localstack stop

ready:		## Wait until LocalStack is ready
	@echo Waiting on the LocalStack container...
	@localstack wait -t 30 && echo LocalStack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

logs:		## Save the logs in a separate file
	@localstack logs > logs.txt

run:
	cd cmd && go run main.go

build_docker:
	docker build -t ddb-local-fargate .

run_docker: build_docker
	docker run -it -e PARAM1=test1 -p 5050:5050 -e AWS_PROFILE=${AWS_PROFILE} -v ${HOME}/.aws:/root/.aws ddb-local-fargate

test:
	docker-compose up --detach;
	pushd pkg/service && go test;
	popd;
	docker-compose down;

deploy:
	cd cdk;\
	cdklocal bootstrap && cdklocal deploy '*'

destroy:
	cd cdk;\
	cdklocal destroy \*
