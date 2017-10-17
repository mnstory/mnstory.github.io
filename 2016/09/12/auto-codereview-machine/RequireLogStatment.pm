package Perl::Critic::Policy::CodeLayout::RequireLogStatment;

use 5.006001;
use strict;
use warnings;
use Readonly;
use Data::Dumper;
use Carp;
use Perl::Critic::Utils qw{ :characters :severities };
use base 'Perl::Critic::Policy';

our $VERSION = '1.0';

my $transLocal = 1;
my $DESC=$transLocal?'日志规范检查：':'Log missing ';
my $EXPL=29219;

sub supported_parameters { return ()                     }
sub default_severity     { return $SEVERITY_HIGH       }
sub default_themes       { return qw(core bugs pbp cosmetic)  }
sub applies_to           { return 'PPI::Token::Word' }

# base functions
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# check stat functions
use constant CheckRight  => 1;
use constant CheckWrong  => 2;
use constant CheckPass => 3;

my $checkRight = 0;
my $checkWrong = 0;
my $checkPass = 0;

sub addCheckRecord {
    my ($chktype, $elem) = @_;
    if($chktype == CheckRight) {
        ++$checkRight;
        #printf(ele2str($elem)."\n");
    } elsif($chktype == CheckWrong) {
        ++$checkWrong;
    } elsif($chktype == CheckPass) {
        ++$checkPass;
    }
}

sub volationEntry {
    my ($self, $elem, $desc) = @_;    
    addCheckRecord(CheckWrong, $elem);
    return $self->violation($DESC.$desc, $EXPL, $elem);
}

# helper functions
sub existsIn {
    my ($word, $words) = @_;
    for my $i (@$words) {
        if($word eq $i) {
            return 1;
        }
    }
    return 0;
}

my @exitWords = qw(return die exit _exit);
sub isExitWord {
    my ($word) = @_;
    return existsIn($word, \@exitWords);
}

my @logWords = qw(ldie lemerg lalert lcrit lerror lwarn lnotice linfo ldebug dbg1 dbg2 dbg3 dbgv);
sub isLogWord {
    my ($word) = @_;
    return existsIn($word, \@logWords);
}

my @conditionJoinWords = qw(|| && or and);
sub isConditionJoinWord {
    my ($word) = @_;
    return existsIn($word, \@conditionJoinWords);
}

my @conditionWords = qw(unless if);
sub isConditionWord {
    my ($word) = @_;
    return existsIn($word, \@conditionWords);
}

sub ele2str {
    my ($elem) = @_;
    return $elem->location()->[4].":".$elem->location()->[0]." ".$elem->content()."\n";
}

sub sfindNextType {
    my ($nsib, $type) = @_;
    while ( $nsib && ! $nsib->isa($type) ) {
        $nsib = $nsib->snext_sibling();
    }
    return $nsib;
}

sub sfindNextTypeAll {
    my ($nsib, $type) = @_;
    my @res = ();
    while ($nsib) {
    	if ($nsib->isa($type)) {
    		push @res, $nsib;
    	}
        $nsib = $nsib->snext_sibling();
    }
    return @res;
}

sub findIfBlock {
    my ($if) = @_;

    if (!$if || !$if->isa('PPI::Statement::Compound')) {
        printf(ele2str($if)." is not if statement!\n");
        return;
    }
    return sfindNextTypeAll($if->schild(0), 'PPI::Structure::Block');
}

sub slast {
    my $next_sibling = shift;
    my $last_following_sibling = $next_sibling;
    if (!$next_sibling) {
        Carp::cluck("null next sibling"); 
        return undef;
    }
    
    while ($next_sibling = $next_sibling->snext_sibling()) {
        $last_following_sibling = $next_sibling;
    }
    # if the last is ;, use previous
    if ($last_following_sibling 
    	&& $last_following_sibling->isa('PPI::Token::Structure') 
    	&& ';' eq $last_following_sibling->content()) {
    	return $last_following_sibling->sprevious_sibling();
    }
    return $last_following_sibling;
}

sub _commentExtra {
    my ($comment) = @_;
    if (!$comment) {
        return "";
    }

    my $offset = index($comment, '#');
    if (-1 == $offset) {
        printf("not a comment: ".$comment."\n");
        return "";
    }

    $comment = substr($comment, $offset+1);
    return trim($comment);
}

sub annotationParse {
    my ($statement) = @_;

    if (!$statement || 0 != index($statement, '@logcheck ')) {
        return ();
    }
    my @annos = split(/[\t ]+/, $statement);
    shift @annos;
    return @annos;
}

sub processStatement {
    my ($self, $elem, $desc, $location) = @_;
    my $ftoken = $elem->schild(0);
    if (!$ftoken) {
        printf(Dumper($elem)." no first child!\n");
        return;
    }
    if (isLogWord($ftoken->content())) {
        return; #condition right
    }
    
    if ($ftoken->content() eq "if") {
        return processIf($self, $elem, $desc, $location);
    }

    return volationEntry($self, $location?$location:$ftoken, $desc?$desc:$transLocal?"PRE LOG MISSING 退出请打日志":"PRE LOG MISSING");
}

sub processIf {
    my ($self, $elem, $desc, $location) = @_;

    my @ifblks = findIfBlock($elem);

    for(my $i = 0; $i < @ifblks; $i++){
    	my $ifblk = $ifblks[$i];
	    if(!$ifblk) {
	        printf("can't found ele's ifblk:".Dumper($elem)."\n");
	        next;
	    }
        my $firstblock = $ifblk->schild(0);
        if(!$firstblock) {
            #Carp::cluck("null schild ".ele2str($ifblk)); 
            # e.g: if($node ne 'cluster') {} 
            # with empty block!
            next;
        }
	    my $last = slast($firstblock);
	    if (!$last) {
	        printf("can't found ifblk's last:".Dumper($ifblk)."\n");
	        next;
	    }
	    my $violate = process($self, $last, $desc, $location);
	    if ($violate) {
	    	return $violate;
	    }
    }
    addCheckRecord(CheckRight, $elem);
    return;
}

sub process {
    my ($self, $elem, $desc, $location) = @_;
    if (!$elem) {
        printf("statement is null\n");
        return;
    }
    if ($elem->isa('PPI::Statement::Compound')) {
        return processIf($self, $elem, $desc, $location);
    } elsif ($elem->isa('PPI::Statement')) {
        return processStatement($self, $elem, $desc, $location);
    } else {
        printf("unknown statement type: ".Dumper($elem)."\n");
    }
    return;
}

sub _isLastStatOfSub {
	my ($stat) = @_;
	
	my $sp = $stat->parent();
	if(!$sp) {
		#printf("stat no parent: ".Dumper($stat)."\n");
		return 0;
	}

	my $findLast = slast($sp->schild(0));
	
	if ((refaddr $findLast) == (refaddr $stat)) {
		return 1;
	}
	#printf("find last: ".(refaddr $findLast)."=>".Dumper($findLast)."\n");
	#printf("  my last: ".(refaddr $stat)."=>".Dumper($stat)."\n");
	return 0;
}

sub isLastStatOfSub {
	my ($stat) = @_;

	while ($stat && _isLastStatOfSub($stat)) {
		my $sp  = $stat ? $stat->parent() : undef;
		my $spp = $sp ? $sp->parent() : undef;
		if ($spp && $spp->isa('PPI::Statement::Sub') && $sp->isa('PPI::Structure::Block')) {
			#printf("stat is root of sub\n");
			return 1;
		}
		$stat = $sp;
	}
	#printf("stat is not root of sub\n");
	return 0;
}


sub violates {
    my ( $self, $elem, undef ) = @_;
    if(!isExitWord($elem->content()))  {
        return;
    }
    #printf("unknown pre statement type: ".Dumper($elem->parent()->parent()->parent())."\n");

    my $statement = $elem->statement();
    if (!$statement) {
        printf(Dumper($elem)." no statement!\n");
        return;
    }

    #CASE sub except
    if (isLastStatOfSub($statement)) {
        addCheckRecord(CheckRight, $statement);
        return;
    }

    #CASE annotation
    my $presib = $statement->previous_sibling();
    while ($presib && $presib->isa('PPI::Token::Whitespace')) {
        $presib = $presib->previous_sibling();
    }
    if($presib && $presib->isa('PPI::Token::Comment')) {
        my @annos = annotationParse(_commentExtra($presib->content()));
        if (@annos && ("no" eq $annos[0])) {
            addCheckRecord(CheckPass, $presib);
            return;
        }
    }

    #CASE or return
    $presib = $elem->sprevious_sibling();
    if ($presib && $presib->isa('PPI::Token::Operator') && isConditionJoinWord($presib->content())) {
        return volationEntry($self, $elem, $transLocal?"OR RETURN 退出前请打日志":"OR RETURN need log");
    }

    #CASE return if
    my $lastsib = slast($elem);
    if($lastsib && $lastsib->isa('PPI::Structure::Condition')) {
    	my $if = $lastsib->sprevious_sibling();
    	if ($if && isConditionWord($if->content())) {
            return volationEntry($self, $elem, $transLocal?"RETURN IF 退出前请打日志":"RETURN IF need log");
    	}
    	printf("invalid condition found: ".Dumper($lastsib)."\n");
    }

    #CASE no pre-statement
    my $prestatement = $statement->sprevious_sibling();
    if(!$prestatement) {
        return volationEntry($self, $elem, $transLocal?"NO PRE-STATEMENT 退出前请打日志":"NO PRE-STATEMENT");
    }

    #CASE if-else return
    if ($prestatement->isa('PPI::Statement::Compound')) {
        #printf("case 1, ".ele2str($prestatement));
        return processIf($self, $prestatement, $transLocal?"IF-ELSE RETURN 退出前请打日志":"IF-ELSE RETURN need log", $elem);
    }

    #CASE normal check    
    if ($prestatement->isa('PPI::Statement')) {
        my $ftoken = $prestatement->schild(0);
        if ($ftoken) {
            if(isLogWord($ftoken->content())) {
                #pre statement is a logstat
                addCheckRecord(CheckRight, $ftoken);
                return;
            } elsif(isConditionWord($ftoken->content())) {
                #printf("case 2, ".ele2str($prestatement)."->".ele2str($ftoken));
                return processIf($self, $prestatement, $transLocal?"IF-ELSE RETURN 退出前请打日志":"IF-ELSE RETURN need log", $elem);
            }
        }
        return volationEntry($self, $elem, $transLocal?"PRE LOG MISSING 退出前请打日志":"PRE LOG MISSING need log");
    }

    printf("unknown pre statement type: ".Dumper($prestatement)."\n");
    return;
}

END {
    printf("LogCheck Right $checkRight Wrong $checkWrong Pass $checkPass\n");
}

1;
