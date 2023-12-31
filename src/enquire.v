import os { read_file }
import prantlf.jany { Any }
import prantlf.json { parse }
import prantlf.osutil { find_file }

fn find_package() !(string, string) {
	return find_file('package.json') or { error('package.json not found') }
}

fn read_json(file string) !Any {
	dfile := d.rwd(file)
	d.log('reading file "%s"', dfile)
	text := read_file(file)!
	return parse(text)!
}

fn get_name() !string {
	_, pkg_file := find_package()!
	pkg := read_json(pkg_file)!
	return if name := pkg.object()!['name'] {
		name.string()!
	} else {
		''
	}
}

fn get_current_version() !string {
	_, pkg_file := find_package()!
	pkg := read_json(pkg_file)!
	return if ver := pkg.object()!['version'] {
		ver.string()!
	} else {
		''
	}
}
