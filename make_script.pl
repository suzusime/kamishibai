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
use Audio::Wav;
use Time::HiRes 'usleep';
use Cwd;
my $cwd = getcwd();

# フォントの定義
my $midashi_font_filename = "GenShinGothic-P-Bold.ttf";
my $midashi_font = Imager::Font->new(
    file => $midashi_font_filename,
    color => 'white',
    aa => 1)
    or die "Cannot load $midashi_font_filename: ", Imager->errstr;

my $font_filename = "851tegaki_zatsu_normal_0883.ttf";
my $font = Imager::Font->new(
    file => $font_filename,
    color => 'white',
    aa => 1)
    or die "Cannot load $font_filename: ", Imager->errstr;

# フォントの定義
my $jimaku_font_filename = "GenShinGothic-P-Bold.ttf";
my $jimaku_font = Imager::Font->new(
    file => $midashi_font_filename,
    color => 'white',
    aa => 1)
    or die "Cannot load $midashi_font_filename: ", Imager->errstr;

# 背景画像を開く
my $bgimg = Imager->new(file=>"kokuban.png")
    or die Imager->errstr();

my $img = $bgimg->copy();

# キャラ画像
# とりあえず1つだけ出す
my $charimg = Imager->new(file=>"kiritan.png")
    or die Imager->errstr();

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

# seikasayで使うcid
my $cid = 1700;

# Windowsから見た実行ディレクトリの絶対パス
my $dirpath = "";
open my $winpath_rs, "wslpath -w $cwd 2>&1 |";
while(<$winpath_rs>) {
    chomp;
    $_ =~ s/\\/\//g;
    $dirpath = $_;
}

# 中間ファイルを生成するフォルダ名

my $intermediate_dir = "intermediate";

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
    # あとで字幕をつけることも考えて、新しいページをつくることにする
    my %page = (
        continue => 1,
        type => "talk",
        elms => [],
    );
    push @manuscript, \%page;

    my ($second) = @_;
    my %elm = (
        type => "wt",
        time => $second
    );
    push @{$manuscript[$#manuscript]{elms}}, \%elm;
}

sub talk {
    my ($text) = @_;

    # あとで字幕をつけることも考えて、新しいページをつくることにする
    my %page = (
        continue => 1,
        type => "talk",
        elms => [],
        text => $text,
    );
    push @manuscript, \%page;

    my %elm = (
        type => "talking",
        text => $text
    );
    push @{$manuscript[$#manuscript]{elms}}, \%elm;
}

sub draw_section {
    my ($src_text) = @_;
    my $text_size = 60;
    my $loc_top_margin = 0;
    my $loc_bottom_margin = 30;
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
    my $text_size = 40;
    my $loc_top_margin = 0;
    my $loc_bottom_margin = 20;
    my $loc_left_margin = $left_margin + 60;
    my $line_height = 40;
    my $indent = 20;
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

sub draw_jimaku {
    my ($src_text) = @_;
    my $text_size = 20;

    # めんどいのでとりあえず一行だけ対応
    my $text = $src_text;
    $jimaku_font->align(
        string => $text,
        size => $text_size,
        x => 600,
        y => 690,
        halign => 'center',
        image => $img);
}

sub get_wav_length {
    my ($wavname) = @_;
    sleep(1);
    my $read = Audio::Wav -> read( "$intermediate_dir/$wavname" )
        or die "Can't open $wavname: $!";
    my $length = $read->length_seconds();
    #my $command = "ffprobe  -hide_banner -show_entries format=duration $wavname";
    #my $length = 0;
    #open my $rs, "$command 2>&1 |";
    #while(<$rs>) {
    #    if($_ =~ /^duration=([0-9\.]+)/){
    #        $length = $1;
    #    }
    #}
    #close $rs;
    #say $length;
    #die;
    return $length;
}

sub make_voice {
    my ($page_num, $text) = @_;
    my $wavname = "v${page_num}.wav";
    my $wavpath = "$dirpath/$intermediate_dir/$wavname";
    print "generating voice $wavname...";
    my $command = "seikasay.exe -cid $cid -save $wavpath -t \"$text\"";
    system($command);
    print " finish.\n";
    my $length = get_wav_length $wavname;
    return $length;
}

# @manuscriptに組み上げた台本を処理する
sub process_manuscript {
    foreach my $page (@manuscript) {
        my $page_num = sprintf("%06d", $page_counter);

        # ページが切り替わる場合は初期化する
        if (! $page->{continue} ){
            $img = $bgimg->copy();
            $last_y = $top_margin;
        }

        # 描画処理
        my $prev_img = $img->copy();#字幕の場合あとで消すので前のものをおいておく
        my $will_be_reverted = 0;#あとで書き戻すか
        my $ptype = $page->{type};
        if ( $ptype eq "section") { draw_section $page->{text} }
        elsif ( $ptype eq "i1") { draw_i1 $page->{text} }
        elsif ( $ptype eq "talk") {
            draw_jimaku $page->{text};
            $will_be_reverted=1;
        }
        else { die "This page type has not implemented: $ptype" }

        # 音声を持っているかのフラグ
        my $has_voice = 0;

        # 継続時間を計算する
        my $continue_time = 0;
        my $elms_ref = $page->{elms};
        if(@$elms_ref){
            foreach my $elm (@$elms_ref) {
                my $etype = $elm->{type};
                if ($etype eq "wt"){
                    $continue_time += $elm->{time};
                }
                elsif ($etype eq "talking"){
                    my $text = $elm->{text};
                    my $length = make_voice $page_num, $text;
                    $continue_time += $length;
                    $has_voice = 1;
                }
                else {
                    die "This element type has not implemented: $etype";
                }
            }
        }

        # 画像出力
        my $img_plus_char = $img->copy();
        # キャラクターの画像を重ねる
        $img_plus_char->rubthrough(src=>$charimg,
            tx=>950, ty=>190);
        my $output_name = "${output_prefix}${page_num}.png";
        print "generating image $output_name...";
        $img_plus_char->write(file=>"$intermediate_dir/$output_name")
            or die "Cannot save $output_name: ", $img.errstr;
        print " finish.\n";

        # 台本へ追加
        $movie_script .= "$elapsed_time $continue_time $has_voice $output_name\n";

        # 次へ進む
        $page_counter++;
        $elapsed_time += $continue_time;
        $img = $prev_img if $will_be_reverted; #書き戻す
    }
}

# ここから内容定義
section "講座の内容";
wt 1;
i1 "端末を使ってみよう";
talk "まずは、所謂黒い画面でコンピュータを操作する方法について解説します";
wt 1;
talk "なにも難しいことはないので、気楽に試してみましょう";
wt 2;
i1 "スクリプトを書いてみよう";
talk "次に、手作業でやっていたコマンド入力を自動化する方法について解説します";
wt 1;
talk "色々な方法がありますが、今回はRakeというものを紹介します";
wt 2;
section "端末";
talk "では、早速端末の話から始めます";
wt 2;
i1 "端末 (terminal)：\n コンピュータから見た人間の側の端";
talk "端末は、英語でterminalと言います";
wt 1;
talk "「終点」という意味の言葉ですね";
wt 5;
i1 "（以下略）";
wt 5;

# 実際の出力処理
# print Dumper @manuscript;
process_manuscript;

print "saving movie_script...";
open (my $fh_movie_script, ">", "$intermediate_dir/movie_script.txt")
    or die "Can't open movie_script.txt: $!";
print $fh_movie_script $movie_script;
print " finish.\n";
close $fh_movie_script or die "$fh_movie_script: $!";