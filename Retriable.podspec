Pod::Spec.new do |spec|
    spec.name     = 'Retriable'
    spec.version  = '1.0.3'
    spec.license  = 'MIT'
    spec.summary  = 'Make asynchronous components retriable'
    spec.homepage = 'https://github.com/retriable/Retriable'
    spec.author   = { 'retriable' => 'retriable@retriable' }
    spec.source   = { :git => 'https://github.com/retriable/Retriable.git',:tag => "#{spec.version}" }
    spec.description = 'Make asynchronous components retriable.'
    spec.requires_arc = true
    spec.source_files = 'Retriable/*.{h,m}'
    spec.ios.framework = 'UIKit'
    spec.tvos.framework = 'UIKit'
    spec.ios.deployment_target = '8.0'
    spec.watchos.deployment_target = '2.0'
    spec.tvos.deployment_target = '9.0'
    spec.osx.deployment_target = '10.9'
end
