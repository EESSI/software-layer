# Pull Request Template – EESSI Software Layer

## Description
<!-- Provide a clear and concise description of the changes introduced by this PR -->
- What does this PR do?
- Why is this change needed?

## Target File(s)
<!-- Confirm that this PR modifies the correct file(s) -->

For new software, the typical path format is:

    `easystacks/software.eessi.io/<EESSI version>/eessi-<EESSI version>-eb-<EasyBuild version>-<toolchain>.yml`

Example:

    easystacks/software.eessi.io/2025.06/eessi-2025.06-eb-5.3.0-2025a.yml

Please verify:

- [ ] I am targeting the **correct EESSI version** (e.g. `2025.06` for toolchain families `2025a`, `2023.06` for toolchain families `2023b`)
- [ ] I am using the **latest EasyBuild version** (e.g. `5.3.0`)
- [ ] I selected the **correct toolchain family** (e.g. `2025a`)
- [ ] I did **not** modify older or unrelated files

### Toolchain Notes
- The toolchain suffix (e.g. `2025a`) defines the compiler/MPI stack
- See documentation: https://docs.easybuild.io/common-toolchains/

### Rebuilds (if applicable)
<!-- Only fill this section if your PR is a rebuild -->

Rebuilds must be placed under the `rebuilds/` subdirectory:

    easystacks/software.eessi.io/<EESSI version>/rebuilds/<date>-eb-<EasyBuild version>-<description>.yml

Example:

    easystacks/software.eessi.io/2025.06/rebuilds/20260413-eb-5.3.0-RStudio-r_home-patch.yml

Please verify:

- [ ] This is a rebuild (not a standard addition/update)
- [ ] The file is placed in the correct `rebuilds/` directory
- [ ] The filename indicates the reason for the rebuild
- [ ] The file includes comments explaining **exactly why the rebuild is necessary**

## Type of Change
<!-- Mark relevant options -->
- [ ] New software addition
- [ ] Version update
- [ ] Bug fix
- [ ] Configuration change
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

