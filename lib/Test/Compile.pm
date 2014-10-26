package Test::Compile;

use warnings;
use strict;
use Test::Builder;
use File::Spec;
use UNIVERSAL::require;

our $VERSION = '0.02';


my $Test = Test::Builder->new;


sub import {
    my $self = shift;
    my $caller = caller;

   for my $func ( qw( pm_file_ok all_pm_files all_pm_files_ok ) ) {
        no strict 'refs';
        *{$caller."::".$func} = \&$func;
    }

    $Test->exported_to($caller);
    $Test->plan(@_);
}


sub pm_file_ok {
    my $file = shift;
    my $name = @_ ? shift : "Compile test for $file";

    if (!-f $file) {
        $Test->ok(0, $name);
        $Test->diag("$file does not exist");
        return;
    }

    my $module = $file;
    $module =~ s!^(blib/)?lib/!!;
    $module =~ s!/!::!g;
    $module =~ s/\.pm$//;

    my $ok = 1;
    $module->use;
    $ok = 0 if $@;

    my $diag = '';
    unless ($ok) {
        $diag = "couldn't use $module ($file): $@";
    }

    $Test->ok($ok, $name);
    $Test->diag($diag) unless $ok;
    $ok;
}


sub all_pm_files_ok {
    my @files = @_ ? @_ : all_pm_files();

    $Test->plan(tests => scalar @files);

    my $ok = 1;
    for (@files) {
        pm_file_ok($_) or undef $ok;
    }
    $ok;
}


sub all_pm_files {
    my @queue = @_ ? @_ : _starting_points();
    my @pm;

    while ( @queue ) {
        my $file = shift @queue;
        if ( -d $file ) {
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
        if (-f $file) {
            push @pm, $file if $file =~ /\.pm$/;
        }
    }
    return @pm;
}


sub _starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}


1;

__END__

=head1 NAME

Test::Compile - check whether Perl module files compile correctly

=head1 SYNOPSIS

C<Test::Compile> lets you check the validity of a Perl module file, and report
its results in standard C<Test::Simple> fashion.

    BEGIN {
        use Test::Compile tests => $num_tests;
        pm_file_ok($file, "Valid Perl module file");
    }

It's probably a good idea to run this in a BEGIN block. The examples below
omit it for clarity.

Module authors can include the following in a F<t/00_compile.t> file and
have C<Test::Compile> automatically find and check all Perl module files in a
module distribution:

    use Test::More;
    eval "use Test::Compile 1.00";
    plan skip_all => "Test::Compile 1.00 required for testing compilation"
      if $@;
    all_pm_files_ok();

You can also specify a list of files to check, using the
C<all_pm_files()> function supplied:

    use strict;
    use Test::More;
    eval "use Test::Compile 1.00";
    plan skip_all => "Test::Compile 1.00 required for testing compilation"
      if $@;
    my @pmdirs = qw(blib script);
    all_pm_files_ok(all_pm_files(@pmdirs));

Or even (if you're running under L<Apache::Test>):

    use strict;
    use Test::More;
    eval "use Test::Compile 1.00";
    plan skip_all => "Test::Compile 1.00 required for testing compilation"
      if $@;

    my @pmdirs = qw(blib script);
    use File::Spec::Functions qw(catdir updir);
    all_pm_files_ok(
        all_pm_files( map { catdir updir, $_ } @pmdirs )
    );

=head1 DESCRIPTION

Check Perl module files for errors or warnings in a test file.

=head1 FUNCTIONS

=over 4

=item pm_file_ok(FILENAME[, TESTNAME ])

C<pm_file_ok()> will okay the test if the Perl module compiles correctly.

When it fails, C<pm_file_ok()> will show any compilation errors as
diagnostics.

The optional second argument TESTNAME is the name of the test.  If it is
omitted, C<pm_file_ok()> chooses a default test name "Compile test for
FILENAME".

=item all_pm_files_ok([@files/@directories])

Checks all the files in C<@files> for compilation.  It runs L<all_pm_files()>
on each file/directory, and calls the C<plan()> function for you (one test for
each function), so you can't have already called C<plan>.

If C<@files> is empty or not passed, the function finds all Perl module files
in the F<blib> directory if it exists, or the F<lib> directory if not.  A Perl
module file is one that ends with F<.pm>.

If you're testing a module, just make a F<t/00_compile.t>:

    use Test::More;
    eval "use Test::Compile 1.00";
    plan skip_all => "Test::Compile 1.00 required for testing compilation"
      if $@;
    all_pm_files_ok();

Returns true if all Perl module files are ok, or false if any fail.

Or you could just let L<Module::Install::StandardTests> do all the work for
you.

=item all_pm_files([@dirs])

Returns a list of all the perl module files - that is, files ending in F<.pm>
- in I<$dir> and in directories below. If no directories are passed, it
defaults to F<blib> if F<blib> exists, or else F<lib> if not.  Skips any files
in CVS or .svn directories.

The order of the files returned is machine-dependent.  If you want them
sorted, you'll have to sort them yourself.

=back

=head1 TAGS

If you talk about this module in blogs, on del.icio.us or anywhere else,
please use the C<testcompile> tag.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-test-compile@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit <http://www.perl.com/CPAN/> to find a CPAN
site near you. Or see <http://www.perl.com/CPAN/authors/id/M/MA/MARCEL/>.

=head1 AUTHOR

Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Marcel GrE<uuml>nauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

