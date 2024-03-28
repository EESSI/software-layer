# x86_64 CPU architecture specifications
# Software path in EESSI 	| Vendor ID 	| List of defining CPU features
"x86_64/intel/haswell"		"GenuineIntel"	"avx2 fma" 						# Intel Haswell, Broadwell
"x86_64/intel/skylake_avx512"	"GenuineIntel"	"avx2 fma avx512f avx512bw avx512cd avx512dq avx512vl"	# Intel Skylake, Cascade Lake
"x86_64/amd/zen2"		"AuthenticAMD"	"avx2 fma"						# AMD Rome
"x86_64/amd/zen3"		"AuthenticAMD"	"avx2 fma vaes"						# AMD Milan, Milan-X
"x86_64/amd/zen4"		"AuthenticAMD"	"avx2 fma vaes avx512f avx512ifma"			# AMD Genoa, Genoa-X
