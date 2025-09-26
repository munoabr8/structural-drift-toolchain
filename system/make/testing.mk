# --- knobs ---
PIPE = python3 ci/dora/dora-refactor/main.py
PIPE_ARGS ?= ci/dora/events.ndjson

 
ALLOW     ?= PATH HOME CI GH_TOKEN LC_ALL
 



ISOLATE ?= vm                 # env | vm
VM ?= iso
IMG ?= 24.04



PIPE_CMD = $(strip \
  $(if $(filter .py,$(suffix $(PIPE))),python3 '$(PIPE)',\
  $(if $(filter .sh,$(suffix $(PIPE))),bash    '$(PIPE)',\
                                            '$(PIPE)')) \
  $(if $(PIPE_ARGS), $(PIPE_ARGS)))



.PHONY: run run-env run-vm vm-up vm-down

run: run-$(ISOLATE)

# --- env isolation (clean env, explicit allowlist) ---
run-env:
	@env -i $(foreach v,$(ALLOW),$(v)="$($(v))") \
	  bash -lc 'umask 0022; $(PIPE_CMD)'


# --- vm isolation (Ubuntu guest + mounted repo) ---
vm-up:
	multipass launch $(IMG) --name $(VM) --cpus 2 --mem 4G --disk 20G || true
	multipass mount . $(VM):/repo || true

run-vm: vm-up
	multipass exec $(VM) -- bash -lc 'umask 0022; cd /repo && $(PIPE)'

vm-down:
	multipass stop $(VM) || true; multipass delete $(VM) || true; multipass purge || true
