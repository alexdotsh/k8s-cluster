SHELL := /bin/bash -o pipefail
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

build_cluster:
	install_kubernetes
	join_nodes

join_nodes:
	$(call docker_run_ansible_with_tags,kubernetes,site,"generate_tokens,join_node")

uninstall_kubernetes:
	$(call docker_run_ansible_with_tags,kubernetes,cleanup,"cleanup")

uninstall_docker:
	$(call docker_run_ansible,docker,cleanup)
	$(call docker_run_ansible,utils,uninstall)
