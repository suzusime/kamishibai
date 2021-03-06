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

# キャラ画像を出すかどうかのフラグ
my $show_char = 1;

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

# forground images（前面に出す画像群）
# 内容はハッシュ
# (
#     l => 0, #画像を出すレイヤ。数字が大きいほうが前
#     x => 0, #画像を出す座標
#     y => 0, #画像を出す座標
#     scale => 1, #画像の拡大率
#     name => "hoge.png", #画像の名前。images以下に入れるのでそこからの相対パス
# )
my @forg_images = ();

# bgmのリスト
# 内容はハッシュ
# (
#     name => "sample.mp3",
#     begin => 3.2,
#     end => 10.3,
# )
my @musics = ();

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

sub add_image {
    my %args = @_;

    # デフォルト値を代入
    $args{x} //= 0;
    $args{y} //= 0;
    $args{scale} //= 1;

    my %page = (
        continue => 1,
        type => "add_image",
        elms => [],
        params => \%args,
    );
    push @manuscript, \%page;
}

sub play_music {
    my ($name) = @_;
    my %page = (
        continue => 1,
        type => "play_music",
        elms => [],
        name => $name,
    );
    push @manuscript, \%page;
}

sub stop_music {
    my ($name) = @_;
    my %page = (
        continue => 1,
        type => "stop_music",
        elms => [],
        name => $name,
    );
    push @manuscript, \%page;
}

sub add_char {
    my %page = (
        continue => 1,
        type => "add_char",
        elms => [],
    );
    push @manuscript, \%page;
}

sub remove_char {
    my %page = (
        continue => 1,
        type => "remove_char",
        elms => [],
    );
    push @manuscript, \%page;
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

sub draw_add_image {
    my %args = @_;

    @forg_images = grep $_->{l} != $args{l}, @forg_images;
    push(@forg_images, \%args);
    @forg_images = sort {$a->{l} <=> $b->{l}} @forg_images;
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
            @forg_images = ();
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
        elsif ( $ptype eq "add_image"){ draw_add_image %{$page->{params}} }
        elsif ( $ptype eq "play_music"){
            my %m = (
                name => $page->{name},
                begin => $elapsed_time,
            );
            push @musics, \%m;
        }
        elsif ( $ptype eq "stop_music"){
            my @matched = grep { $_->{name} eq $page->{name}} @musics;
            for my $m (@matched){
                $m->{end} = $elapsed_time;
            }
        }
        elsif ($ptype eq "add_char") { $show_char = 1 }
        elsif ($ptype eq "remove_char") { $show_char = 0 }
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
        # 前面画像を描画
        foreach my $fg (@forg_images){
            my %params = %$fg;
            my $fgimg = Imager->new(file=> "images/".$params{name})
                or die Imager->errstr();
            $img_plus_char->rubthrough(src=>$fgimg,
                tx => $params{x},
                ty => $params{y},
            );
        }
        # キャラクターの画像を重ねる
        $img_plus_char->rubthrough(src=>$charimg,
            tx=>950, ty=>190) if $show_char;
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
remove_char;
section "このツールの機能紹介";
wt 1;
i1 "テキストの表示";
talk "このように、テキストを表示できます";
wt 1;
talk "スライド発表風のものを求めて作ったので箇条書きです";
wt 2;
add_char;
i1 "読み上げ機能";
talk "既にやっているように、テキストを読み上げてもらうことができます";
wt 1;
talk "字幕もこのようにいいかんじに出ます";
wt 2;
section "画像表示";
wt 1;
add_image (l=>0, x=>200, y=>200, name=>"sample.png");
wt 1;
talk "こんなふうに画像を挿入することもできます";
wt 2;
section "音楽の挿入";
play_music "sample.mp3";
i1 "BGMのみ実装";
wt 1;
talk "BGMを挿入することができるようになりました";
wt 1;
talk "1回限りの効果音も挿入できるようになるといいですね";
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

print "saving music_list...";
open (my $fh_music_list, ">", "$intermediate_dir/music_list.txt")
    or die "Can't open music_list.txt: $!";
foreach my $m (@musics){
    my $name = $m->{name};
    my $begin = $m->{begin};
    my $end = $m->{end} // $elapsed_time;
    my $line = "$name $begin $end\n";
    print $fh_music_list $line;
}
print " finish.\n";
close $fh_music_list or die "$fh_music_list: $!";