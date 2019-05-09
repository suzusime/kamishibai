task :make_script do
  sh "perl make_script.pl"
end

task :make_each_movie => :make_script do
  sh "perl make_movie.pl"
end

task :concat_movie => :make_each_movie do
  sh "ffmpeg -y -f concat -i movie_list.txt -c:v copy -c:a copy output.mp4"
end

task :default => :concat_movie