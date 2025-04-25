# ARM CPU architecture specifications (see https://gpages.juszkiewicz.com.pl/arm-socs-table/arm-socs.html for guidance)
# CPU implementers: 0x41 (ARM), 0x46 (Fujitsu) - also see https://github.com/hrw/arm-socs-table/blob/main/data/socs.yml
# To ensure that archdetect produces the correct ordering, CPU targets should be listed from the most specific
# to the most general. In particular, if CPU target A is a subset of CPU target B, then A must be listed before B

# Software path in EESSI 	| 'Vendor ID' or 'CPU implementer' 	| List of defining CPU features
"aarch64/a64fx"		"0x46"		"asimdhp sve"		# Fujitsu A64FX
"aarch64/neoverse_n1"	"ARM"		"asimddp"		# Ampere Altra
"aarch64/neoverse_n1"	"0x41"		"asimddp"		# AWS Graviton2
"aarch64/neoverse_v1"	"ARM"		"asimddp svei8mm"
"aarch64/neoverse_v1"	"0x41"		"asimddp svei8mm"	# AWS Graviton3
"aarch64/nvidia/grace"	"0x41"		"sve2 sm3 sm4 svesm4"		# NVIDIA Grace
"aarch64/google/axion"	"0x41"		"sve2 rng sm3 sm4 svesm4"	# Google Axion
