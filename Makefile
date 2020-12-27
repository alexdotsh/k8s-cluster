SHELL := /bin/bash
ANSIBLE_WORK_DIR := ${PWD}

define docker_run_ansible
	@docker run --rm -it \
		-v ${ANSIBLE_WORK_DIR}/hosts:/etc/ansible/hosts \
		-v ${ANSIBLE_WORK_DIR}/ansible.cfg:/etc/ansible/ansible.cfg \
		-v ${HOME}/.ssh/ansible:/root/.ssh:ro \
		-v ${ANSIBLE_WORK_DIR}/playbooks/$(1):/playbooks \
		ansible ansible-playbook $(2).yml
endef

define docker_run_ansible_with_tags
	@docker run --rm -it \
		-v ${ANSIBLE_WORK_DIR}/hosts:/etc/ansible/hosts \
		-v ${ANSIBLE_WORK_DIR}/ansible.cfg:/etc/ansible/ansible.cfg \
		-v ${HOME}/.ssh/ansible:/root/.ssh:ro \
		-v ${ANSIBLE_WORK_DIR}/playbooks/$(1):/playbooks \
		ansible ansible-playbook $(2).yml --tags $(3)
endef

install_docker:
	$(call docker_run_ansible,utils,install)
	$(call docker_run_ansible,docker,site)

install_kubernetes_prerequisites:
	$(call docker_run_ansible,utils,system)
	$(call docker_run_ansible,utils,disable_swap)
	$(call docker_run_ansible_with_tags,ubuntu,site,"cgroup_enable_memory")
	install_docker

install_kubernetes:
	install_kubernetes_prerequisites
	$(call docker_run_ansible_with_tags,kubernetes,site,"install,endpoint")

join_nodes:
	$(call docker_run_ansible_with_tags,kubernetes,site,"generate_tokens,join_node")

upgrade_kubeadm:
	$(call docker_run_ansible_with_tags,kubernetes,site,"upgrade")

kubeadm_reset_and_init:

uninstall_kubernetes:
	$(call docker_run_ansible_with_tags,kubernetes,site,"uninstall")

uninstall_docker:
	$(call docker_run_ansible_with_tags,docker,site,"uninstall")
	$(call docker_run_ansible,utils,uninstall)

install_weave_net_pod_network:
	$(call docker_run_ansible_with_tags,kubernetes,site,"add_weave_net")

delete_weave_net_pod_network:
	# $(call docker_run_ansible_with_tags,kubernetes,site,"remove_weave_net_resources")
	$(call docker_run_ansible_with_tags,kubernetes,site,"remove_weave_net_configs")

install_flannel_pod_network:
	$(call docker_run_ansible_with_tags,kubernetes,site,"add_flannel")

delete_flannel_pod_network:
	$(call docker_run_ansible_with_tags,kubernetes,site,"remove_flannel_resources")
	$(call docker_run_ansible_with_tags,kubernetes,site,"remove_flannel_configs")

install_canal_pod_network:
	$(call docker_run_ansible_with_tags,kubernetes,site,"add_canal")

delete_canal_pod_network:
	$(call docker_run_ansible_with_tags,kubernetes,site,"remove_canal_resources")
	$(call docker_run_ansible_with_tags,kubernetes,site,"remove_canal_configs")

build_cni_plugins:
	$(call docker_run_ansible_with_tags,kubernetes,site,"build_cni_plugins")

build_cluster_with_flannel:
	install_kubernetes
	join_nodes
# system
# kubeadm
	install_flannel_pod_network

build_cluster_with_weave_net:
	# install_kubernetes
	# join_nodes
	$(call docker_run_ansible_with_tags,kubernetes,site,"system")
	$(call docker_run_ansible_with_tags,kubernetes,site,"kubeadm")
	# system
	# kubeadm
	# install_weave_net_pod_network

# reset_kubeadm_slave_nodes:
# 	$(call docker_run_ansible_with_tags,kubernetes,site,"reset_slave_nodes")

# reset_kubeadm_master_nodes:
# 	$(call docker_run_ansible_with_tags,kubernetes,site,"reset_master_nodes")
