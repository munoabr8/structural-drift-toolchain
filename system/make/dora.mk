# included from root Makefile
.PHONY: exact clean dora-env

exact:
	test/exact.sh

dora-env:
	env -i PATH="$$PATH" TZ=UTC LC_ALL=C python3 ci/dora/compute-dora.py --show-env

clean:
	rm -rf ./.tmp.dora
