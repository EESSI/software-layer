# ARM CPU architecture specifications (see https://gpages.juszkiewicz.com.pl/arm-socs-table/arm-socs.html for guidance)
# Software path in EESSI 	| Vendor ID 	| List of defining CPU features
"aarch64/a64fx"	""		"asimdhp sve"		# Fujitsu A64FX
"aarch64/neoverse_n1"	"ARM"		"asimddp"		# Ampere Altra
"aarch64/neoverse_n1"	""		"asimddp"		# AWS Graviton2
"aarch64/neoverse_v1"	"ARM"		"asimddp svei8mm"
"aarch64/neoverse_v1"	""		"asimddp svei8mm"	# AWS Graviton3
