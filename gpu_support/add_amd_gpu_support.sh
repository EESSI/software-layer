cat << EOF
This is not implemented yet :(

If you would like to contribute this support there are a few things you will
need to consider:
- We will need to change the Lmod property added to GPU software so we can
  distinguish AMD and Nvidia GPUs
- Support should be implemented in user space, if this is not possible (e.g.,
  requires a driver update) you need to tell the user what to do
- Support needs to be _verified_ and a trigger put in place (like the existence
  of a particular path) so we can tell Lmod to display the associated modules
EOF
