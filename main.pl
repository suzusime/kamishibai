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

use Imager;

my $midashi_font_filename = "GenShinGothic-P-Bold.ttf";
my $midashi_font = Imager::Font->new(file=>$midashi_font_filename)
    or die "Cannot load $midashi_font_filename: ", Imager->errstr;

my $font_filename = "APJapanesefont.ttf";
my $font = Imager::Font->new(file=>$font_filename)
    or die "Cannot load $font_filename: ", Imager->errstr;

my $img = Imager->new(file=>"nc184832.png")
    or die Imager->errstr();

# 左の余白
my $left_margin = 50;

# 上の余白
my $top_margin = 130;

# 次に挿入されるページのページ番号
my $page_counter = 0;

# 前回最後に挿入された座標
my $last_y = $top_margin;

# そのページの見出し
# TeXのsection相当かなということでこの名前
sub add_section {
    my ($src_text) = @_;
    my $text_size = 60;
    my $loc_top_margin = 0;
    my $loc_bottom_margin = 50;
    my $loc_left_margin = $left_margin + 0;
    my $line_height = 60;
    my $indent = 30;
    $last_y += $loc_top_margin;

    my $text = $src_text;
    my @lines = split /\n/, $text;
    foreach my $line (@lines) {
        $midashi_font->align(
            string => $line,
            size => $text_size,
            color => 'white',
            x => $loc_left_margin + $indent,
            y => $last_y,
            halign => 'left',
            image => $img);
        $last_y += $line_height;
    }
    $last_y += $loc_bottom_margin;
}

# インデント1の箇条書き
sub add_i1 {
    my ($src_text) = @_;
    my $text_size = 60;
    my $loc_top_margin = 0;
    my $loc_bottom_margin = 30;
    my $loc_left_margin = $left_margin + 80;
    my $line_height = 60;
    my $indent = 30;
    $last_y += $loc_top_margin;

    # 箇条書きマーカー
    my $marker = "・";
    $font->align(
        string => $marker,
        size => $text_size,
        color => 'white',
        x => $loc_left_margin,
        y => $last_y,
        halign => 'left',
        image => $img);

    my $text = $src_text;
    my @lines = split /\n/, $text;
    foreach my $line (@lines) {
        $font->align(
            string => $line,
            size => $text_size,
            color => 'white',
            x => $loc_left_margin + $indent,
            y => $last_y,
            halign => 'left',
            image => $img);
        $last_y += $line_height;
    }
    $last_y += $loc_bottom_margin;
}

# ここから内容定義
add_section "講座の内容";
add_i1 "コマンドラインを使ってみよう";
add_i1 "スクリプトを書いてみよう";

$img->write(file=>'sm1.png')
    or die 'Cannot save file: ', $img.errstr;
