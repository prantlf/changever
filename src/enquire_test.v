module main

import os { getwd }

fn test_find_package() {
	cwd := getwd()
	dir, name := find_package()!
	assert dir == cwd
	assert name == '${cwd}${os.path_separator}package.json'
}

fn test_read_json() {
	any := read_json('package.json')!
	assert any.get('name')!.string()! == 'changever'
}

fn test_get_name() {
	name := get_name()!
	assert name == 'changever'
}

fn test_get_current_version() {
	ver := get_current_version()!
	assert ver.len > 0
}
