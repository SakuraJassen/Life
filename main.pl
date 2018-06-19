#!/usr/bin/perl
use strict;
use warnings;

use GD;
use GD::Image;
use Tk;
use Tk::PNG;
use MIME::Base64;
use Storable 'dclone';
use List::Util qw(min max);
use Time::HiRes;
use Time::Stopwatch;

#Console Params
my $filename = shift || 'source.png';

my $myStartField = new GD::Image($filename);

#stats
tie my $time, 'Time::Stopwatch';

my $width  = 100;
my $height = 100;

my $zoom = 5;

my $PicWidth  = $width*$zoom;
my $PicHeight = $height*$zoom;

#Create the Field
my @field = ();
for (my $x = 0; $x < $width; $x++) {
    for (my $y = 0; $y < $height; $y++) {
        push @field, 0;
    }
}

if(defined($myStartField)){
    foreach my $x (0..min($myStartField->width, $width)) {
        foreach my $y (0..min($myStartField->height, $height)) {
            if($myStartField->getPixel($x,$y) != 0){
                $field[$width * $x + $y] = 1;
                #$field->[$x]->[$y] = 1,
            }
        }
    }
}
my $gen = 0;
my $maxgen = 10;
my $frame = new GD::Image($width, $height);

my $mw = new MainWindow;
my $photo_obj = $mw->Photo(-data => drawFrame() );
my $display = $mw->Label(
    -image => $photo_obj,
)->pack(
    -fill=>'both',
    -expand=>1
);
$mw->Button(
    -text => "Quit",
    -command => sub{ $mw->destroy(); },
)->pack();
$mw->after(100 => \&redraw);

sub redraw {
    my $time1 = $time;

    logic();
    $photo_obj->blank;
    $photo_obj->configure(-data => drawFrame());
    $mw->update;
    $mw->after(100 => \&redraw) if ($maxgen > 0 and $gen <= $maxgen);

    print($time-$time1, "\n");
    $gen++;
}

$mw->MainLoop();

sub logic {
    my @localField = @field;
    for (my $y = 0; $y < $height; $y++) {
        for (my $x = 0; $x < $width; $x++) {
            my $cnt = getNeighbors(x=> $x, y => $y);
            $localField[$width * $x + $y] = 0 if($cnt > 3);
            $localField[$width * $x + $y] = 1 if($cnt == 2 and $field[$width * $x + $y] == 1);
            $localField[$width * $x + $y] = 1 if($cnt == 3);
            $localField[$width * $x + $y] = 0 if($cnt < 2);
        }
    }
    @field = @localField;
}

sub getNeighbors {
    my %params  = (
        x => undef,
        y => undef,
        @_
    );
    return 0 unless(defined($params{x}) && defined($params{y}));

    my $cnt = 0;
    for (my $y = -1; $y <= 1; $y++) {
        for (my $x = -1; $x <= 1; $x++) {
            next if($x == 0 and $y == 0);
            $cnt++ if(defined($field[$width * ($params{x}+$x) + ($params{y}+$y)]) and $field[$width * ($params{x}+$x) + ($params{y}+$y)] > 0);
        }
    }
    return $cnt;
}

sub drawFrame {
    my $frame = new GD::Image($width, $height);
    $frame->colorAllocate(0,0,0);
    $frame->colorAllocate(255,255,255);
    for (my $y = 0; $y < $height; $y++) {
        for (my $x = 0; $x < $width; $x++) {
            $frame->setPixel($x, $y, $field[$width * $x + $y]);
        }
    }
    my $retFrame = new GD::Image($PicWidth, $PicHeight);
    $retFrame->copyResized($frame, 0, 0, 0, 0, $PicWidth, $PicHeight, $width, $height);
    return encode_base64( $retFrame->png() );
}

sub getVal {
    my %params  = (
        x => undef,
        y => undef,
        width => $width,
        @_
    );
    return $field[$params{width} * $params{x} + $params{y}];
}

sub setVal {
    my %params  = (
        x => undef,
        y => undef,
        width => $width,
        value => undef,
        @_
    );
    return 0 unless(defined($params{value}));
    $field[$params{width} * $params{x} + $params{y}] = $params{value};
}

sub indexToXY{
    my %params  = (
        index => undef,
        width => $width,
        @_
    );
    my $y = ($params{index} / $params{width});
    my $x = ($params{index} % $params{width});

    return [$y, $x];

}