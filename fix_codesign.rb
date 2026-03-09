require 'xcodeproj'

project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'no_typing MacOS' }

copy_phase = target.copy_files_build_phases.find { |p| p.name == 'Copy Sherpa Binary' }
if copy_phase
  copy_phase.files.each do |f|
    f.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
    puts "Added CodeSignOnCopy attribute"
  end
end

project.save
puts "Project saved"
