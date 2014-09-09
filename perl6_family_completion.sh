# bash completion for the Perl6 family
# Put this in your bash_completion directory or add
# 'source path/to/dir/perl6_family_completion.sh' to your bashrc and
# running shells.

##PERL6_COMMON>>
# Prepending with _perl6_ so there are no conflicts when sourcing multiple files
_perl6_match() { # Succeeds if argument is repeated. Must be an EXACT MATCH.
		#usage,  _perl6_match 'str to match' a list of str #returns fale/1; 
		#usage,  _perl6_match 'matched str' a 'matched str' was found  #returns true/0; 
	repcur="$1"
	shift
	for val in "$@"; do
		[[ "${repcur}" == "${val}" ]] && return 0
	done
	return 1
}
_perl6_assoc() { # Removes associated arguments. usage, from _perl6_rem: _perl6_assoc $i -h --help 
	asscur=$1; shift
	akv=($@)
	for (( k=0; k<$((${#akv[@]}-1)); k+=2)); do
		v=$(($k+1))
		[[ "$asscur" == "${akv[$k]}" ]] && {
			COMPREPLY=" ${COMPREPLY[@]} "
			COMPREPLY=(${COMPREPLY/ ${akv[$v]%% *} / })
		}
		[[ "$asscur" == "${akv[$v]}" ]] && {
			COMPREPLY=" ${COMPREPLY[@]} "
			COMPREPLY=(${COMPREPLY/ ${akv[$k]%% *} / })
		}
	done
	printf "%s\n" "${COMPREPLY[@]}"
}
_perl6_seper() { # Prints the arguments that are deliminated by 'cnt' number of 'sep's. ie:
		# _perl6_seper 1 '--' -a -1 -- -2 -b -- c 3 ; #yeilds -2 -b; _perl6_seper 0 yeilds -a -1
	cnt=$1; shift
	sep=$1; shift
	args=("$@")
	idx=0
	zarg=0
	for ((iter=0; iter<=$cnt; iter++)); do
		zarg=1
		while [[ "$idx" -lt "${#args[@]}" ]]; do
			zarg=0
			arg="${args[$idx]}"; ((idx++))
			[[ "$arg" == "$sep" ]] && {
				[ "$iter" -eq "$cnt" ] && return 0
				break
			}
			[[ "$iter" == "$cnt" ]] && printf "%s\n" "${arg}" # Im not sure how this will handle spaces
		done
		[ "$zarg" -ne "0" ] && return 1
		iterend=$iter
	done 
	[ "$iterend" -eq "$cnt" ] && return 0 # may chose to do 3 way in future
	return 1
}
# NOTE: This slows things down!
# Taken from gentoo's adaption of Ian Macdonald's bash_completion.
# (Adapted from bash_completion by Ian Macdonald <ian@caliban.org>)
# This removes any options from the list of completions that have
# already been specified on the command line.
_perl6_rem() {	# removes arguments previously used.
				# _perl6_rem repeatable words -- associated pairs -- words we shouldn't add spaces after
	rep_words=($(_perl6_seper '0' '--' "$@"))		# These words can be repeated 
	assoc_words=($(_perl6_seper '1' '--' "$@"))		# These words are paired. If we have seen one, we will not sugest either.
	nospace_words=($(_perl6_seper '2' '--' "$@"))	# these words should not have a space appended to them (eg. --output= )
	# NOTE i wonder why he didnt use a for loop? (would IFS need to be changed?)
	COMPREPLY=($(echo "${COMP_WORDS[@]}" | \
		(while read -d ' ' i; do
			[[ -z ${i} ]] && continue							# next word if null.
			_perl6_match "${i}" "${rep_words[@]}" && continue		# next if word may repeat
			COMPREPLY=($(_perl6_assoc "${i}" "${assoc_words[@]}"))	# Remove word if its pair has been typed
			COMPREPLY=" ${COMPREPLY[@]} " # flatten array with spaces on either side, so we can grep on word boundaries of first and last word.
			COMPREPLY=("${COMPREPLY/ ${i%% *} / }") # remove word from list of completions
		done
		echo ${COMPREPLY[@]})))
		# If only one match was found, and that match is a nospace_word, tell bash not to add a space after the completion.
	[[ "${#COMPREPLY[@]}" -eq '1' ]] && [[ "${#nospace_words[@]}" -ge '1' ]] && {
		_perl6_match "$COMPREPLY" "${nospace_words[@]}" && compopt -o nospace
	}
	return 0
}
#_BC_dbg() { # used for debuging
#	fifo_pipe="${HOME}/tmp/pipe/perl6cmdcomp.fifo"
#	[[ -p "$fifo_pipe" ]] && echo "$@" > "$fifo_pipe"
#}
##PERL6_COMMON

# perl6 tab completion ----


_perl6() {
	local cur prev words cword
	_init_completion || return
	longargs="--doc --help --stagestats --ll-exception --profile"
	unlong="--target= --trace= --encoding= --output="
	shortargs="-c -h -e -n -p -t -o -v"
	unshort=''
	repargs="--output --encoding -e -n -p -o" # Repeatable Arguments
	assocargs="-h --help"	# Assosiated Arguments (only ones that cannot repeat)
	case $prev in
		--encoding)
			COMPREPLY=( $( compgen -W 'utf8'  -- "$cur" ) )
			return 0
			;;
	esac
	case "$cur" in
			'--encoding='*)
				# FIXME our '\=' is interpoliating to '='. Fix it or make --* yeild the same, 
				base='--encoding='
				COMPREPLY=( $( compgen -W '${base}utf8'  -- "$cur" ) )
				return 0
		  		;;
			--* )
				COMPREPLY=( $( compgen -W '$longargs $unlong' -- "$cur" ) )
				_perl6_rem $repargs '--' $assocargs -- $unlong
				return 0
				;;
			-* )
				COMPREPLY=( $( compgen -W '$shortargs' -- "$cur" ) )
				_perl6_rem $repargs '--' $assocargs
				return 0
				;;
			# Default, list paths
	esac
} # &&
complete -F _perl6 -o default perl6{,m,j,p} perl6-debug-{m,j,p}

# panda tab completion ----


_panda_read_json_perl() { # FIXME If we cannot do it all in perl5, we should do it all in perl6.
perl <<'HEREPERL'
	use feature qw{say};
	use utf8;
	binmode STDOUT, q{:utf8};
	use Module::Load::Conditional qw[can_load]; # builtin, so safe?
	my $json;
	my %Mods;
	my @CompUnits = qx{perl6 -e 'for @*INC { say $_.Str if $_.^name === "CompUnitRepo::Local::Installation" ;}'};
	chomp (@CompUnits);
	COMP_UNIT:
	foreach my $CompUnit (@CompUnits) {
		{
			local $/;
			next COMP_UNIT unless (-f $CompUnit . q{/panda/projects.json});
			open my $fh, q{<}, $CompUnit . q{/panda/projects.json};
			$json = <$fh>;
			close $fh;
		}
		# NOTE! Module::Load::Conditional::can_load return false if it can load the module, and true if it cannot. (is this a bug?)
		unless ( can_load(modules => q{JSON}) ) {
			require JSON; JSON->import(qw{decode_json});
	
			foreach ( @{decode_json($json)} ){
					$Mods{"$_->{name}"}=1; # consider getting installation status
			}
		} else { # because requiring perl5 mods wont fly
			while ($json =~ m/ \" name \" \: \" ([^\"]*) \" /gx) {
					$Mods{"$1"}=1;
			}
		}
	}
	foreach my $key (keys %Mods) {
		say "$key";
	}
HEREPERL
}

_panda_modules() { # TIMTOWTDI. (actualy, I think the container may change in future versions(or implimintations).. but feel free to try seding/greping/whatever instead)
	# store the output into $out. so we can check if modules were found and try another command if it failed.
	out="$(_panda_read_json_perl 2>/dev/null)" # First try to read any/all projects.json files (created by panda on update/list/search/install)
	[[ -z "$out" ]] && { 
		# Last resort, use 'panda list'. This both alows us to do completion without a projects.json,
		out="$(panda list | awk '{print $1}')" 2>/dev/null # and generates one for faster completion next time
	}
	echo "$out"
	unset out
	# TODO fallback onto panda search (search should also generate a prjojects.json if it doesn't exist)
}


_panda() {
	local cur prev words cword
	_init_completion || return
	# Dont treat ':' as a wordbreak. Fixes our issue #1, our first bug! (Thanks moritz)
	COMP_WORDBREAKS=${COMP_WORDBREAKS//:} # NOTE Im not sure if I am suppose to define it here...
	list_args="--verbrose --installed"
	install_args="--notests --nodeps"
	case $prev in
		install|--notests|--nodeps)
			#COMPREPLY=( $( compgen -W 'install $install_args $( _panda_modules )'  -- "$cur" ) )
			COMPREPLY=( $( compgen -W 'install $install_args'  -- "$cur" ) )
			_perl6_match 'install' "$prev" "${COMP_WORDS[@]}" && COMPREPLY+=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
		list|--verbrose|--installed)
			COMPREPLY=( $( compgen -W 'list $list_args' -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
		search|info|update)
			COMPREPLY=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
	esac
	if _perl6_match 'install' "$prev" "${COMP_WORDS[@]}" ; then # I am assuming install eats the rest of the line
		COMPREPLY+=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
		return 0;
	elif [[ "$cur" == * ]]; then
		COMPREPLY=( $( compgen -W '$list_args $install_args update info search install list' -- "$cur" ) )
	fi
}

complete -F _panda -o default panda

# rakudobrew tab completion ----


_rakudobrew_dir() {
	# in case some form of config file appears? 
	# I added this under the *mostly* incorrect assumption that rakudobrew used the installation dir for storing files
	# (which would be a bad idea since it wouldn't work for system installations)
	brewdir="${HOME}/.rakudobrew"
	echo "$brewdir";
}
_rakudobrew_inst_versions() { # finds all backends and versions installed. (in backend-version notation)
	brewdir="$(_rakudobrew_dir)"
	{ find "$brewdir" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex "${brewdir}"'/(moar|moar_jit|parrot|jvm)\-(HEAD|.*)' | sed 's/.*\///'; } 2>/dev/null
}

_rakudobrew_impl() {
	 brewdir="$(_rakudobrew_dir)";
	 baserepo="$(_rakudobrew_inst_versions | head -n 1)"
	 pushd "${brewdir}/${baserepo}" 2>&1>/dev/null;
	 git tag -l 2>/dev/null;
}   

_rakudobrew() { # Tab completion for rakudo brew.
	local cur prev words cword;
	_init_completion || return;
	brewdir="$(_rakudobrew_dir)";
	backends="parrot jvm moar moar_jit";
	versions="HEAD";
	case $prev in
			 switch)
				 COMPREPLY=( $( compgen -W '$( _rakudobrew_inst_versions )'  -- "$cur" ) );
				 _perl6_rem;
				 return 0;
				 ;;
			 build)
				 COMPREPLY=( $( compgen -W 'all $backends'  -- "$cur" ) );
				 _perl6_rem;
				 return 0;
				 ;;
	esac
	if  ( [[ "${#COMP_WORDS[@]}" -ge '3' ]] && [[ "${COMP_WORDS[-3]}" == "build" ]] && _perl6_match "$prev" $backends ); then
		 COMPREPLY=( $( compgen -W "$versions $(_rakudobrew_impl)"  -- "$cur" ) );
	elif [[ "$cur" == * ]]; then
		 COMPREPLY=( $( compgen -W 'switch rehash list current build build-panda' -- "$cur" ) );
		 _perl6_rem;
	fi;
}

complete -F _rakudobrew -o default rakudobrew

# padre tab completion ----


_padre() {
	local cur prev words cword
	_init_completion || return
	longargs="--help --reset --version --desktop"
	unlong="--home= --session= --actionqueue= --locale="
	case "$cur" in
		-*)
			COMPREPLY=( $( compgen -W '$longargs $unlong' -- "$cur" ) )
			_perl6_rem $repargs '--' $assocargs -- $unlong
			return 0
			;;
	esac
	
}
complete -F _padre -o default padre
