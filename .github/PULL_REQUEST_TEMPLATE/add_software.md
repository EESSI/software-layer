<!-- Pull Request Template for adding software – EESSI Software Layer -->
<!-- (comments look like this, beginning with what is at the start of this line
and ending with what is at the end of this one, so they can be multiline!) -->

(If you need a PR template for a rebuild, open the Preview tab in this comment
and [click here](?expand=1&template=rebuild_software.md). Otherwise delete this line)

## Description
<!--
Give some context for the changes introduced by this PR
- What is the software being added?
- What domain does it serve?
- Why are you adding it?
- ...
-->

## Target File(s)
<!--
Confirm that this PR modifies the correct file(s)
For new software, the typical path format is:
- `easystacks/software.eessi.io/<EESSI version>/eessi-<EESSI version>-eb-<EasyBuild version>-<toolchain>.yml`
Example:
- `easystacks/software.eessi.io/2025.06/eessi-2025.06-eb-5.3.0-2025a.yml`
-->


Please verify:

<!-- Mark relevant options with an [x] -->
- [ ] I am targeting the [**correct EESSI version**](https://www.eessi.io/docs/repositories/versions/)
  (e.g. `2025.06` for toolchain generation `2025a`, `2023.06` for toolchain generation `2023b`)
- [ ] I am using the [**latest EasyBuild version**](https://pypi.org/project/easybuild/) (e.g. `5.3.0`)
- [ ] I selected the **correct toolchain generation** (e.g. `2025a`)
- [ ] I did **not** modify other unrelated files

<!--
### Toolchain Notes
- The toolchain suffix (e.g. `2025a`) defines the compiler/MPI stack.
- See documentation: https://docs.easybuild.io/common-toolchains/
Sometimes it can be difficult to figure out which suffix your software belongs to, if in doubt please ask for help on
the [EESSI slack](https://join.slack.com/t/eessi-hpc/shared_invite/zt-2wg10p26d-m_CnRB89xQq3zk9qxf1k3g)
-->

## Type of Change
<!-- Mark relevant options with an [x] -->
- [ ] New software addition
- [ ] Version update
- [ ] Other (please specify):

## Testing
<!-- Describe how you validated your changes -->
- [ ] I have tested this PR locally using [**EESSI-extend**](https://www.eessi.io/docs/using_eessi/building_on_eessi/#using-the-eessi-extend-module)
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
