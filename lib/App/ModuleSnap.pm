use v6.c;

class App::ModuleSnap {
    use META6;
    method get-meta(Str :$name!, Version :$perl = $*PERL.version, Version :$version = v0.0.1, :@exclude-auth = <perl private:snapshot>) returns META6 {
        my $meta = self.create-meta(:$name, :$perl, :$version);
        $meta.depends = self.get-dists(@exclude-auth).map(*.name).list;
        $meta;
    }

    method create-meta(Str :$name!, Version :$perl = $*PERL.version, Version :$version = v0.0.1) returns META6 {
        my Str $auth        = 'private:snapshot';
        my Str $source-url  = 'urn:no-install';
        my $meta = META6.new(:$name, :$perl, :$version, :$auth, :$source-url);
        return $meta;
    }

    method get-dists(@exclude-auth = <perl private:snapshot>) {
        my Distribution @dists;
        for $*REPO.repo-chain -> $r {
            if $r.can('prefix') {
                if $r.prefix.child('dist').e {
                    for $r.prefix.child('dist').dir -> $d {
                        my $dist-data = from-json($d.slurp);
                        my $dist =  Distribution.new(|$dist-data);
                        if !$dist.auth.defined || $dist.auth ne any(@exclude-auth.list) {
                            @dists.append: $dist;
                        }
                    }
                }
            }
        }
        @dists;
    }

} 
# vim: expandtab shiftwidth=4 ft=perl6
