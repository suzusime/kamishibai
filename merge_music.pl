#!/usr/bin/env perl
use strict;
use warnings;
use 5.014;
use utf8;
use open ':encoding(utf8)';
use Encode::Locale;
use File::Basename;
binmode(STDIN, ":encoding(console_in)");
binmode(STDOUT, ":encoding(console_out)");
binmode(STDERR, ":encoding(console_out)");
Encode::Locale::decode_argv;

my @music_list = ();

# 中間ファイルを生成するフォルダ名
my $intermediate_dir = "intermediate";

# ffmpegのログレベルを指定
my $ffmpeg_loglevel = "error";

my $script_name = "$intermediate_dir/music_list.txt";
open(my $fh, "<", $script_name)
    or die "Can't open $script_name: $!";

while (<$fh>) {
    my ($name, $begin, $end) = split /\s+/, $_;
    my ($basename, $dirname, $ext) = fileparse($name, qr/\..*$/);
    my $output_name = "$intermediate_dir/$basename.wav";
    system "ffmpeg -y -loglevel $ffmpeg_loglevel -f lavfi -i aevalsrc=\"0:c=2:d=$begin:s=44100\" -i musics/$name -t $end -filter_complex \"concat=n=2:v=0:a=1\" -vn -ac 2 -ar 44100 -acodec pcm_s16le -f wav $output_name";
    push @music_list, $output_name;
}

my $command = "ffmpeg -y -loglevel $ffmpeg_loglevel -i $intermediate_dir/no_bgm.mp4";
my $filecount = 1;
for my $m (@music_list){
    $command .=" -i $m";
    $filecount++;
}
$command .= " -filter_complex amix=\"inputs=$filecount:duration=first,loudnorm,volume=2\" output.mp4";
system $command;
