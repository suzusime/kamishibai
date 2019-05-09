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

use Data::Dumper;
use Imager;

# フォントの定義
my $midashi_font_filename = "GenShinGothic-P-Bold.ttf";
my $midashi_font = Imager::Font->new(
    file => $midashi_font_filename,
    color => 'white',
    aa => 1)
    or die "Cannot load $midashi_font_filename: ", Imager->errstr;

my $font_filename = "APJapanesefont.ttf";
my $font = Imager::Font->new(
    file => $font_filename,
    color => 'white',
    aa => 1)
    or die "Cannot load $font_filename: ", Imager->errstr;

# 背景画像を開く
my $bgimg = Imager->new(file=>"nc184832.png")
    or die Imager->errstr();

my $img = $bgimg->copy();

# 左の余白
my $left_margin = 50;

# 上の余白
my $top_margin = 130;

# 次に挿入されるページのページ番号
my $page_counter = 0;

# 前回最後に挿入された座標
my $last_y = $top_margin;

# 出力ファイルのprefix
my $output_prefix = "p",

# そのページが始まるまでの経過時間
my $elapsed_time = 0;

# 台本が入る配列
# 中身はページハッシュへの参照
# ページハッシュの形式は
# (
#   continue => 1, #前のものを消去しない
#   type => "i1", #そこで追加するもののタイプ
#   elms => [ @con ] # 継続要素の参照の配列への参照
# )
# 継続要素とは、各ページの継続時間を決めるもの（音声や動画）
# 必ずtypeキーを持つハッシュだが、他の要素はタイプにより存在したりしなかったり
my @manuscript = ();

# 動画生成用の台本データ
my $movie_script = "";

# そのページの見出し
# TeXのsection相当かなということでこの名前
sub section {
    my ($text) = @_;
    my %page = (
        continue => 0,
        type => "section",
        elms => [],
        text => $text,
    );
    push @manuscript, \%page;
}

# インデント1の箇条書き
sub i1 {
    my ($text) = @_;
    my %page = (
        continue => 1,
        type => "i1",
        elms => [],
        text => $text,
    );
    push @manuscript, \%page;
}

# waitをかける
sub wt {
    my ($second) = @_;
    my %elm = (
        type => "wt",
        time => $second
    );
    push @{$manuscript[$#manuscript]{elms}}, \%elm;
}

sub draw_section {
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
            x => $loc_left_margin + $indent,
            y => $last_y,
            halign => 'left',
            image => $img);
        $last_y += $line_height;
    }
    $last_y += $loc_bottom_margin;
}

sub draw_i1 {
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

# @manuscriptに組み上げた台本を処理する
sub process_manuscript {
    foreach my $page (@manuscript) {
        # ページが切り替わる場合は初期化する
        if (! $page->{continue} ){
            $img = $bgimg->copy();
            $last_y = $top_margin;
        }

        # 描画処理
        my $ptype = $page->{type};
        if ( $ptype eq "section") { draw_section $page->{text} }
        elsif ( $ptype eq "i1") { draw_i1 $page->{text} }
        else { die "This page type has not implemented: $ptype" }

        # 継続時間を計算する
        my $continue_time = 0;
        my $elms_ref = $page->{elms};
        if(@$elms_ref){
            foreach my $elm (@$elms_ref) {
                my $etype = $elm->{type};
                if ($etype eq "wt"){
                    $continue_time += $elm->{time};
                }
                else {
                    die "This element type has not implemented: $etype";
                }
            }
        }

        # 画像出力
        my $page_num = sprintf("%04d", $page_counter);
        my $output_name = $output_prefix . $page_num . ".png";
        $img->write(file=>$output_name)
            or die "Cannot save $output_name: ", $img.errstr;

        # 台本へ追加
        $movie_script .= "$elapsed_time $continue_time $output_name\n";

        # 次へ進む
        $page_counter++;
        $elapsed_time += $continue_time;
    }
}

# ここから内容定義
section "講座の内容";
wt 1;
i1 "ご注文は、うさぎですか？";
wt 2;
i1 "スクリプトを書いてみよう";
wt 3;

# 実際の出力処理
# print Dumper @manuscript;
process_manuscript;

open (my $fh_movie_script, ">", "movie_script.txt")
    or die "Can't open movie_script.txt: $!";
print $fh_movie_script $movie_script;
close $fh_movie_script or die "$fh_movie_script: $!";