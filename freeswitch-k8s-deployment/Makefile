# Makefile

.PHONY: build deploy cleanup

build:
	docker build -t freeswitch:latest ./docker

deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/persistentvolume.yaml
	kubectl apply -f k8s/persistentvolumeclaim.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml

cleanup:
	kubectl delete -f k8s/service.yaml || true
	kubectl delete -f k8s/deployment.yaml || true
	kubectl delete -f k8s/persistentvolumeclaim.yaml || true
	kubectl delete -f k8s/persistentvolume.yaml || true
	kubectl delete -f k8s/configmap.yaml || true
	kubectl delete -f k8s/namespace.yaml || true