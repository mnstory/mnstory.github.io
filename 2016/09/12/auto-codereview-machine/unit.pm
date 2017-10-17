#[W] no pre-statement
return 4;

#[P] annotation
if (-e "path/to/file") {
	i++;
	#@logcheck no
	exit (0); #PPI::Statement
}

#[R] if return
if (-e "path/to/file") {
	i++;
	ldebug("file found!");
	exit (0); #PPI::Statement
}

#[R] if if return
if (-e "path/to/file") {
	if (true){
		ldebug("file found!");
	}
	exit 1; #PPI::Statement
}

#[W] if-else return
if (-e "path/to/file") {
	if ($i == 1){
		lerror("file found 1!");
	} elsif ($i == 2){
		ldebug("file found 2!");
	} else {
		i++;
	}
	exit 1; #PPI::Statement
}

#[R] if-else return
if (-e "path/to/file") {
	if ($i == 1){
		lerror("file found 1!");
	} elsif ($i == 2){
		ldebug("file found 2!");
	} else {
		i++;
		linfo("file found 3!");
	}
	exit 1; #PPI::Statement
}

#[W] if-else return
if (-e "path/to/file") {
	if ($i == 1){
		lerror("file found 1!");
	} elsif ($i == 2){
		i++;
	} else {
		ldebug("file found 2!");
	}
	exit 1; #PPI::Statement
}

#[W] if-else return
if (-e "path/to/file") {
	if ($i == 1){
		i++;
	} elsif ($i == 2){
		lerror("file found 1!");
	} else {
		ldebug("file found 2!");
	}
	exit 1; #PPI::Statement
}

#[W] pre log missing
while (true) {
	i++;
	exit 2;
}

#[W] return if
return (-1, "file not found") if(! -e "path/to/file"); #statement=PPI::Structure::Condition,PPI::Token::Structure=';'

#[W] return unless
return $vmlist unless (-e $powerfile);

#[W] or return
open STDOUT, '>/dev/null' or die "$msg $!\n";

#[W] or return
! -e "path/to/file" || die "file not exist!"; #psib=PPI::Token::Operator='||'

#[W] sub except
sub foo {
	my ($arg) = @_;
	i++;
	if (i > 0) {
		return i;
	}
	i--;
}

#[R] sub except
sub foo {
	my ($arg) = @_;
	i++;
	return i;
}

