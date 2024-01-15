File naming matters, since it determines the order in which easystack files are processed.

Software installed with system toolchain should be installed first,
this includes EasyBuild itself, see `eessi-2023.06-eb-4.8.2-001-system.yml` .

CUDA installations must be done before CUDA is required as dependency for something
built with a non-system toolchain, see `eessi-2023.06-eb-4.8.2-010-CUDA.yml` .
