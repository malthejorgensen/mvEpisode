require 'uri'
require 'open-uri'
require 'nokogiri'
working_dir = Dir.pwd
Dir.pwd =~ /\/(?<series_name>[A-Za-z0-9 ]+)\/Season (?<season>[0-9]+)$/i
series_name = $~[:series_name]
season_num = $~[:season]
print "Is '#{series_name}' the correct name of the series? "
answer = gets.chomp
if answer.downcase != "yes"
  exit
end
uri_name = URI.escape(series_name)
print "Getting series ID... "
xml_search_series_name = Nokogiri::HTML(open("http://www.tvrage.com/feeds/search.php?show=#{uri_name}"))
if xml_search_series_name.css("show name").first.inner_text.downcase == series_name.downcase
  show_id = xml_search_series_name.css("show showid").first.inner_text
  puts "Found '#{series_name}' (ID: #{show_id})"
  print "Getting episode list... "
  xml_series_episodes = Nokogiri::HTML(open("http://www.tvrage.com/feeds/episode_list.php?sid=#{show_id}"))
  puts "Done"
end

oldfilenames = []
newfilenames = []
matches = 0
errors = 0
renames = 0
Dir.foreach('.') do |filename|
  if filename =~ /s?(?<season>[0-9]?[0-9])(?<episode>[xe ][0-3]?[0-9]|[0-3][0-9]).*\.(?<filetype>mkv|avi|mpg)$/i
    #define matches here because of *** (se below)
    filetype = $~[:filetype]
    #season = $~[:season] # not used
    
    # Remove the 'e' matched in the 'episode' regexp matching group
    episode_num = $~[:episode].gsub(/^[ex ]?0?/i,"")
    # or the smarter(?)
    # episode_num = $~[:episode].downcase.gsub("e","").to_i # deprecated due to 5x15 - the 'x' will be part of $~[:episode]
    # ***: The question is whether this is smarter as we now
    # overwrite the $~ variable (e.g. $~[:filetype]) because gsub uses regex
    
    season_num_prepended = (season_num.to_i < 10)? "0" + season_num : season_num
    episode_num_prepended = (episode_num.to_i < 10)? "0" + episode_num : episode_num
    episode_name = xml_series_episodes.xpath("//season[@no='#{season_num}']/episode[seasonnum='#{episode_num_prepended}']/title").inner_text
    
    oldfilenames[episode_num.to_i] = filename
    newfilenames[episode_num.to_i] = "#{series_name} - S#{season_num_prepended}E#{episode_num_prepended} - #{episode_name}.#{filetype}"
    matches += 1
    puts newfilenames[episode_num.to_i]
    
  else
  end
end
if matches == 0
  puts "No episodes found -- nothing done."
else
  puts "#{matches} episode(s) found."
  File.open('original_filenames.txt', 'a') do |listfile|
    listfile.puts("--- " + Time.new.strftime("%Y-%m-%d %H:%M:%S") + " ---")
    oldfilenames.each_with_index do |oldfilename, index|
      if oldfilename != nil
        newfilename = newfilenames[index]
        if File.exists?(newfilename)
          puts "Error renaming \"#{oldfilename}\":"
          puts "File \"#{newfilename}\" already exists."
          errors += 1
        else
          File.rename( oldfilename, newfilename )
          strindex = String(index)
          strindex =  strindex.length == 1 ? '0' + strindex : strindex
          listfile.puts "#{strindex} -> #{oldfilename}\t\t\t -> #{newfilename}"
          renames += 1
        end
      end
    end
  end
  puts "#{errors} error(s)."
  puts "#{renames} episode(s) successfully renamed."
end
