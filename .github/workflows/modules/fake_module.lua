setenv("INSIDE_GITHUB_ACTIONS", "true")
-- Interfere with PATH so Lmod keeps a record
prepend_path("PATH", "/snap/bin")
