VM=iso

vm/up:
	multipass launch 24.04 --name $(VM) --cpus 2 --mem 4G --disk 20G || true
	multipass mount . $(VM):/repo || true

vm/run:
	
	multipass exec $(VM) -- bash -lc 'umask 0022; cd /repo && bash ./ci/enviornment/isolate_ci.sh'

vm/down:
	multipass stop $(VM) || true
	multipass delete $(VM) || true
	multipass purge || true



vm/all:   vm/up vm/run vm/doctor


vm/doctor:
	@$(MAKE) -f system/make/vm.mk vm/run CMD='bash ci/where.sh'
