from easybuild.framework.easystack import parse_easystack
import sys 

test = parse_easystack(sys.argv[1])

print(test)