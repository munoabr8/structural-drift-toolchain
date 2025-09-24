VM=iso

vm/up:
	multipass launch 24.04 --name $(VM) --cpus 2 --mem 4G --disk 20G || true
	multipass mount . $(VM):/repo || true

vm/run:
	
	multipass exec $(VM) -- bash -lc 'umask 0022; cd /repo && bash ./ci/env/isolate_ci.sh'

vm/down:
	multipass stop $(VM) || true
	multipass delete $(VM) || true
	multipass purge || true
