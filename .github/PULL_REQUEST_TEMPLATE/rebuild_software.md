# Pull Request Template for rebuilding software – EESSI Software Layer

## Description
<!--
Give some context for the changes introduced by this PR
- Why is the rebuild necessary?
- What are the potential positive/negative impacts?
- ...
-->

## Target File(s)
<!--
Confirm that this PR modifies the correct file(s)
Rebuilds must be placed under the `rebuilds/` subdirectory:
- `easystacks/software.eessi.io/<EESSI version>/rebuilds/<date>-eb-<EasyBuild version>-<description>.yml`
Example:
- `easystacks/software.eessi.io/2025.06/rebuilds/20260413-eb-5.3.0-RStudio-r_home-patch.yml`
-->

Please verify:

<!-- Mark relevant options with an [x] -->
- [ ] This is a rebuild (not a standard addition/update)
- [ ] I am targeting the **correct EESSI version** (e.g. `2025.06` for toolchain families `2025a`, `2023.06` for toolchain families `2023b`)
- [ ] The file is placed in the correct `rebuilds/` directory
- [ ] I am using the **latest EasyBuild version** (e.g. `5.3.0`)
- [ ] The filename gives some indication of the reason for the rebuild
- [ ] The file includes comments explaining **exactly why the rebuild is necessary**
- [ ] I did **not** modify older or unrelated files

## Testing
<!-- Describe how you validated your changes -->
<!-- Mark relevant options with an [x] -->
- [ ] I have tested this PR locally using **EESSI-extend**
  <!-- Hint:
      module load EESSI/<EESSI version>
      module load EESSI-extend
      # Show what will be rebuilt 
      eb --missing --rebuild --easystack <path to easystack>
      # Perform the build (no dependencies are to be built, so no `--robot`)
      eb --rebuild --easystack <path to easystack>
  -->
- [ ] The build completed successfully
- [ ] The installed software/module loads correctly
- [ ] Basic functionality has been verified

