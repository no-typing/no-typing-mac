require 'xcodeproj'
project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group['no_typing MacOS']['Services']['AudioServices']
if group.nil?
  puts "Could not find Services/AudioServices group"
  exit 1
end

file = group.new_file('SystemAudioCaptureManager.swift')
target.add_file_references([file])
project.save
puts "Successfully added file to Xcode project"
