# x86_64 CPU architecture specifications
# The overview at https://github.com/InstLatx64/InstLatX64_Misc/tree/4802ff02415ed1ecdefddfd540615a27b617349c/SIMD_Euler may be helpful in defining this list
# Software path in EESSI 	| Vendor ID 	| List of defining CPU features
"x86_64/intel/haswell"		"GenuineIntel"	"avx2 fma"									# Intel Haswell, Broadwell
"x86_64/intel/skylake_avx512"	"GenuineIntel"	"avx2 fma avx512f avx512bw avx512cd avx512dq avx512vl"				# Intel Skylake
"x86_64/intel/cascadelake"	"GenuineIntel"	"avx2 fma avx512f avx512bw avx512cd avx512dq avx512vl avx512_vnni"	# Intel Cascade Lake
"x86_64/intel/icelake"	"GenuineIntel"	"avx2 fma avx512f avx512bw avx512cd avx512dq avx512vl avx512_vnni avx512_vbmi2"	# Intel Icelake Lake
"x86_64/intel/sapphirerapids"	"GenuineIntel"	"avx2 fma avx512f avx512bw avx512cd avx512dq avx512vl avx512_bf16 amx_tile"	# Intel Sapphire/Emerald Rapids
"x86_64/amd/zen2"		"AuthenticAMD"	"avx2 fma"									# AMD Rome
"x86_64/amd/zen3"		"AuthenticAMD"	"avx2 fma vaes"									# AMD Milan, Milan-X
"x86_64/amd/zen4"		"AuthenticAMD"	"avx2 fma vaes avx512f avx512ifma"						# AMD Genoa, Genoa-X
