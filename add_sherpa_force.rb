require 'xcodeproj'

project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'no_typing MacOS' }
if target.nil?
  puts "Target 'no_typing MacOS' not found"
  exit 1
end

# Check if Resources group exists
resources_group = project.main_group.find_subpath('Resources', false)
if resources_group.nil?
  puts "Creating Resources group explicitly..."
  resources_group = project.main_group.new_group('Resources')
end

# Check if SherpaOnnx group exists inside Resources
sherpa_group = resources_group.find_subpath('SherpaOnnx', false)
if sherpa_group.nil?
  puts "Creating SherpaOnnx group explicitly..."
  sherpa_group = resources_group.new_group('SherpaOnnx')
end

# Find or add the file reference
file_path = 'Resources/SherpaOnnx/sherpa-onnx-offline'
file_ref = sherpa_group.files.find { |f| f.path == 'sherpa-onnx-offline' || f.path == file_path }
if file_ref.nil?
  file_ref = sherpa_group.new_reference(file_path)
  puts "Added file reference for sherpa-onnx-offline"
else
  puts "File reference already exists"
end

# Ensure the file is in the "Copy Bundle Resources" build phase
resources_build_phase = target.resources_build_phase
if resources_build_phase.files.find { |f| f.file_ref == file_ref }.nil?
  resources_build_phase.add_file_reference(file_ref)
  puts "Added to Copy Bundle Resources phase"
else
  puts "Already in Copy Bundle Resources phase"
end

project.save
puts "Project saved"
