use v6.*;

=begin pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides a facility to take a "snapshot" of the Raku modules you have installed
on your system in the form of a skeleton distribution with the modules as dependencies
which can be used to reinstall the modules or even install them fresh on a new machine.

The key use cases for this kind of thing would be either that you need to remove and
reinstall your Raku installation (rather than just upgrading in place that will
leave the modules as they were,) or you want deploy the same modules on another machine
to run some application (or duplicate a development environment.)

This is similar in intent to the C<autobundle> command of Perl 5's C<cpan> command.


It should work with any module installer that uses the standard Raku installation
mechanisms (such as C<zef>) and should in theory work with any new
ones that may come along as it simply writes a minimal META file into an otherwise
bare directory.  The META file contains the installed modules as it's dependencies
just a like a normal module might.

The primary interface for this is the provided script C<raku-module-snapshot> and
this module, whilst it may be useful in another context, simply encapsulates the
bulk of the implementation in order to take advantage of precompilation.

=head1 METHODS

All of the methods are 'class' methods that can be called on the type object, they
could just as easily be exported sub-routines but I feel making them methods
allows for easier extension and doesn't pollute the consumers namespace.

=head2 method create-meta

    method create-meta(Str :$name!, Version :$raku-version = $*RAKU.version, Version :$version = v0.0.1) returns META6

This returns a C<META6> object initialised with the minimal attributes for it to work.
The C<name> must be provided.

=head2 method get-dists

    method get-dists(@exclude-auth = <raku perl private:snapshot>)

This returns a list of the installed L<Distribution> objects, it will skip distributions that appear to
either be part of the installed Rakudo or those created by this module. To allow for other uses a
list of the 'auth' strings that should be skipped can be provided.

=head2 method get-meta

    method get-meta(Str :$name!, Version :$raku-version = $*RAKU.version, Version :$version = v0.0.1, :@exclude-auth = <perl private:snapshot>) returns META6

This returns the fully populated META data that will be serialised to create the
META6.json file.  C<name> is required (and will form the name of the
created distribution,) all of the other arguments have defaults that are
sensible for the application.

=end pod

class App::ModuleSnap {
    use JSON::Fast;
    use META6;

    my $auth     = 'private:snapshot';

    has Str $.auth is rw = $auth;

    my @excludes = ('perl', $auth );

    has Str @.exclude-auths is rw = @excludes;

    my @repos = <site vendor core>;

    has Str @.include-repositories is rw = @repos;

    sub timestamp-part( --> Str ) {
        DateTime.now.Str.subst(/<[:+.-]>/,"", :g);
    }

    sub auto-name-parts( --> Positional ) {
        ('Snapshot', 'Auto', timestamp-part() );
    }

    multi sub MAIN(IO() :$directory = '.') is export {

        my @parts = auto-name-parts();
        my Str $name = @parts.join('::');
        my Str $dir-name = @parts.join('-');

        my IO::Path $dir = $directory.add($dir-name);

        my META6 $meta = App::ModuleSnap.get-meta(:$name);

        if !$dir.d {
            $dir.mkdir;
        }

        $dir.add('META6.json').spurt($meta.to-json);
        say "the snapshot has been written in the directory $dir";
    }

    proto get-meta { * }

    multi method get-meta(App::ModuleSnap:U: Str :$name!, Version :$raku-version = $*RAKU.version, Version :$version = v0.0.1, :@exclude-auth = @excludes --> META6 ) {
        my $meta = self.create-meta(:$name, :$raku-version, :$version);
        $meta.depends = self.get-dists(@exclude-auth).map(*.meta<name>).list;
        $meta;
    }

    proto create-meta { * }

    multi method create-meta(App::ModuleSnap:U: Str :$name!, Version :$raku-version = $*RAKU.version, Version :$version = v0.0.1 --> META6 ) {
        my Str $auth        = 'private:snapshot';
        my Str $source-url  = 'urn:no-install';
        my $meta = META6.new(:$name, :$raku-version, :$version, :$auth, :$source-url);
        return $meta;
    }

    method get-repos( --> Iterable ) {
        $*REPO.repo-chain.grep(CompUnit::Repository::Installation);
    }

    proto get-dists { * }

    multi method get-dists(App::ModuleSnap:U: @exclude-auth = @excludes --> Iterable ) {
        my @dists;
        for self.get-repos -> $r {
            for $r.installed -> $dist {
                if !$dist.meta<auth>.defined || $dist.meta<auth> ne any(@exclude-auth.list) {
                    @dists.append: $dist;
                }
            }
        }
        @dists;
    }
}
# vim: expandtab shiftwidth=4 ft=raku
