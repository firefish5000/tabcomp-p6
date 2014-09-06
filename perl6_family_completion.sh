# bash completion for (rakudo?) perl6
# Put this in your bash_completion directory or add
# 'source path/to/dir/perl6_family_completion.sh' to your bashrc and
# running shells.

# Usefull looking things that may or may not exist
# _filedir

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
			#usage: _perl6_rem repeatable words -- associated pairs -- words we shouldn't add spaces after
	rep_words=($(_perl6_seper '0' '--' "$@")) # It looks like we can quote all of these without error. consider doing so.
	assoc_words=($(_perl6_seper '1' '--' "$@"))
	nospace_words=($(_perl6_seper '2' '--' "$@"))
		COMPREPLY=($(echo "${COMP_WORDS[@]}" | \
		(while read -d ' ' i; do
			[[ -z ${i} ]] && continue
		_perl6_match "${i}" "${rep_words[@]}" && continue
		COMPREPLY=($(_perl6_assoc "${i}" "${assoc_words[@]}"))
		# flatten array with spaces on either side,
			# otherwise we cannot grep on word boundaries of
			# first and last word
			COMPREPLY=" ${COMPREPLY[@]} "
			# remove word from list of completions
			COMPREPLY=("${COMPREPLY/ ${i%% *} / }") # FIXME doesnt work for --target\= and alike
		done
		echo ${COMPREPLY[@]})))
	[[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ "${#nospace_words[@]}" -ge '1' ]] &&  _perl6_match "$COMPREPLY" "${nospace_words[@]}" && compopt -o nospace
		return 0
}
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
	_panda_read_json_perl
}


_panda() {
	local cur prev words cword
	_init_completion || return
	list_args="--verbrose --installed"
	install_args="--notests --nodeps"
	case $prev in
		install|--notests|--nodeps)
			#COMPREPLY=( $( compgen -W 'install $install_args $( _panda_modules )'  -- "$cur" ) )
			COMPREPLY=( $( compgen -W 'install $install_args'  -- "$cur" ) )
			_perl6_match 'install' "${COMP_WORDS[@]}" && COMPREPLY+=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
		list|--verbrose|--installed)
			#COMPREPLY=( $( compgen -W 'list $list_args $( _panda_modules )' -- "$cur" ) )
			COMPREPLY=( $( compgen -W 'list $list_args' -- "$cur" ) )
			_perl6_match 'list' "${COMP_WORDS[@]}" && COMPREPLY+=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
		search|info|update)
			COMPREPLY=( $( compgen -W '$( _panda_modules )'  -- "$cur" ) )
			_perl6_rem;
			return 0
			;;
	esac
	if [[ "$cur" == * ]]; then
		COMPREPLY=( $( compgen -W '$list_args $install_args update info search install list' -- "$cur" ) )
	fi
} 
_rakudobrew() {
	local cur prev words cword
	_init_completion || return
	backends="parrot jvm moar moar_jit"
	case $prev in
			switch)
				COMPREPLY=( $( compgen -W '$backends'  -- "$cur" ) )
				_perl6_rem
				return 0
		  		;;
			build)
				COMPREPLY=( $( compgen -W 'all $backends'  -- "$cur" ) )
				_perl6_rem 
				return 0
		  		;;
	esac
	if  ( [[ "${#COMP_WORDS[@]}" -ge '3' ]] && [[ "${COMP_WORDS[-3]}" == "build" ]] && _perl6_match "$prev" $backends ); then
		COMPREPLY=( $( compgen -W '2014,08 2014.07 2014.06 HEAD'  -- "$cur" ) ) # TODO version
	elif [[ "$cur" == * ]]; then
		COMPREPLY=( $( compgen -W 'switch rehash list current build build-panda' -- "$cur" ) )
		_perl6_rem 
	fi
}
_perl6() {
	local cur prev words cword
	_init_completion || return
	case $prev in
			--encoding)
				COMPREPLY=( $( compgen -W 'utf8'  -- "$cur" ) )
				return 0
		  		;;
	esac
	longargs="--doc --help --stagestats --ll-exception --profile"
	unlong="--target\= --trace\= --encoding\= --output\="
	shortargs="-c -h -e -n -p -t -o -v"
	unshort=''
	repargs="--output --encoding -e -n -p -o" # Repeatable Arguments
	assocargs="-h --help"	# Assosiated Arguments (only ones that cannot repeat)
	if [[ "$cur" == --* ]]; then
		COMPREPLY=( $( compgen -W '$longargs $unlong' -- "$cur" ) )
		_perl6_rem $repargs '--' $assocargs -- $unlong
	elif [[ "$cur" == -* ]]; then
		COMPREPLY=( $( compgen -W '$shortargs' -- "$cur" ) )
		_perl6_rem $repargs '--' $assocargs
	fi
} # &&
complete -F _perl6 -o default perl6{,m,j,p} perl6-debug-{m,j,p}
complete -F _panda -o default panda
complete -F _rakudobrew -o default rakudobrew
