package Test::Compile::Internal;

use 5.006;
use warnings;
use strict;

use File::Spec;
use UNIVERSAL::require;
use Test::Builder;

our $VERSION = '0.21';

=head1 NAME

Test::Compile::Internal - Test whether your perl files compile.

=head1 SYNOPSIS

    use Test::Compile::Internal;
    my $test = Test::Compile::Internal->new();
    $test->all_files_ok();
    $test->done_testing();

=head1 DESCRIPTION

C<Test::Compile::Internal> is an object oriented tool for testing whether your
perl files compile.

It is primarily to provide the inner workings of C<Test::Compile>, but it can
also be used directly to test a CPAN distribution.

=head1 METHODS

=over 4

=item C<new()>

A basic constructor, nothing special.
=cut

sub new {
    my ($class,%self) = @_;
    my $self = \%self;

    $self->{test} = Test::Builder->new();

    bless ($self, $class);
    return $self;
}

=item C<all_files_ok(@dirs)>

Checks all the perl files it can find for compilation errors.

If C<@dirs> is defined then it is taken as an array of directories to 
be searched for perl files, otherwise it searches some default locatioons
- see L</all_pm_files()> and L</all_pl_files()>. 

=cut
sub all_files_ok {
    my ($self,@dirs) = @_;

    my $test = $self->{test};

    for my $file ( $self->all_pl_files(@dirs) ) {
        my $ok = $self->pl_file_compiles($file);
        $test->ok($ok,"$file compiles");
    }

    for my $file ( $self->all_pm_files(@dirs) ) {
        my $ok = $self->pm_file_compiles($file);
        $test->ok($ok,"$file compiles");
    }
}


=item C<verbose($verbose)>

An accessor to get/set the verbose flag.  If C<verbose> is set, you can get some 
extra diagnostics when compilation fails.

Verbose is set off by default.
=cut

sub verbose {
    my ($self,$verbose) = @_;

    if ( defined($verbose) ) {
        $self->{verbose} = $verbose;
    }

    return $self->{verbose};
}

=item C<all_pm_files(@dirs)>

Returns a list of all the perl module files - that is any files ending in F<.pm>
in C<@dirs> and in directories below. If C<@dirs> is undefined, it
searches F<blib> if F<blib> exists, or else F<lib>.

Skips any files in C<CVS> or C<.svn> directories.

The order of the files returned is machine-dependent. If you want them
sorted, you'll have to sort them yourself.
=cut

sub all_pm_files {
    my ($self,@dirs) = @_;

    @dirs = @dirs ? @dirs : _pm_starting_points();

    my @pm;
    for my $file ( $self->_find_files(@dirs) ) {
        if (-f $file) {
            push @pm, $file if $file =~ /\.pm$/;
        }
    }
    return @pm;
}

=item C<all_pl_files(@dirs)>

Returns a list of all the perl script files - that is, any files ending in F<.pl>
or files with no extension in C<@dirs> and in directories below. If
C<@dirs> is undefined, it searches F<script> if F<script> exists, or else
F<bin> if F<bin> exists.

Skips any files in C<CVS> or C<.svn> directories.

The order of the files returned is machine-dependent. If you want them
sorted, you'll have to sort them yourself.

=cut

sub all_pl_files {
    my ($self,@dirs) = @_;

    @dirs = @dirs ? @dirs : _pl_starting_points();

    my @pl;
    for my $file ( $self->_find_files(@dirs) ) {
        if (defined($file) && -f $file) {
            # Only accept files with no extension or extension .pl
            push @pl, $file if $file =~ /(?:^[^.]+$|\.pl$)/;
        }
    }
    return @pl;
}

=item C<pl_file_compiles($file)>

Returns true if C<$file> compiles as a perl script.

=cut

sub pl_file_compiles {
    my ($self,$file) = @_;
    return $self->_run_closure(
        sub{
            if ( -f $file ) {
                my @perl5lib = split(':', ($ENV{PERL5LIB}||""));
                my $taint = $self->_is_in_taint_mode($file);
                unshift @perl5lib, 'blib/lib';
                system($^X, (map { "-I$_" } @perl5lib), "-c$taint", $file);
                return ($? ? 0 : 1);
            }
        }
    );
}

=item C<pm_file_compiles($file)>

Returns true if C<$file> compiles as a perl module.

=back
=cut

sub pm_file_compiles {
    my ($self,$file) = @_;

    return $self->_run_closure(
        sub{
            if ( -f $file ) {
                my $module = $file;
                $module =~ s!^(blib[/\\])?lib[/\\]!!;
                $module =~ s![/\\]!::!g;
                $module =~ s/\.pm$//;
    
                $module->use;
                return ($@ ? 0 : 1);
            }
        }
    );
}

=head1 TEST METHODS

C<Test::Compile::Internal> encapsulates a C<Test::Builder> object, and provides
access to some of its methods.

=over 4

=item C<done_testing()>

Declares that you are done testing, no more tests will be run after this point.

=cut
sub done_testing {
    my ($self,@args) = @_;
    $self->{test}->done_testing(@args);
}

=item C<ok($test,$name)>

Your basic test. Pass if C<$test> is true, fail if C<$test> is false. Just
like C<Test::Simple>'s C<ok()>.

=cut
sub ok {
    my ($self,@args) = @_;
    $self->{test}->ok(@args);
}

=item C<plan($count)>

Defines how many tests you plan to run.

=cut
sub plan {
    my ($self,@args) = @_;
    $self->{test}->plan(@args);
}

=item C<exported_to($caller)>

Tells C<Test::Builder> what package you exported your functions to.  I am
not sure why you would want to do that, or whether it would do you any good.

=cut

sub exported_to {
    my ($self,@args) = @_;
    $self->{test}->exported_to(@args);
}

=item C<diag(@msgs)>

Prints out the given C<@msgs>. Like print, arguments are simply appended
together.

Output will be indented and marked with a # so as not to interfere with
test output. A newline will be put on the end if there isn't one already.

We encourage using this rather than calling print directly.

=cut

sub diag {
    my ($self,@args) = @_;
    $self->{test}->diag(@args);
}

=item C<skip($why)>

Skips the current test, reporting C<$why>.

=cut

sub skip {
    my ($self,@args) = @_;
    $self->{test}->skip(@args);
}

=item C<skip_all($reason)>

Skips all the tests, using the given C<$reason>. Exits immediately with 0.

=back
=cut

sub skip_all {
    my ($self,@args) = @_;
    $self->{test}->skip_all(@args);
}

sub _run_closure {
    my ($self,$closure) = @_;

    my $pid = fork();
    if ( ! defined($pid) ) {
        return 0;
    } elsif ( $pid ) {
        wait();
        return ($? ? 0 : 1);
    }

    if ( ! $self->verbose() ) {
        open STDERR, '>', File::Spec->devnull;
    }

    my $rv = $closure->();

    exit ($rv ? 0 : 1);
}

sub _find_files {
    my ($self,@queue) = @_;

    for my $file (@queue) {
        if (defined($file) && -d $file) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;
            @newfiles = File::Spec->no_upwards(@newfiles);
            @newfiles = grep { $_ ne "CVS" && $_ ne ".svn" } @newfiles;
            for my $newfile (@newfiles) {
                my $filename = File::Spec->catfile($file, $newfile);
                if (-f $filename) {
                    push @queue, $filename;
                } else {
                    push @queue, File::Spec->catdir($file, $newfile);
                }
            }
        }
    }
    return @queue;
}

sub _pm_starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}

sub _pl_starting_points {
    return 'script' if -e 'script';
    return 'bin'    if -e 'bin';
}

sub _is_in_taint_mode {
    my ($self,$file) = @_;

    open(my $f, "<", $file) or die "could not open $file";
    my $shebang = <$f>;
    my $taint = "";
    if ($shebang =~ /^#![\/\w]+\s+\-w?([tT])/) {
        $taint = $1;
    }
    return $taint;
}

1;

=head1 AUTHORS

Sagar R. Shah C<< <srshah@cpan.org> >>,
Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>,
Evan Giles, C<< <egiles@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2012 by the authors.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Strict> proveds functions to ensure your perl files comnpile, with
the added bonus that it will check you have used strict in all your files.

=cut
