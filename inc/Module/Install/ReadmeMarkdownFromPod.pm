#line 1
package Module::Install::ReadmeMarkdownFromPod;

use 5.006;
use strict;
use warnings;
use Pod::Markdown;

our $VERSION = '0.02';

use base qw(Module::Install::Base);

sub readme_markdown_from {
    my ($self, $file, $clean) = @_;
    return unless $Module::Install::AUTHOR;
    die "syntax: readme_markdown_from $file, [$clean]\n" unless $file;

    my $parser = Pod::Markdown->new;
    $parser->parse_from_file($file);
    open my $fh, '>', 'README.mkdn' or die "$!\n";
    print $fh $parser->as_markdown;
    close $fh or die "$!\n";

    return 1 unless $clean;
    $self->postamble(<<"END");
distclean :: license_clean

license_clean:
\t\$(RM_F) README.mkdn
END
    1;
}

sub reference_module {
    my ($self, $file) = @_;
    die "syntax: reference_module $file\n" unless $file;
    $self->all_from($file);
    $self->readme_from($file);
    $self->readme_markdown_from($file);
}

1;

__END__

#line 146
