# Pull Request Template for adding software – EESSI Software Layer

(If you need a PR template for a rebuild, open the Preview tab in this comment and [click here](?expand=1&template=rebuild_softare.md))

## Description
<!-- Give some context for the changes introduced by this PR -->
- What is the software being added?
- What domain does it serve?
- Why are you adding it?
- ...

## Target File(s)
<!-- Confirm that this PR modifies the correct file(s) -->

For new software, the typical path format is:

- `easystacks/software.eessi.io/<EESSI version>/eessi-<EESSI version>-eb-<EasyBuild version>-<toolchain>.yml`

Example:

- `easystacks/software.eessi.io/2025.06/eessi-2025.06-eb-5.3.0-2025a.yml`

Please verify:

- [ ] I am targeting the **correct EESSI version** (e.g. `2025.06` for toolchain families `2025a`, `2023.06` for toolchain families `2023b`)
- [ ] I am using the **latest EasyBuild version** (e.g. `5.3.0`)
- [ ] I selected the **correct toolchain family** (e.g. `2025a`)
- [ ] I did **not** modify older or unrelated files

### Toolchain Notes

- The toolchain suffix (e.g. `2025a`) defines the compiler/MPI stack.
- See documentation: https://docs.easybuild.io/common-toolchains/

Sometimes it can be difficult to figure out which suffix your software belongs to, if in doubt please ask for help on
the [EESSI slack](https://join.slack.com/t/eessi-hpc/shared_invite/zt-2wg10p26d-m_CnRB89xQq3zk9qxf1k3g)

## Type of Change
<!-- Mark relevant options -->
- [ ] New software addition
- [ ] Version update
- [ ] Other (please specify):

## Testing
<!-- Describe how you validated your changes -->
- [ ] I have tested this PR locally using **EESSI-extend**
  <!-- Hint:
  
      module load EESSI/<EESSI version>
      module load EESSI-extend

      # Show what will be built
      eb --missing --easystack <path to easystack>

      # Perform the build
      eb --robot --easystack <path to easystack>
  -->
- [ ] The build completed successfully
- [ ] The installed software/module loads correctly
- [ ] Basic functionality has been verified

