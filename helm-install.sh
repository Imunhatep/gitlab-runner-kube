#!/bin/bash

kubectl create ns kube-deployer; \
	helm install kube-deployer -n kube-deployer -f values/values.yaml ./charts/kube-deployer
