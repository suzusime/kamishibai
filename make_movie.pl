#!/usr/bin/env perl
use strict;
use warnings;
use 5.014;
use utf8;
use open ':encoding(utf8)';
use Encode::Locale;
binmode(STDIN, ":encoding(console_in)");
binmode(STDOUT, ":encoding(console_out)");
binmode(STDERR, ":encoding(console_out)");
Encode::Locale::decode_argv;

my $movie_list = "";

my $script_name = "movie_script.txt";
open(my $fh, "<", $script_name)
    or die "Can't open $script_name: $!";

while (<$fh>) {
    my ($elapsed, $continue, $image_name) = split /\s+/, $_;
    $image_name =~ /([0-9]+)/;
    my $number = $1;
    my $output_name = "m${number}.mp4";
    system "ffmpeg -y -loop 1 -i $image_name -t $continue -vcodec libx264 -pix_fmt yuv420p $output_name";
    $movie_list .= "$output_name\n"
}

open(my $fh_list, ">", "movie_list.txt")
    or die "Can't open movie_list.txt: $!";
print $fh_list $movie_list;
close $fh_list;