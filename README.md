## 📁 Project Structure (Declared)

<!-- structure-spec:start -->
This project enforces a filesystem contract using `structure.spec`.

Example structure:

- `dir: ./attn`
- `file: ./attn/context-status.sh`
- `link: linked/context.sh -> attn/context-status.sh`

Run `make enforce-structure` to validate.

<!-- structure-spec:end -->



# Future idea:
# make document-structure-spec → auto-inject structure summary into README

#Each line in `structure.spec` must be one of:

#- `dir: ./folder`
#- `file: ./path/to/file.sh`
#- `link: ./link.sh -> ./real/target.sh`

#Lines starting with `#` are comments and ignored.

