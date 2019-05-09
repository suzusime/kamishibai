task :make_script do
  sh "perl make_script.pl"
end

task :make_each_movie => :make_script do
  sh "perl make_movie.pl"
end

task :concat_movie => :make_each_movie do
  puts "concatinating movies..."
  cd "intermediate" do
	  sh "ffmpeg -loglevel error  -y -f concat -i movie_list.txt -c:v copy -c:a copy ../output.mp4"
  end
  puts "finish."
end

task :clean_intermediate do
  cd "intermediate" do
    sh "git clean -fdX"
  end
end

task :clean => :clean_intermediate do
  rm_f("output.mp4")
end

task :default => :concat_movie
