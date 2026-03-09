require 'xcodeproj'

project_path = 'no_typing.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'no_typing MacOS' }

support_group = project.main_group.find_subpath('Support', false) || project.main_group.new_group('Support')

copy_phase = target.copy_files_build_phases.find { |p| p.name == 'Copy Sherpa Binary' }
if copy_phase.nil?
  copy_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  copy_phase.name = 'Copy Sherpa Binary'
  copy_phase.dst_subfolder_spec = '6' # Executables (MacOS)
  target.build_phases << copy_phase
end

files_to_copy = [
  'Resources/SherpaOnnx/sherpa-onnx-offline',
  'Resources/SherpaOnnx/lib/libonnxruntime.1.17.1.dylib',
  'Resources/SherpaOnnx/lib/libonnxruntime.dylib',
  'Resources/SherpaOnnx/lib/libsherpa-onnx-c-api.dylib',
  'Resources/SherpaOnnx/lib/libsherpa-onnx-cxx-api.dylib',
  'Resources/SherpaOnnx/lib/libcargs.dylib'
]

files_to_copy.each do |file_path|
  file_ref = support_group.files.find { |f| f.path == file_path } || support_group.new_reference(file_path)
  
  if copy_phase.files.find { |f| f.file_ref == file_ref }.nil?
    build_file = copy_phase.add_file_reference(file_ref, true)
    
    # We must explicitly add CodeSignOnCopy for executables AND dylibs
    # so they aren't rejected by macOS Gatekeeper due to missing signatures.
    build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
    puts "Added to Copy Files phase with CodeSign: #{file_path}"
  end
end

project.save
puts "Project saved successfully"
