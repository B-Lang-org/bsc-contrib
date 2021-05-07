####################

if { ! [info exists contribtest] } then {

    # Look for this environment variable
    set var BSCCONTRIBDIR

    if { [info exists env($var)] && [file isdirectory $env($var)] } then {
	set contrib_inst $env($var)
	set contribtest 1
    } else {
	set contrib_inst ""
	set contribtest 0
    }

    verbose -log "Do contrib tests is $contribtest" 1
    if { $contribtest } {
	verbose -log "Contrib inst is $contrib_inst" 1
    }

}

####################

proc add_contrib_dirs_to_path { dirs } {
    global old_option
    global contrib_inst

    # Make sure the tools are initialized first
    # so that they aren't initialized with the new path
    # (in case the caller gave bad values)
    bsc_initialize
    bluetcl_initialize

    # Record the current path
    set old_option ""
    if { [info exists ::env(BSC_OPTIONS)] } {
	set old_option $::env(BSC_OPTIONS)
    }

    set libdir "$contrib_inst/lib/Libraries"

    if { [llength $dirs] > 0 } {
	append ::env(BSC_OPTIONS) " -p "
	foreach d $dirs {
	    append ::env(BSC_OPTIONS) "$libdir/$d:"
	}
	    append ::env(BSC_OPTIONS) "+"
    }	
}

proc restore_path { } {
    global old_option

    set ::env(BSC_OPTIONS) $old_option
}

####################
