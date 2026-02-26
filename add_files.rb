require 'xcodeproj'
project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group['no_typing MacOS']['Services']
if group.nil?
  puts "Could not find Services group"
  exit 1
end

file1 = group.new_file('VoiceCommandService.swift')
file2 = group.new_file('KeystrokeSimulator.swift')

target.add_file_references([file1, file2])
project.save
puts "Successfully added files to Xcode project"
