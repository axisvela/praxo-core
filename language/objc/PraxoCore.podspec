Pod::Spec.new do |s|
  s.name             = "PraxoCore"
  s.version          = "0.4.0"
  s.summary          = "Embeddable MIT-licensed agent framework for Objective-C"
  s.description      = <<-DESC
Native Objective-C Core for PRAXO-CORE: tools, policy, events, memory,
context, middleware, checkpoints, JSON Schema, plugin manifests, and an agent loop.
                       DESC
  s.homepage         = "https://axisvela.github.io/praxo-core/"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "AxisVela" => "releases@axisvela.com" }
  s.source           = {
    :git => "https://github.com/axisvela/praxo-core.git",
    :tag => "objc/v#{s.version}"
  }
  s.source_files     = "language/objc/Praxo*.{h,m}"
  s.public_header_files = "language/objc/Praxo*.h"
  s.requires_arc     = true
  s.frameworks       = "Foundation"
  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "10.15"
end
