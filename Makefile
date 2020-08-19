
# Image URL to use all building/pushing image targets
IMG ?= fluxcd/image-automation-controller
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true"

# Versions of the Toolkit components from which to get CRDs. Change this if you
# bump the go module version.
SOURCE_VERSION:=v0.0.10

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

TEST_CRDS:=controllers/testdata/crds

all: manager

# Running the tests requires the source.toolkit.fluxcd.io CRDs
test_deps: ${TEST_CRDS}/imagepolicies.yaml ${TEST_CRDS}/gitrepositories.yaml

clean_test_deps:
	rm -r ${TEST_CRDS}

${TEST_CRDS}/gitrepositories.yaml:
	mkdir -p ${TEST_CRDS}
	curl -s https://raw.githubusercontent.com/fluxcd/source-controller/${SOURCE_VERSION}/config/crd/bases/source.toolkit.fluxcd.io_gitrepositories.yaml \
		-o ${TEST_CRDS}/gitrepositories.yaml

${TEST_CRDS}/imagepolicies.yaml:
	mkdir -p ${TEST_CRDS}
	curl -s https://raw.githubusercontent.com/fluxcd/image-reflector-controller/main/config/crd/bases/image.toolkit.fluxcd.io_imagepolicies.yaml \
		-o ${TEST_CRDS}/imagepolicies.yaml

# Run tests
test: test_deps generate fmt vet manifests
	go test ./... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet manifests
	go run ./main.go

# Install CRDs into a cluster
install: manifests
	kustomize build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall: manifests
	kustomize build config/crd | kubectl delete -f -

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	cd config/manager && kustomize edit set image controller=${IMG}
	kustomize build config/default | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Build the docker image
docker-build: test
	docker build . -t ${IMG}

# Push the docker image
docker-push:
	docker push ${IMG}

# find or download controller-gen
# download controller-gen if necessary
controller-gen:
ifeq (, $(shell which controller-gen))
	@{ \
	set -e ;\
	CONTROLLER_GEN_TMP_DIR=$$(mktemp -d) ;\
	cd $$CONTROLLER_GEN_TMP_DIR ;\
	go mod init tmp ;\
	go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.3.0 ;\
	rm -rf $$CONTROLLER_GEN_TMP_DIR ;\
	}
CONTROLLER_GEN=$(GOBIN)/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif
