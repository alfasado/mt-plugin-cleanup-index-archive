package CleanupIndexArchive::Plugin;

use strict;

sub _edit_template {
    my ( $cb, $app, $param, $tmpl ) = @_;
    return 1 if (! MT->config( 'CleanupIndexArchive' ) );
    return 1 if ( $param->{ type } ne 'index' );
    if (! $param->{ build_type } ) {
        $param->{ published_url } = '';
    }
    return 1;
}

sub _cms_post_save_template {
    my ( $cb, $app, $obj, $original ) = @_;
    return 1 if (! MT->config( 'CleanupIndexArchive' ) );
    return 1 if ( $obj->type ne 'index' );
    return 1 if (! defined $original );
    return 1 if (! $original->id );
    my $old_type = $original->build_type;
    my $new_type = $obj->build_type;
    return 1 if ( $old_type == 3 );
    return 1 if ( $old_type == 0 );
    return 1 if ( $old_type == $new_type );
    my $blog = $obj->blog;
    return 1 unless $blog;
    my $site_path = $blog->site_path || '';
    require File::Spec;
    require MT::FileMgr;
    my $orig_outfile = $original->outfile;
    return 1 unless $orig_outfile;
    my $outfile = $obj->outfile;
    my $old_path = File::Spec->catfile( $site_path, $orig_outfile );
    my $new_path = File::Spec->catfile( $site_path, $outfile );
    if ( $old_type != $new_type ) {
        if ( $new_type == 0 ) {
            # Do Not Publish
            my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
            if ( $fmgr->exists( $old_path ) ) {
                my $do = $fmgr->delete( $old_path );
                if ( $do != 1 ) {
                    MT->log( $do );
                }
            }
            return 1;
        }
    }
    if ( $outfile eq $orig_outfile ) {
        return 1;
    }
    require MT::Session;
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    if ( $fmgr->exists( $old_path ) ) {
        my $session = MT::Session->get_by_key( { name => $old_path, id => $orig_outfile, kind => 'TF' } );
        $session->email( $obj->id ); # For Delete at BuildPage.
        $session->start( time );
        $session->save or die $session->errstr;
    }
    my $session = MT::Session->load( { name => $new_path, id => $outfile, kind => 'TF' } );
    if ( defined $session ) {
        $session->remove or die $session->errstr;
    }
    return 1;
}

sub _build_page {
    my ( $cb, %args ) = @_;
    my $template = $args{ Template };
    return 1 if (! MT->config( 'CleanupIndexArchive' ) );
    return 1 if (! MT->config( 'CleanupIndexArchiveAtRebuild' ) ); # or by Task
    return 1 if ( $template->type ne 'index' );
    require MT::Session;
    my $session = MT::Session->load( { email => $template->id, kind => 'TF' } );
    return 1 if (! defined $session );
    my $path = $session->name;
    require MT::FileInfo;
    my $fi = MT::FileInfo->load( { file_path => $path } );
    return 1 if ( defined $fi );
    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    if ( $fmgr->exists( $path ) ) {
        my $do = $fmgr->delete( $path );
        if ( $do != 1 ) {
            MT->log( $do );
        } else {
            $session->remove or die $session->errstr;
        }
    }
    return 1;
}

1;