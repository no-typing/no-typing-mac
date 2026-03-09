require 'xcodeproj'

project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'no_typing MacOS' }
if target.nil?
  puts "Target 'no_typing MacOS' not found"
  exit 1
end

resources_group = project.main_group.find_subpath('Resources', true)
sherpa_group = resources_group.find_subpath('SherpaOnnx', true)

file_path = 'Resources/SherpaOnnx/sherpa-onnx-offline'
file_ref = sherpa_group.files.find { |f| f.path == 'sherpa-onnx-offline' }

if file_ref.nil?
  file_ref = sherpa_group.new_file('sherpa-onnx-offline')
  puts "Added file reference for sherpa-onnx-offline"
else
  puts "File reference already exists"
end

resources_build_phase = target.resources_build_phase
if resources_build_phase.files.find { |f| f.file_ref == file_ref }.nil?
  resources_build_phase.add_file_reference(file_ref)
  puts "Added to resources build phase"
else
  puts "Already in resources build phase"
end

project.save
puts "Project saved"
