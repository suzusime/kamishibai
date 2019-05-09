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

# 中間ファイルを生成するフォルダ名
my $intermediate_dir = "intermediate";

# ffmpegのログレベルを指定
my $ffmpeg_loglevel = "error";

my $script_name = "$intermediate_dir/movie_script.txt";
open(my $fh, "<", $script_name)
    or die "Can't open $script_name: $!";

while (<$fh>) {
    my ($elapsed, $continue, $has_voice, $image_name) = split /\s+/, $_;
    if($continue == 0){
        # 長さ0の場合は動画を生成しない
        next;
    }
    $image_name =~ /([0-9]+)/;
    my $number = $1;
    my $output_name = "m${number}.mp4";
    print "generating movie $output_name...";
    if($has_voice){
        my $voice_name = "v${number}.wav";
        system "ffmpeg -loglevel $ffmpeg_loglevel -y -i $intermediate_dir/$voice_name -loop 1 -i $intermediate_dir/$image_name -t $continue -vcodec libx264 -pix_fmt yuv420p -c:a aac -ac 2 -ar 44100 $intermediate_dir/$output_name";
    } else {
        system "ffmpeg -loglevel $ffmpeg_loglevel -y -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -loop 1 -i $intermediate_dir/$image_name -t $continue -vcodec libx264 -pix_fmt yuv420p $intermediate_dir/$output_name";
    }
    print " finish.\n";
    $movie_list .= "file $output_name\n"
}

print "saving movie_list...";
open(my $fh_list, ">", "$intermediate_dir/movie_list.txt")
    or die "Can't open movie_list.txt: $!";
print $fh_list $movie_list;
print " finish.\n";
close $fh_list;