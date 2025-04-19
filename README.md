## 📁 Project Structure (Declared)

<!-- structure-spec:start -->
This project enforces a filesystem contract using `structure.spec`.

Example structure:

- `dir: ./attn`
- `file: ./attn/context-status.sh`
- `link: linked/context.sh -> attn/context-status.sh`

Run `make enforce-structure` to validate.

<!-- structure-spec:end -->



✅ structure.spec is the source of truth	If your spec isn’t correct, any auto-doc will lie.
✅ README sections should reflect actual enforced structure	You’re not documenting ideas — you’re exposing constraints.
✅ Devs will still need to write higher-level documentation manually	We’re not replacing the whole README, just sections 
of it.
✅ Auto-generated sections won’t be edited manually	Otherwise, regen wipes local edits.
✅ The generation process is intentional, not automatic on every run



✅ structure.spec always uses a stable, parseable format	If someone writes weird free-form lines, the generator 
breaks or misleads.
✅ Auto-generated content is clearly delimited	So it can be safely replaced without touching the rest of the README.
✅ Generator is idempotent	Re-running it shouldn’t create duplicates or inconsistencies.
✅ Manual and auto content are kept separate	You must not allow human edits inside the generated block.
✅ Auto-gen only runs on demand (make update-docs)




# Future idea:
# make document-structure-spec → auto-inject structure summary into README

#Each line in `structure.spec` must be one of:

#- `dir: ./folder`
#- `file: ./path/to/file.sh`
#- `link: ./link.sh -> ./real/target.sh`

#Lines starting with `#` are comments and ignored.

