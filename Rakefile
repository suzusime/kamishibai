# 台本ファイル（及び画像と音声）を生成
task :make_script do
  sh "perl make_script.pl"
end

# 台本ファイルから各ページの動画を生成
task :make_each_movie => :make_script do
  sh "perl make_movie.pl"
end

# 各ページの動画を結合して1つにする
task :concat_movie => :make_each_movie do
  puts "concatinating movies..."
  cd "intermediate" do
    sh "ffmpeg -loglevel error  -y -f concat -i movie_list.txt -c:v copy -c:a copy no_bgm.mp4"
  end
  puts "finish."
end

task :merge_music => :concat_movie do
  puts "merging bgm..."
  sh "perl merge_music.pl"
  puts "finish."
end

desc "中間ファイルを削除"
task :clean_intermediate do
  cd "intermediate" do
    sh "git clean -fdX"
  end
end

desc "生成ファイル（中間ファイル含む）を削除"
task :clean => :clean_intermediate do
  rm_f("output.mp4")
end

task :default => :merge_music
